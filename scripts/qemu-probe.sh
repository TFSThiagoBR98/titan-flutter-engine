#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"

usage() {
  cat <<'EOF'
Usage: scripts/qemu-probe.sh --abi x64|hf|softfp|softfp-musl [--cpu <qemu-cpu>] [--assets <dir>]

Compile the software-rendering engine probe and run it with QEMU or natively.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

abi=
qemu_cpu=
assets_arg=
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

case "$abi" in
  x64|hf|softfp|softfp-musl) ;;
  *) die "invalid ABI: $abi (expected x64, hf, softfp or softfp-musl)" ;;
esac
if [[ "$abi" != x64 ]]; then
  [[ -n "$qemu_cpu" ]] || die "--cpu is required for ARM probes"
fi

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

case "$abi" in
  x64)
    target=x86_64-unknown-linux-gnu
    float_abi=
    sysroot=
    variant="$flutter_commit"
    ;;
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
if [[ "$abi" != x64 ]]; then
  [[ -d "$sysroot" ]] || die "target sysroot is missing: $sysroot"
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
)
if [[ "$abi" == x64 ]]; then
  compiler_flags+=(--target="$target")
else
  compiler_flags+=(
    -march=armv7-a
    -mfpu=vfpv3-d16
    -mfloat-abi="$float_abi"
    --sysroot="$sysroot"
  )
fi
if [[ "$abi" != hf && "$abi" != x64 ]]; then
  compiler_flags+=(--rtlib=libgcc --unwindlib=libgcc -static-libgcc)
fi

printf 'compiling engine probe: abi=%s target=%s\n' "$abi" "$target"
"$clang" "${compiler_flags[@]}" "$probe_source" -ldl -o "$probe"
if [[ "$abi" == x64 ]]; then
  printf 'running native probe\n'
  exec "$probe" "$engine" "$assets" "$icu"
fi

qemu_binary=
for candidate in qemu-arm-static qemu-arm; do
  if command -v "$candidate" >/dev/null 2>&1; then
    qemu_binary=$candidate
    break
  fi
done
[[ -n "$qemu_binary" ]] || die "qemu-arm-static or qemu-arm is required"
printf 'running QEMU probe: cpu=%s binary=%s\n' "$qemu_cpu" "$qemu_binary"
exec "$qemu_binary" -cpu "$qemu_cpu" -L "$sysroot" "$probe" "$engine" "$assets" "$icu"
