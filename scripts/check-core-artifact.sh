#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/check-core-artifact.sh <libflutter_engine_core.so>
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

if (($# != 1)); then
  usage >&2
  exit 2
fi

artifact=$1
[[ -f "$artifact" ]] || die "artifact not found: $artifact"

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

violation=0
dynamic_output="$temporary_directory/dynamic.txt"
dynamic_symbols="$temporary_directory/dynamic-symbols.txt"
all_symbols="$temporary_directory/all-symbols.txt"
strings_output="$temporary_directory/strings.txt"

if ! readelf -d "$artifact" >"$dynamic_output"; then
  die "readelf failed for $artifact"
fi

mapfile -t needed_libraries < <(
  sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p' "$dynamic_output"
)
for needed_library in "${needed_libraries[@]}"; do
  case "$needed_library" in
    libdl.so*|libm.so*|libpthread.so*|libc.so*|ld-linux*|libc.musl*|ld-musl*)
      ;;
    *)
      printf 'error: (a) unexpected NEEDED library in %s: %s\n' \
        "$artifact" "$needed_library" >&2
      violation=1
      ;;
  esac
done

if ! nm -D --defined-only "$artifact" >"$dynamic_symbols"; then
  die "nm -D failed for $artifact"
fi
awk '
  $NF !~ /^FlutterCore/ &&
  $NF !~ /^__start_/ &&
  $NF !~ /^__stop_/ { print $NF }
' "$dynamic_symbols" | sort -u >"$temporary_directory/unexpected-exports.txt"
if [[ -s "$temporary_directory/unexpected-exports.txt" ]]; then
  printf 'error: (b) unexpected exported symbols in %s:\n' "$artifact" >&2
  sed -n '1,20p' "$temporary_directory/unexpected-exports.txt" >&2
  violation=1
fi

artifact_directory=$(dirname "$artifact")
artifact_name=$(basename "$artifact")
unstripped_artifact="$artifact_directory/lib.unstripped/$artifact_name"
if [[ -f "$unstripped_artifact" ]]; then
  if ! nm -C "$unstripped_artifact" >"$all_symbols"; then
    die "nm -C failed for $unstripped_artifact"
  fi
  if grep -Eq 'Dart_|dart::|tonic::|kDartVmSnapshotData|kDartVmSnapshotInstructions|kDartIsolateSnapshotData|kDartIsolateSnapshotInstructions' \
    "$all_symbols"; then
    printf 'error: (c) Dart symbols found in %s:\n' "$unstripped_artifact" >&2
    grep -E 'Dart_|dart::|tonic::|kDartVmSnapshotData|kDartVmSnapshotInstructions|kDartIsolateSnapshotData|kDartIsolateSnapshotInstructions' \
      "$all_symbols" | sed -n '1,20p' >&2 || true
    violation=1
  fi
else
  printf 'warning: (c) skipped; unstripped artifact not found at %s\n' \
    "$unstripped_artifact" >&2
fi

if ! strings "$artifact" >"$strings_output"; then
  die "strings failed for $artifact"
fi
# kDartSnapshotData is present in the Dart engine and absent from the core.
if grep -Fqx 'kDartSnapshotData' "$strings_output"; then
  printf 'error: (d) Dart snapshot marker kDartSnapshotData found in %s\n' \
    "$artifact" >&2
  violation=1
fi

if ((violation)); then
  exit 1
fi

printf 'core artifact: ok\n'
