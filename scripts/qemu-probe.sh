#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"

usage() {
  cat <<'EOF'
Usage: scripts/qemu-probe.sh --abi hf|softfp|softfp-musl --cpu <qemu-cpu>

Compile the software-rendering engine probe and run it with qemu-arm-static.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

abi=
qemu_cpu=
while (($# > 0)); do
  case "$1" in
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case "$abi" in
  hf|softfp|softfp-musl) ;;
  *) die "invalid ABI: $abi (expected hf, softfp or softfp-musl)" ;;
esac
[[ -n "$qemu_cpu" ]] || die "--cpu is required"

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
work_root="$TITAN_WORK_DIR"
flutter_dir="$work_root/flutter"
engine_src="$flutter_dir/engine/src"
clang="$engine_src/flutter/buildtools/linux-x64/clang/bin/clang"
probe_source="$repository_root/tests/qemu/probe_engine.c"
probe_root="$work_root/qemu"
bundle_root="$TITAN_BUNDLE_DIR"
assets="$TITAN_REPOSITORY_ROOT/../../apps/titan_spike_counter/build/flutter_assets"
flutter_commit=$(sed -n 's/^flutter_commit=//p' "$repository_root/flutter.lock")

[[ -x "$clang" ]] || die "embedded clang is missing: $clang"
[[ -f "$probe_source" ]] || die "probe source is missing: $probe_source"
[[ -d "$assets" ]] || die "Flutter assets bundle is missing: $assets"

case "$abi" in
  hf)
    target=armv7-unknown-linux-gnueabihf
    float_abi=hard
    sysroot="$work_root/sysroots/titan_armv7a_hf"
    variant="$flutter_commit-debug-arm-hard"
    ;;
  softfp)
    target=arm-linux-gnueabi
    float_abi=softfp
    sysroot="$work_root/sysroots/titan_armv7a_softfp"
    variant="$flutter_commit-debug-arm-softfp"
    ;;
  softfp-musl)
    target=arm-linux-musleabi
    float_abi=softfp
    sysroot="$work_root/sysroots/titan_armv7a_softfp_musl"
    variant="$flutter_commit-debug-arm-softfp-musl"
    ;;
esac

bundle="$bundle_root/$variant"
probe="$probe_root/engine-probe-$abi"
engine="$bundle/libflutter_engine.so"
icu="$bundle/icudtl.dat"
mkdir -p "$probe_root"
[[ -d "$sysroot" ]] || die "target sysroot is missing: $sysroot"
[[ -f "$engine" ]] || die "engine bundle is missing: $engine"
[[ -f "$icu" ]] || die "ICU data is missing: $icu"

compiler_flags=(
  --target="$target"
  -march=armv7-a
  -mfpu=vfpv3-d16
  -mfloat-abi="$float_abi"
  --sysroot="$sysroot"
  -fuse-ld=lld
  -I"$bundle"
  -Wall
  -Wextra
  -Werror
  -O2
  -pthread
)
if [[ "$abi" != hf ]]; then
  compiler_flags+=(--rtlib=libgcc --unwindlib=libgcc -static-libgcc)
fi

printf 'compiling QEMU probe: abi=%s target=%s\n' "$abi" "$target"
"$clang" "${compiler_flags[@]}" "$probe_source" -ldl -o "$probe"
printf 'running QEMU probe: cpu=%s\n' "$qemu_cpu"
exec qemu-arm-static -cpu "$qemu_cpu" -L "$sysroot" "$probe" "$engine" "$assets" "$icu"
