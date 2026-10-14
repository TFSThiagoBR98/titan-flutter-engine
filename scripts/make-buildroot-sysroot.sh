#!/usr/bin/env bash
# Builds a minimal Buildroot glibc sysroot for a supported ARM ABI.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/make-buildroot-sysroot.sh --config <defconfig> [--out <dir>]

Build a Buildroot toolchain-only sysroot and link it into the Flutter Engine.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

config_arg=
out_arg=
while (($# > 0)); do
  case "$1" in
    --config)
      (($# >= 2)) || die "--config requires a value"
      config_arg=$2
      shift 2
      ;;
    --config=*)
      config_arg=${1#*=}
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

[[ -n "$config_arg" ]] || die "--config is required"

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
config_name=$(basename "$config_arg")
case "$config_name" in
  titan_armv7a_hf_glibc_defconfig)
    sysroot_name=titan_armv7a_hf
    ;;
  titan_armv7a_softfp_glibc_defconfig)
    sysroot_name=titan_armv7a_softfp
    ;;
  *)
    die "unsupported Buildroot config: $config_name"
    ;;
esac
config_path="$repository_root/buildroot/configs/$config_name"
[[ -f "$config_path" ]] || die "Buildroot config does not exist: $config_path"

superproject_root=$(git -C "$repository_root" rev-parse --show-superproject-working-tree 2>/dev/null || true)
if [[ -z "$superproject_root" ]]; then
  superproject_root=$(cd "$repository_root/../.." && pwd -P)
fi
workspace_root="$superproject_root/.build_flutter"
buildroot_root="$workspace_root/buildroot"
[[ -d "$buildroot_root" ]] || die "Buildroot checkout does not exist: $buildroot_root"

build_output="$workspace_root/buildroot-out/$config_name"
download_dir="$workspace_root/buildroot-dl"
sysroot_output=${out_arg:-$workspace_root/sysroots/$sysroot_name}
if [[ "$sysroot_output" != /* ]]; then
  sysroot_output="$superproject_root/$sysroot_output"
fi
sysroot_output=$(cd "$(dirname "$sysroot_output")" && pwd -P)/$(basename "$sysroot_output")
engine_sysroot="$superproject_root/.build_flutter/flutter/engine/src/build/linux/${sysroot_name}-sysroot"

mkdir -p "$build_output" "$download_dir" "$sysroot_output"
export BR2_DL_DIR="$download_dir"
export BR2_JLEVEL="$(getconf _NPROCESSORS_ONLN)"

make -C "$buildroot_root" \
  O="$build_output" \
  BR2_EXTERNAL="$repository_root/buildroot" \
  "$config_name"
make -C "$buildroot_root" \
  O="$build_output" \
  BR2_EXTERNAL="$repository_root/buildroot"

staging_dir=$(readlink -f "$build_output/staging")
[[ -d "$staging_dir" ]] || die "Buildroot staging sysroot is missing: $staging_dir"
cp -a "$staging_dir/." "$sysroot_output/"

mkdir -p "$(dirname "$engine_sysroot")"
ln -sfn "$sysroot_output" "$engine_sysroot"
printf 'Buildroot sysroot: %s\n' "$sysroot_output"
printf 'Engine sysroot link: %s -> %s\n' "$engine_sysroot" "$(readlink "$engine_sysroot")"
