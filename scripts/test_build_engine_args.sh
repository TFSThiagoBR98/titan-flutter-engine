#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

standalone_repository="$temporary_directory/titan-flutter-engine"
flutter_directory="$temporary_directory/work/flutter"
fake_bin="$temporary_directory/bin"
gn_log="$temporary_directory/gn.log"
ninja_log="$temporary_directory/ninja.log"

mkdir -p "$standalone_repository/scripts/lib" "$standalone_repository/patches" \
  "$temporary_directory/work/depot_tools" \
  "$flutter_directory/engine/src/flutter/tools" "$fake_bin"
cp "$repository_root/scripts/build-engine.sh" "$standalone_repository/scripts/build-engine.sh"
cp "$repository_root/scripts/patch_series.py" "$standalone_repository/scripts/patch_series.py"
cp "$repository_root/scripts/lib/paths.sh" "$standalone_repository/scripts/lib/paths.sh"
: > "$standalone_repository/patches/series"

git init --quiet "$flutter_directory"
git -C "$flutter_directory" config user.email test@example.invalid
git -C "$flutter_directory" config user.name "Build Engine Test"
printf '%s\n' 'fake Flutter checkout' > "$flutter_directory/README"
git -C "$flutter_directory" add README
git -C "$flutter_directory" commit --quiet -m 'test: fake Flutter checkout'
flutter_commit=$(git -C "$flutter_directory" rev-parse HEAD)
printf 'flutter_commit=%s\n' "$flutter_commit" > "$standalone_repository/flutter.lock"

fake_gn="$flutter_directory/engine/src/flutter/tools/fake-gn"
cat > "$fake_gn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_GN_LOG"
EOF
chmod +x "$fake_gn"

fake_ninja="$fake_bin/ninja"
cat > "$fake_ninja" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_NINJA_LOG"
EOF
chmod +x "$fake_ninja"

run_engine() {
  TITAN_GN="$fake_gn" \
  TITAN_GN_LOG="$gn_log" \
  TITAN_NINJA_LOG="$ninja_log" \
  TITAN_WORK_DIR="$temporary_directory/work" \
  TITAN_BUNDLE_DIR="$temporary_directory/bundle" \
  FVM_ROOT="$temporary_directory/fvm" \
  PATH="$fake_bin:$PATH" \
    "$standalone_repository/scripts/build-engine.sh" "$@"
}

assert_log_contains() {
  local log_path=$1
  local expected=$2
  grep -Fq -- "$expected" "$log_path" || {
    printf 'missing log entry: %s\nlog:\n' "$expected" >&2
    sed -n '1,120p' "$log_path" >&2
    exit 1
  }
}

assert_log_not_contains() {
  local log_path=$1
  local unexpected=$2
  if grep -Fq -- "$unexpected" "$log_path"; then
    printf 'unexpected log entry: %s\nlog:\n' "$unexpected" >&2
    sed -n '1,120p' "$log_path" >&2
    exit 1
  fi
}

: > "$gn_log"
run_engine --gn-only
assert_log_contains "$gn_log" '--target-dir host_debug'
assert_log_contains "$gn_log" 'build_linux_gtk_shell=false titan_target_libc="glibc"'
assert_log_not_contains "$gn_log" '--enable-fontconfig'

: > "$gn_log"
run_engine --mode profile --gtk-shell --enable-fontconfig --gn-only
assert_log_contains "$gn_log" '--target-dir host_profile'
assert_log_contains "$gn_log" 'build_linux_gtk_shell=true titan_target_libc="glibc"'
assert_log_contains "$gn_log" '--enable-fontconfig'

: > "$ninja_log"
run_engine --mode release --out-name sdk_custom \
  --ninja-target first/target --ninja-target second/target --jobs 2 --load 2
assert_log_contains "$ninja_log" '-C '
assert_log_contains "$ninja_log" 'first/target second/target'
assert_log_not_contains "$ninja_log" 'flutter/shell/platform/embedder:flutter_engine_library'

[[ "$(run_engine --mode debug --cpu x64 --print-out-name)" == host_debug ]] || {
  printf 'unexpected default output name\n' >&2
  exit 1
}
[[ "$(run_engine --mode release --out-name sdk_custom --print-out-name)" == sdk_custom ]] || {
  printf 'unexpected overridden output name\n' >&2
  exit 1
}

matrix_repository="$temporary_directory/matrix-repository"
matrix_log="$temporary_directory/matrix.log"
mkdir -p "$matrix_repository/scripts/lib"
cp "$repository_root/scripts/build-matrix.sh" "$matrix_repository/scripts/build-matrix.sh"
cp "$repository_root/scripts/lib/paths.sh" "$matrix_repository/scripts/lib/paths.sh"
matrix_build_engine="$matrix_repository/scripts/build-engine.sh"
cat > "$matrix_build_engine" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

out_name=
print_out_name=0
previous=
for argument in "$@"; do
  if [[ "$previous" == --out-name ]]; then
    out_name=$argument
  fi
  [[ "$argument" == --out-name ]] && previous=--out-name || previous=
  [[ "$argument" == --print-out-name ]] && print_out_name=1
done
if ((print_out_name)); then
  printf '%s\n' "$out_name"
  exit 0
fi
printf '%s\n' "$*" >> "$TITAN_MATRIX_ARGS_LOG"
EOF
chmod +x "$matrix_build_engine"

TITAN_WORK_DIR="$temporary_directory/matrix-work" \
TITAN_MATRIX_ARGS_LOG="$matrix_log" \
  bash "$matrix_repository/scripts/build-matrix.sh" --parallel 3 \
    sdk-host-debug sdk-host-release sdk-desktop-debug sdk-desktop-profile sdk-desktop-release
assert_log_contains "$matrix_log" '--mode debug --out-name sdk_host_debug --ninja-target flutter/build/archives:artifacts'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:flutter_patched_sdk'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:dart_sdk_archive'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:embedder'
assert_log_contains "$matrix_log" '--ninja-target flutter/tools/font_subset'
assert_log_contains "$matrix_log" '--ninja-target flutter/impeller/toolkit/interop:sdk'
assert_log_contains "$matrix_log" '--mode release --out-name sdk_host_release --ninja-target flutter/build/archives:flutter_patched_sdk'
assert_log_contains "$matrix_log" '--mode debug --gtk-shell --enable-fontconfig --out-name sdk_desktop_debug'
assert_log_contains "$matrix_log" '--mode profile --gtk-shell --enable-fontconfig --out-name sdk_desktop_profile'
assert_log_contains "$matrix_log" '--mode release --gtk-shell --enable-fontconfig --out-name sdk_desktop_release'

assemble_script="$repository_root/scripts/assemble-sdk-artifacts.sh"
artifact_fixture="$temporary_directory/artifact-fixture"
artifact_output="$temporary_directory/artifact-output"
mkdir -p "$artifact_fixture/flutter/engine/src"
ln -s "$artifact_fixture/out" "$artifact_fixture/flutter/engine/src/out"
mkdir -p "$artifact_fixture/out/sdk_host_debug/zip_archives/linux-x64" \
  "$artifact_fixture/out/sdk_host_release/zip_archives" \
  "$artifact_fixture/out/sdk_desktop_debug/zip_archives/linux-x64-debug" \
  "$artifact_fixture/out/sdk_desktop_profile/zip_archives/linux-x64-profile" \
  "$artifact_fixture/out/sdk_desktop_release/zip_archives/linux-x64-release"

artifact_paths=(
  linux-x64/artifacts.zip
  flutter_patched_sdk.zip
  dart-sdk-linux-x64.zip
  linux-x64/font-subset.zip
  linux-x64/linux-x64-embedder.zip
  linux-x64/impeller_sdk.zip
  flutter_patched_sdk_product.zip
  linux-x64-debug/linux-x64-flutter-gtk.zip
  linux-x64-profile/linux-x64-flutter-gtk.zip
  linux-x64-release/linux-x64-flutter-gtk.zip
)
for artifact_path in "${artifact_paths[@]}"; do
  case "$artifact_path" in
    linux-x64-debug/*) source_root="$artifact_fixture/out/sdk_desktop_debug/zip_archives" ;;
    linux-x64-profile/*) source_root="$artifact_fixture/out/sdk_desktop_profile/zip_archives" ;;
    linux-x64-release/*) source_root="$artifact_fixture/out/sdk_desktop_release/zip_archives" ;;
    flutter_patched_sdk_product.zip) source_root="$artifact_fixture/out/sdk_host_release/zip_archives" ;;
    *) source_root="$artifact_fixture/out/sdk_host_debug/zip_archives" ;;
  esac
  mkdir -p "$source_root/$(dirname "$artifact_path")"
  printf 'fixture:%s\n' "$artifact_path" > "$source_root/$artifact_path"
done
printf 'fixture:sky_engine.zip\n' > "$artifact_fixture/out/sdk_host_debug/zip_archives/sky_engine.zip"

TITAN_WORK_DIR="$artifact_fixture" \
TITAN_BUNDLE_DIR="$temporary_directory/default-bundle" \
  bash "$assemble_script" --hash test-hash --out "$artifact_output" \
  || {
    printf 'assemble-sdk-artifacts.sh failed unexpectedly\n' >&2
    exit 1
  }
for artifact_path in "${artifact_paths[@]}" sky_engine.zip; do
  [[ -f "$artifact_output/flutter_infra_release/flutter/test-hash/$artifact_path" ]] || {
    printf 'missing assembled artifact: %s\n' "$artifact_path" >&2
    exit 1
  }
done
manifest="$artifact_output/MANIFEST"
[[ "$(awk 'END { print NR }' "$manifest")" -eq 11 ]] || {
  printf 'unexpected MANIFEST entry count\n' >&2
  exit 1
}
while IFS=$'\t' read -r path size checksum; do
  [[ -n "$path" && "$size" =~ ^[0-9]+$ && "$checksum" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'invalid MANIFEST row: %s\n' "$path" >&2
    exit 1
  }
done < "$manifest"

rm "$artifact_fixture/out/sdk_host_debug/zip_archives/linux-x64/artifacts.zip"
if TITAN_WORK_DIR="$artifact_fixture" \
  TITAN_BUNDLE_DIR="$temporary_directory/default-bundle" \
  bash "$assemble_script" --hash missing-artifact --out "$temporary_directory/missing-output"; then
  printf 'assemble-sdk-artifacts.sh accepted a missing required artifact\n' >&2
  exit 1
fi

printf 'test_build_engine_args.sh: ok\n'
