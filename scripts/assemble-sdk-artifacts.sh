#!/usr/bin/env bash
# Assembles Flutter SDK artifacts using the layout expected by flutter precache.
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"

usage() {
  cat <<'EOF'
Usage: scripts/assemble-sdk-artifacts.sh [--hash <content-hash>] [--out <dir>]

Copy SDK zip archives into the Flutter storage layout and write MANIFEST.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

hash_arg=
out_arg=
while (($# > 0)); do
  case "$1" in
    --hash)
      (($# >= 2)) || die "--hash requires a value"
      hash_arg=$2
      shift 2
      ;;
    --hash=*)
      hash_arg=${1#*=}
      shift
      ;;
    --out)
      (($# >= 2)) || die "--out requires a value"
      out_arg=$2
      shift 2
      ;;
    --out=*)
      out_arg=${1#*=}
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if [[ -n "$out_arg" ]]; then
  output_root=$(mkdir -p "$out_arg" && cd "$out_arg" && pwd -P)
else
  output_root=$(mkdir -p "$TITAN_BUNDLE_DIR/sdk" && cd "$TITAN_BUNDLE_DIR/sdk" && pwd -P)
fi

if [[ -n "$hash_arg" ]]; then
  content_hash=$hash_arg
else
  content_hash_script="$TITAN_WORK_DIR/flutter/bin/internal/content_aware_hash.sh"
  [[ -x "$content_hash_script" ]] || die "content-aware hash script is missing: $content_hash_script"
  content_hash=$(bash "$content_hash_script")
fi
[[ -n "$content_hash" ]] || die "content hash is empty"

archive_root="$TITAN_WORK_DIR/flutter/engine/src/out"
layout_root="$output_root/flutter_infra_release/flutter/$content_hash"
manifest="$output_root/MANIFEST"
shopt -s nullglob
archive_directories=("$archive_root"/*/zip_archives)
shopt -u nullglob
((${#archive_directories[@]} > 0)) || die "no SDK zip_archives found under $archive_root"

# Same fields as the engine_stamp.json the Flutter CI publishes next to the
# artifacts; the tool reads it to describe the engine build.
write_engine_stamp() {
  local stamp_path=$1
  local flutter_root="$TITAN_WORK_DIR/flutter"
  local revision revision_date
  revision=$(git -C "$flutter_root" rev-parse HEAD)
  revision_date=$(TZ=UTC git -C "$flutter_root" log -1 --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%SZ HEAD)
  STAMP_REVISION="$revision" STAMP_REVISION_DATE="$revision_date" STAMP_CONTENT_HASH="$content_hash" \
    python3 - "$stamp_path" <<'PY'
import datetime, json, os, sys
now = datetime.datetime.now()
stamp = {
    "build_date": now.isoformat(),
    "build_time_ms": int(now.timestamp() * 1000),
    "git_revision": os.environ["STAMP_REVISION"],
    "git_revision_date": os.environ["STAMP_REVISION_DATE"],
    "content_hash": os.environ["STAMP_CONTENT_HASH"],
}
with open(sys.argv[1], "w", encoding="utf-8") as stamp_file:
    json.dump(stamp, stamp_file, separators=(",", ":"))
PY
}

rm -rf "$layout_root"
mkdir -p "$layout_root"

for archive_directory in "${archive_directories[@]}"; do
  while IFS= read -r -d '' source_path; do
    relative_path=${source_path#./}
    destination_path="$layout_root/$relative_path"
    [[ ! -e "$destination_path" ]] || die "duplicate SDK artifact path: $relative_path"
    mkdir -p "$(dirname "$destination_path")"
    cp -a "$archive_directory/$relative_path" "$destination_path"
  done < <(cd "$archive_directory" && find . -type f -print0 | LC_ALL=C sort -z)
done

inventory_path="$TITAN_REPOSITORY_ROOT/sdk/official-artifacts.txt"
[[ -f "$inventory_path" ]] || die "official artifact inventory is missing: $inventory_path"
mapfile -t required_paths < <(
  awk -F '\t' 'NF >= 2 { print $2 }' "$inventory_path" | LC_ALL=C sort -u
)
(( ${#required_paths[@]} > 0 )) || die "official artifact inventory is empty: $inventory_path"
for required_path in "${required_paths[@]}"; do
  [[ -f "$layout_root/$required_path" ]] || die "required SDK artifact is missing: $required_path"
done

write_engine_stamp "$layout_root/engine_stamp.json"

: > "$manifest"
while IFS= read -r -d '' artifact_path; do
  relative_path=${artifact_path#"$layout_root/"}
  size=$(stat -c '%s' "$artifact_path")
  checksum=$(sha256sum "$artifact_path" | cut -d' ' -f1)
  printf '%s\t%s\t%s\n' "$relative_path" "$size" "$checksum" >> "$manifest"
done < <(find "$layout_root" -type f -print0 | LC_ALL=C sort -z)

printf 'SDK artifacts assembled: %s\n' "$layout_root"
printf 'SDK manifest: %s\n' "$manifest"
