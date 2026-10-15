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
archive_directories=("$archive_root"/sdk_*/zip_archives)
shopt -u nullglob
((${#archive_directories[@]} > 0)) || die "no SDK zip_archives found under $archive_root"

rm -rf "$layout_root"
mkdir -p "$layout_root"

for archive_directory in "${archive_directories[@]}"; do
  while IFS= read -r -d '' source_path; do
    relative_path=${source_path#./}
    destination_path="$layout_root/$relative_path"
    [[ ! -e "$destination_path" ]] || die "duplicate SDK artifact path: $relative_path"
    mkdir -p "$(dirname "$destination_path")"
    cp -a "$archive_directory/$relative_path" "$destination_path"
  done < <(cd "$archive_directory" && find . -type f -name '*.zip' -print0 | LC_ALL=C sort -z)
done

required_paths=(
  linux-x64/artifacts.zip
  flutter_patched_sdk.zip
  flutter_patched_sdk_product.zip
  dart-sdk-linux-x64.zip
  linux-x64/font-subset.zip
  linux-x64/linux-x64-embedder.zip
  linux-x64/impeller_sdk.zip
  linux-x64-debug/linux-x64-flutter-gtk.zip
  linux-x64-profile/linux-x64-flutter-gtk.zip
  linux-x64-release/linux-x64-flutter-gtk.zip
)
for required_path in "${required_paths[@]}"; do
  [[ -f "$layout_root/$required_path" ]] || die "required SDK artifact is missing: $required_path"
done

: > "$manifest"
while IFS= read -r -d '' artifact_path; do
  relative_path=${artifact_path#"$layout_root/"}
  size=$(stat -c '%s' "$artifact_path")
  checksum=$(sha256sum "$artifact_path" | cut -d' ' -f1)
  printf '%s\t%s\t%s\n' "$relative_path" "$size" "$checksum" >> "$manifest"
done < <(find "$layout_root" -type f -name '*.zip' -print0 | LC_ALL=C sort -z)

printf 'SDK artifacts assembled: %s\n' "$layout_root"
printf 'SDK manifest: %s\n' "$manifest"
