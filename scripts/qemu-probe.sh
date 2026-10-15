#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"
source "$(dirname "$0")/lib/sysroot.sh"

usage() {
  cat <<'EOF'
Usage: scripts/qemu-probe.sh --abi x64|hf|softfp|softfp-musl [--cpu <qemu-cpu>] [--assets <dir>]
       scripts/qemu-probe.sh --target <variant> [--cpu <qemu-cpu>] [--assets <dir>]

Compile the software-rendering engine probe and run it with QEMU or natively.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

target_variant=
abi=
qemu_cpu=
assets_arg=
while (($# > 0)); do
  case "$1" in
    --target)
      (($# >= 2)) || die "--target requires a value"
      target_variant=$2
      shift 2
      ;;
    --target=*)
      target_variant=$(printf '%s' "$1" | sed 's/^--target=//')
      shift
      ;;
    --abi)
      (($# >= 2)) || die "--abi requires a value"
      abi=$2
      shift 2
      ;;
    --abi=*)
      abi=${1#*=}
      shift
      ;;
    --cpu)
      (($# >= 2)) || die "--cpu requires a value"
      qemu_cpu=$2
      shift 2
      ;;
    --cpu=*)
      qemu_cpu=${1#*=}
      shift
      ;;
    --assets)
      (($# >= 2)) || die "--assets requires a value"
      assets_arg=$2
      shift 2
      ;;
    --assets=*)
      assets_arg=${1#*=}
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

if [[ -n "$abi" ]]; then
  case "$abi" in
    x64) target_variant=x64-debug ;;
    hf) target_variant=arm-hard-debug ;;
    softfp) target_variant=arm-softfp-debug ;;
    softfp-musl) target_variant=arm-softfp-musl-debug ;;
    *) die "invalid ABI: $abi (expected x64, hf, softfp or softfp-musl)" ;;
  esac
fi
[[ -n "$target_variant" ]] || die "--target is required"

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
work_root="$TITAN_WORK_DIR"
flutter_dir="$work_root/flutter"
engine_src="$flutter_dir/engine/src"
clang="$engine_src/flutter/buildtools/linux-x64/clang/bin/clang"
probe_source="$repository_root/tests/qemu/probe_engine.c"
probe_root="$work_root/qemu"
bundle_root="$TITAN_BUNDLE_DIR"
if [[ -n "$assets_arg" ]]; then
  assets="$assets_arg"
elif [[ -n "$TITAN_SUPERPROJECT_ROOT" && -d "$TITAN_SUPERPROJECT_ROOT/apps/titan_spike_counter/build/flutter_assets" ]]; then
  assets="$TITAN_SUPERPROJECT_ROOT/apps/titan_spike_counter/build/flutter_assets"
else
  assets="$work_root/probe-app/flutter_assets"
fi
flutter_commit=$(sed -n 's/^flutter_commit=//p' "$repository_root/flutter.lock")

[[ -x "$clang" ]] || die "embedded clang is missing: $clang"
[[ -f "$probe_source" ]] || die "probe source is missing: $probe_source"
[[ -d "$assets" ]] || die "Flutter assets bundle is missing: $assets"

target=
float_abi=
sysroot=
sysroot_name=
variant=
qemu_binary=
default_qemu_cpu=
uses_gcc_runtime=0
case "$target_variant" in
  x64-debug)
    target=x86_64-unknown-linux-gnu
    variant="$flutter_commit"
    ;;
  x64-musl-debug)
    target=x86_64-linux-musl
    sysroot_name=titan_x64_musl
    variant="$flutter_commit-debug-x64-musl"
    qemu_binary=qemu-x86_64-static
    default_qemu_cpu=qemu64
    uses_gcc_runtime=1
    ;;
  arm64-debug)
    target=aarch64-linux-gnu
    sysroot_name=titan_arm64_glibc
    variant="$flutter_commit-debug-arm64"
    qemu_binary=qemu-aarch64-static
    default_qemu_cpu=cortex-a53
    ;;
  arm64-musl-debug)
    target=aarch64-linux-musl
    sysroot_name=titan_arm64_musl
    variant="$flutter_commit-debug-arm64-musl"
    qemu_binary=qemu-aarch64-static
    default_qemu_cpu=cortex-a53
    uses_gcc_runtime=1
    ;;
  arm-hard-debug)
    target=armv7-unknown-linux-gnueabihf
    float_abi=hard
    sysroot_name=titan_armv7a_hf
    variant="$flutter_commit-debug-arm-hard"
    qemu_binary=qemu-arm-static
    default_qemu_cpu=cortex-a8
    ;;
  arm-hard-musl-debug)
    target=arm-linux-musleabihf
    float_abi=hard
    sysroot_name=titan_armv7a_hf_musl
    variant="$flutter_commit-debug-arm-hard-musl"
    qemu_binary=qemu-arm-static
    default_qemu_cpu=cortex-a8
    uses_gcc_runtime=1
    ;;
  arm-softfp-debug)
    target=arm-linux-gnueabi
    float_abi=softfp
    sysroot_name=titan_armv7a_softfp
    variant="$flutter_commit-debug-arm-softfp"
    qemu_binary=qemu-arm-static
    default_qemu_cpu=cortex-a8
    uses_gcc_runtime=1
    ;;
  arm-softfp-musl-debug)
    target=arm-linux-musleabi
    float_abi=softfp
    sysroot_name=titan_armv7a_softfp_musl
    variant="$flutter_commit-debug-arm-softfp-musl"
    qemu_binary=qemu-arm-static
    default_qemu_cpu=cortex-a8
    uses_gcc_runtime=1
    ;;
  riscv32-glibc-debug)
    target=riscv32-linux-gnu
    sysroot_name=titan_riscv32_glibc
    variant="$flutter_commit-debug-riscv32"
    qemu_binary=qemu-riscv32-static
    default_qemu_cpu=rv32
    uses_gcc_runtime=1
    ;;
  riscv32-musl-debug)
    target=riscv32-linux-musl
    sysroot_name=titan_riscv32_musl
    variant="$flutter_commit-debug-riscv32-musl"
    qemu_binary=qemu-riscv32-static
    default_qemu_cpu=rv32
    uses_gcc_runtime=1
    ;;
  riscv64-glibc-debug)
    target=riscv64-linux-gnu
    sysroot_name=titan_riscv64_glibc
    variant="$flutter_commit-debug-riscv64"
    qemu_binary=qemu-riscv64-static
    default_qemu_cpu=rv64
    ;;
  riscv64-musl-debug)
    target=riscv64-linux-musl
    sysroot_name=titan_riscv64_musl
    variant="$flutter_commit-debug-riscv64-musl"
    qemu_binary=qemu-riscv64-static
    default_qemu_cpu=rv64
    uses_gcc_runtime=1
    ;;
  *) die "unknown target variant: $target_variant" ;;
esac
if [[ -n "$qemu_binary" && -z "$qemu_cpu" ]]; then
  qemu_cpu=$default_qemu_cpu
fi
if [[ -n "$sysroot_name" ]]; then
  sysroot="$work_root/sysroots/$sysroot_name"
fi

bundle="$bundle_root/$variant"
probe="$probe_root/engine-probe-$target_variant"
engine="$bundle/libflutter_engine.so"
icu="$bundle/icudtl.dat"
mkdir -p "$probe_root"
if [[ -n "$sysroot" ]]; then
  sysroot_has_stamp "$sysroot" || die "target sysroot is incomplete or outdated: $sysroot"
fi
[[ -f "$engine" ]] || die "engine bundle is missing: $engine"
[[ -f "$icu" ]] || die "ICU data is missing: $icu"

compiler_flags=(
  -fuse-ld=lld
  -I"$bundle"
  -Wall
  -Wextra
  -Werror
  -O2
  -pthread
  --target="$target"
)
case "$target_variant" in
  arm64-*)
    compiler_flags+=(-march=armv8-a --sysroot="$sysroot")
    ;;
  arm-*)
    compiler_flags+=(-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi="$float_abi" --sysroot="$sysroot")
    ;;
  riscv32-*)
    compiler_flags+=(-march=rv32gc -mabi=ilp32d --sysroot="$sysroot")
    ;;
  riscv64-*)
    compiler_flags+=(-march=rv64gc -mabi=lp64d --sysroot="$sysroot")
    ;;
  x64-musl-debug)
    compiler_flags+=(--sysroot="$sysroot")
    ;;
esac
if ((uses_gcc_runtime)); then
  compiler_flags+=(--rtlib=libgcc --unwindlib=libgcc -static-libgcc)
fi

printf 'compiling engine probe: variant=%s target=%s\n' "$target_variant" "$target"
"$clang" "${compiler_flags[@]}" "$probe_source" -ldl -o "$probe"
if [[ -z "$qemu_binary" ]]; then
  printf 'running native probe\n'
  exec "$probe" "$engine" "$assets" "$icu"
fi

command -v "$qemu_binary" >/dev/null 2>&1 || die "$qemu_binary is required"
printf 'running QEMU probe: variant=%s cpu=%s binary=%s\n' "$target_variant" "$qemu_cpu" "$qemu_binary"
exec "$qemu_binary" -cpu "$qemu_cpu" -L "$sysroot" "$probe" "$engine" "$assets" "$icu"
