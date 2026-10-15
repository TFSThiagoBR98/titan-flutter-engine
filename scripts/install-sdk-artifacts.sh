#!/usr/bin/env bash
# Install locally assembled Flutter SDK artifacts through flutter precache.
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"

usage() {
  cat <<'EOF'
Usage: scripts/install-sdk-artifacts.sh [--with-dart-sdk] <flutter-sdk>

Install Linux SDK artifacts through the Flutter tool and the local artifact server.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

with_dart_sdk=0
flutter_sdk_arg=
while (($# > 0)); do
  case "$1" in
    --with-dart-sdk)
      with_dart_sdk=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$flutter_sdk_arg" ]] || die "only one Flutter SDK path is allowed"
      flutter_sdk_arg=$1
      shift
      ;;
  esac
done

[[ -n "$flutter_sdk_arg" ]] || die "a Flutter SDK path is required"
[[ -d "$flutter_sdk_arg" ]] || die "Flutter SDK does not exist: $flutter_sdk_arg"
flutter_sdk=$(cd "$flutter_sdk_arg" && pwd -P)
flutter_tool="$flutter_sdk/bin/flutter"
[[ -x "$flutter_tool" ]] || die "Flutter tool is missing or not executable: $flutter_tool"

artifact_root="$TITAN_BUNDLE_DIR/sdk"
manifest="$artifact_root/MANIFEST"
server_script="$(dirname "$0")/sdk-artifacts-server.py"
server_log="$TITAN_WORK_DIR/sdk-server.log"
[[ -f "$manifest" ]] || die "SDK artifact MANIFEST is missing: $manifest"
[[ -f "$server_script" ]] || die "SDK artifact server is missing: $server_script"
mkdir -p "$TITAN_WORK_DIR"
: > "$server_log"

flutter_hash=
engine_stamp="$flutter_sdk/bin/cache/engine.stamp"
if [[ -f "$engine_stamp" ]]; then
  flutter_hash=$(<"$engine_stamp")
fi
if [[ -z "$flutter_hash" || ! -d "$artifact_root/flutter_infra_release/flutter/$flutter_hash" ]]; then
  shopt -s nullglob
  hash_directories=("$artifact_root/flutter_infra_release/flutter"/*)
  shopt -u nullglob
  ((${#hash_directories[@]} == 1)) || \
    die "could not determine the single local Flutter content hash"
  flutter_hash=$(basename "${hash_directories[0]}")
fi

if ((with_dart_sdk)); then
  rm -rf "$flutter_sdk/bin/cache/dart-sdk"
fi

port_file=$(mktemp "$TITAN_WORK_DIR/sdk-server-port.XXXXXX")
server_pid=
cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f "$port_file"
}
trap cleanup EXIT

python3 "$server_script" --root "$artifact_root" --work-dir "$TITAN_WORK_DIR" --port 0 \
  > "$port_file" 2>&1 &
server_pid=$!
port=
for _ in {1..100}; do
  if [[ -s "$port_file" ]]; then
    port=$(sed -n 's/^PORT=//p' "$port_file" | head -n 1)
    [[ -n "$port" ]] && break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    die "SDK artifact server exited before reporting its port"
  fi
  sleep 0.1
done
[[ "$port" =~ ^[1-9][0-9]*$ ]] || die "SDK artifact server did not report a valid port"

if FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:$port" \
  "$flutter_tool" precache --linux --force; then
  :
else
  precache_status=$?
  die "flutter precache failed with status $precache_status"
fi

kill "$server_pid" 2>/dev/null || true
wait "$server_pid" 2>/dev/null || true
server_pid=

while IFS=$'\t' read -r relative_path _size _checksum; do
  [[ -n "$relative_path" ]] || continue
  requested_path="/flutter_infra_release/flutter/$flutter_hash/$relative_path"
  grep -Fqx "local $requested_path" "$server_log" || \
    die "MANIFEST artifact was not requested locally: $relative_path"
done < "$manifest"

if grep -q '^upstream ' "$server_log"; then
  printf 'upstream artifacts:\n'
  grep '^upstream ' "$server_log"
fi
printf 'SDK artifacts installed through flutter precache: %s\n' "$flutter_sdk"
