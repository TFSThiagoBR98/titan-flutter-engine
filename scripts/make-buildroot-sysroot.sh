#!/usr/bin/env bash
# Builds a minimal Buildroot glibc sysroot for a supported ARM ABI.
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"
source "$(dirname "$0")/lib/cpu-budget.sh"

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

# Clang links the GCC runtime (crtbegin*.o, libgcc, libgcc_eh) for soft-float
# ARM; it finds it automatically under usr/lib/gcc/<triple>/<version>.
install_gcc_runtime() {
  local build_output=$1 sysroot=$2 triple=$3
  local gcc_dirs=("$build_output"/host/lib/gcc/*/*)
  [[ -f "${gcc_dirs[0]}/libgcc_eh.a" ]] || die "GCC runtime is missing in ${gcc_dirs[0]}"
  local destination="$sysroot/usr/lib/gcc/$triple/$(basename "${gcc_dirs[0]}")"
  mkdir -p "$destination"
  cp "${gcc_dirs[0]}"/crt*.o "${gcc_dirs[0]}"/libgcc.a "${gcc_dirs[0]}"/libgcc_eh.a "$destination/"
}

[[ -n "$config_arg" ]] || die "--config is required"

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
buildroot_lock="$repository_root/buildroot/buildroot.lock"
buildroot_url=$(sed -n 's/^url=//p' "$buildroot_lock")
buildroot_tag=$(sed -n 's/^tag=//p' "$buildroot_lock")
[[ -n "$buildroot_url" ]] || die "Buildroot lock is missing url: $buildroot_lock"
[[ -n "$buildroot_tag" ]] || die "Buildroot lock is missing tag: $buildroot_lock"
config_name=$(basename "$config_arg")
# Sysroot name (as patches/linux-target-matrix expects it) and the GCC triple
# Clang looks for under usr/lib/gcc/ in the sysroot, per Buildroot defconfig.
declare -A sysroot_names=(
  [titan_x64_musl_defconfig]=titan_x64_musl
  [titan_arm64_glibc_defconfig]=titan_arm64_glibc
  [titan_arm64_musl_defconfig]=titan_arm64_musl
  [titan_armv7a_hf_glibc_defconfig]=titan_armv7a_hf
  [titan_armv7a_hf_musl_defconfig]=titan_armv7a_hf_musl
  [titan_armv7a_softfp_glibc_defconfig]=titan_armv7a_softfp
  [titan_armv7a_softfp_musl_defconfig]=titan_armv7a_softfp_musl
  [titan_riscv32_glibc_defconfig]=titan_riscv32_glibc
  [titan_riscv32_musl_defconfig]=titan_riscv32_musl
  [titan_riscv64_glibc_defconfig]=titan_riscv64_glibc
  [titan_riscv64_musl_defconfig]=titan_riscv64_musl
)
declare -A gcc_triples=(
  [titan_x64_musl_defconfig]=x86_64-linux-musl
  [titan_arm64_glibc_defconfig]=aarch64-linux-gnu
  [titan_arm64_musl_defconfig]=aarch64-linux-musl
  [titan_armv7a_hf_glibc_defconfig]=arm-linux-gnueabihf
  [titan_armv7a_hf_musl_defconfig]=arm-linux-musleabihf
  [titan_armv7a_softfp_glibc_defconfig]=arm-linux-gnueabi
  [titan_armv7a_softfp_musl_defconfig]=arm-linux-musleabi
  [titan_riscv32_glibc_defconfig]=riscv32-linux-gnu
  [titan_riscv32_musl_defconfig]=riscv32-linux-musl
  [titan_riscv64_glibc_defconfig]=riscv64-linux-gnu
  [titan_riscv64_musl_defconfig]=riscv64-linux-musl
)
[[ -n "${sysroot_names[$config_name]+set}" ]] || die "unsupported Buildroot config: $config_name"
sysroot_name=${sysroot_names[$config_name]}
clang_gcc_triple=${gcc_triples[$config_name]}
config_path="$repository_root/buildroot/configs/$config_name"
[[ -f "$config_path" ]] || die "Buildroot config does not exist: $config_path"

workspace_root="$TITAN_WORK_DIR"
buildroot_root="$TITAN_WORK_DIR/buildroot"
if [[ ! -e "$buildroot_root" ]]; then
  mkdir -p "$workspace_root"
  printf 'cloning Buildroot %s into %s\n' "$buildroot_tag" "$buildroot_root"
  git clone --depth 1 --branch "$buildroot_tag" "$buildroot_url" "$buildroot_root"
elif [[ ! -d "$buildroot_root/.git" && ! -f "$buildroot_root/.git" ]]; then
  die "Buildroot checkout is not a Git repository: $buildroot_root"
else
  current_buildroot_tag=$(git -C "$buildroot_root" describe --tags --exact-match HEAD 2>/dev/null || true)
  [[ "$current_buildroot_tag" == "$buildroot_tag" ]] || \
    die "Buildroot checkout has version ${current_buildroot_tag:-unknown}; expected $buildroot_tag: $buildroot_root"
fi
[[ -d "$buildroot_root" ]] || die "Buildroot checkout does not exist: $buildroot_root"

build_output="$workspace_root/buildroot-out/$config_name"
download_dir="$workspace_root/buildroot-dl"
sysroot_output=${out_arg:-$workspace_root/sysroots/$sysroot_name}
if [[ "$sysroot_output" != /* ]]; then
  sysroot_output="$TITAN_REPOSITORY_ROOT/$sysroot_output"
fi
sysroot_output=$(cd "$(dirname "$sysroot_output")" && pwd -P)/$(basename "$sysroot_output")
engine_sysroot="$TITAN_WORK_DIR/flutter/engine/src/build/linux/${sysroot_name}-sysroot"

mkdir -p "$build_output" "$download_dir" "$sysroot_output"
export BR2_DL_DIR="$download_dir"
export BR2_JLEVEL="$TITAN_JOBS"

run_within_cpu_budget make -C "$buildroot_root" \
  O="$build_output" \
  BR2_EXTERNAL="$repository_root/buildroot" \
  "$config_name"
run_within_cpu_budget make -C "$buildroot_root" \
  O="$build_output" \
  BR2_EXTERNAL="$repository_root/buildroot"

staging_dir=$(readlink -f "$build_output/staging")
[[ -d "$staging_dir" ]] || die "Buildroot staging sysroot is missing: $staging_dir"
cp -a "$staging_dir/." "$sysroot_output/"
install_gcc_runtime "$build_output" "$sysroot_output" "$clang_gcc_triple"

mkdir -p "$(dirname "$engine_sysroot")"
ln -sfn "$sysroot_output" "$engine_sysroot"
printf 'Buildroot sysroot: %s\n' "$sysroot_output"
printf 'Engine sysroot link: %s -> %s\n' "$engine_sysroot" "$(readlink "$engine_sysroot")"
