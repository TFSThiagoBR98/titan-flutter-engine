#!/usr/bin/env bash
# Builds the supported Flutter Engine variants concurrently.
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"
source "$(dirname "$0")/lib/cpu-budget.sh"

if [[ "${TITAN_CPU_SCOPE:-1}" != 0 ]]; then
  run_within_cpu_budget "$0" "$@"
  exit $?
fi

usage() {
  cat <<'EOF'
Usage: scripts/build-matrix.sh [--parallel N] [--zip] [variant ...]

Build the selected engine variants concurrently. Without variants, build the
10 Linux targets in debug, profile, and release modes.

Options:
  --parallel N  Maximum number of simultaneous builds (default: 3)
  -h, --help    Show this help
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

parallel=2
zip_output=0
variants=()
while (($# > 0)); do
  case "$1" in
    --parallel)
      (($# >= 2)) || die "--parallel requires a value"
      parallel=$2
      shift 2
      ;;
    --parallel=*)
      parallel=${1#*=}
      shift
      ;;
    --zip)
      zip_output=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      variants+=("$1")
      shift
      ;;
  esac
done

[[ "$parallel" =~ ^[1-9][0-9]*$ ]] || die "--parallel must be a positive integer"

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
work_root="$TITAN_WORK_DIR"
matrix_root="$TITAN_WORK_DIR/matrix"
build_engine="$repository_root/scripts/build-engine.sh"
# Every build gets the whole budget for -j, and -l (system load) keeps the
# concurrent builds together near it.
jobs=$TITAN_JOBS
load=$TITAN_JOBS

declare -A target_specs=(
  [x64]='--cpu x64'
  [x64-musl]="--cpu x64 --libc musl --target-sysroot $work_root/sysroots/titan_x64_musl"
  [arm64]="--cpu arm64 --target-sysroot $work_root/sysroots/titan_arm64_glibc"
  [arm64-musl]="--cpu arm64 --libc musl --target-sysroot $work_root/sysroots/titan_arm64_musl"
  [arm-hard]="--cpu arm --arm-float-abi hard --target-sysroot $work_root/sysroots/titan_armv7a_hf"
  [arm-hard-musl]="--cpu arm --arm-float-abi hard --libc musl --target-sysroot $work_root/sysroots/titan_armv7a_hf_musl"
  [arm-softfp]="--cpu arm --arm-float-abi softfp --target-sysroot $work_root/sysroots/titan_armv7a_softfp"
  [arm-softfp-musl]="--cpu arm --arm-float-abi softfp --libc musl --target-sysroot $work_root/sysroots/titan_armv7a_softfp_musl"
  [riscv64-glibc]="--cpu riscv64 --target-sysroot $work_root/sysroots/titan_riscv64_glibc"
  [riscv64-musl]="--cpu riscv64 --libc musl --target-sysroot $work_root/sysroots/titan_riscv64_musl"
)
target_names=(
  x64
  x64-musl
  arm64
  arm64-musl
  arm-hard
  arm-hard-musl
  arm-softfp
  arm-softfp-musl
  riscv64-glibc
  riscv64-musl
)
runtime_modes=(debug profile release)

declare -A variant_specs=()
for target in "${target_names[@]}"; do
  for mode in "${runtime_modes[@]}"; do
    variant_specs["$target-$mode"]="--mode $mode ${target_specs[$target]}"
  done
done

for mode in "${runtime_modes[@]}"; do
  variant_specs["sdk-desktop-$mode"]="--mode $mode --gtk-shell --enable-fontconfig --out-name sdk_desktop_$mode --ninja-target flutter/shell/platform/linux:flutter_gtk"
done
for target in "${target_names[@]:1}"; do
  desktop_target=${target//-/_}
  for mode in "${runtime_modes[@]}"; do
    variant_specs["sdk-desktop-$target-$mode"]="--mode $mode --gtk-shell --enable-fontconfig ${target_specs[$target]} --out-name sdk_desktop_${desktop_target}_$mode --ninja-target flutter/shell/platform/linux:flutter_gtk"
  done
done

variant_specs[sdk-host-debug]='--mode debug --out-name sdk_host_debug --ninja-target flutter/build/archives:artifacts --ninja-target flutter/build/archives:flutter_patched_sdk --ninja-target flutter/build/archives:dart_sdk_archive --ninja-target flutter/build/archives:embedder --ninja-target flutter/tools/font_subset --ninja-target flutter/impeller/toolkit/interop:sdk --ninja-target flutter/sky/dist:zip_old_location --ninja-target flutter/lib/gpu/dist:zip_old_location'
variant_specs[sdk-host-release]='--mode release --out-name sdk_host_release --ninja-target flutter/build/archives:flutter_patched_sdk'
variant_specs[sdk-host-arm64-debug]='--mode debug --cpu arm64 --out-name sdk_host_arm64_debug --ninja-target flutter/build/archives:artifacts --ninja-target flutter/tools/font_subset --ninja-target flutter/build/archives:embedder --ninja-target flutter/impeller/toolkit/interop:sdk --ninja-target flutter/build/archives:dart_sdk_archive'

android_debug_arm_targets='--ninja-target flutter --ninja-target flutter/sky/dist:zip_old_location --ninja-target flutter/lib/gpu/dist:zip_old_location --ninja-target flutter/shell/platform/android:embedding_jars --ninja-target flutter/shell/platform/android:abi_jars --ninja-target flutter/shell/platform/embedder:embedder-archive --ninja-target flutter/impeller/toolkit/interop:sdk'
android_debug_targets='--ninja-target flutter --ninja-target flutter/shell/platform/android:abi_jars --ninja-target flutter/shell/platform/embedder:embedder-archive --ninja-target flutter/impeller/toolkit/interop:sdk'
android_aot_arm_targets='--ninja-target default --ninja-target clang_x64/gen_snapshot --ninja-target flutter/shell/platform/android:embedding_jars --ninja-target flutter/shell/platform/android:abi_jars'
android_aot_targets='--ninja-target default --ninja-target clang_x64/gen_snapshot --ninja-target flutter/shell/platform/android:abi_jars --ninja-target flutter/shell/platform/android:analyze_snapshot'
for android_cpu in arm arm64 x64; do
  debug_targets=$android_debug_targets
  aot_targets=$android_aot_targets
  if [[ "$android_cpu" == arm ]]; then
    debug_targets=$android_debug_arm_targets
    aot_targets=$android_aot_arm_targets
  fi
  variant_specs["android-debug-$android_cpu"]="--mode debug --android --android-cpu=$android_cpu --out-name android_debug_$android_cpu $debug_targets"
  variant_specs["android-profile-$android_cpu"]="--mode profile --android --android-cpu=$android_cpu --out-name android_profile_$android_cpu $aot_targets"
  variant_specs["android-release-$android_cpu"]="--mode release --android --android-cpu=$android_cpu --out-name android_release_$android_cpu $aot_targets"
done

variant_specs[web-release]='--mode release --web --out-name web_release --ninja-target flutter/web_sdk:flutter_web_sdk_archive'
for fuchsia_cpu in arm64 x64; do
  for mode in debug profile release; do
    variant_specs["fuchsia-$mode-$fuchsia_cpu"]="--mode $mode --fuchsia --fuchsia-cpu=$fuchsia_cpu --out-name fuchsia_${mode}_$fuchsia_cpu --ninja-target flutter/shell/platform/fuchsia:fuchsia"
  done
done

# riscv32 builds and passes QEMU but is a niche target: request it by name
# (riscv32-glibc-debug, riscv32-musl-debug).
variant_specs[riscv32-glibc-debug]="--mode debug --cpu riscv32 --target-sysroot $work_root/sysroots/titan_riscv32_glibc"
variant_specs[riscv32-musl-debug]="--mode debug --cpu riscv32 --libc musl --target-sysroot $work_root/sysroots/titan_riscv32_musl"

default_variants=()
for mode in "${runtime_modes[@]}"; do
  for target in "${target_names[@]}"; do
    default_variants+=("$target-$mode")
  done
done
if ((${#variants[@]} == 0)); then
  variants=("${default_variants[@]}")
fi

declare -A output_owner
for variant in "${variants[@]}"; do
  [[ -n "${variant_specs[$variant]+set}" ]] || die "unknown variant: $variant"
  spec=${variant_specs[$variant]}
  build_spec=$spec
  read -r -a build_args <<<"$build_spec"
  output_name=$("$build_engine" "${build_args[@]}" --print-out-name)
  if [[ -n "${output_owner[$output_name]+set}" ]]; then
    die "variants ${output_owner[$output_name]} and $variant share the same output directory: $output_name"
  fi
  output_owner[$output_name]=$variant
done

mkdir -p "$matrix_root"

declare -A variant_by_pid start_by_variant status_by_variant duration_by_variant
active=0
next_variant=0
overall_status=0
variant_count=${#variants[@]}

while ((next_variant < variant_count || active > 0)); do
  while ((active < parallel && next_variant < variant_count)); do
    variant=${variants[next_variant]}
    spec=${variant_specs[$variant]}
    build_spec=$spec
    log="$matrix_root/$variant.log"
    read -r -a build_args <<<"$build_spec"
    start_by_variant[$variant]=$(date +%s)
    printf 'starting %s (log: %s)\n' "$variant" "$log"
    build_options=(--jobs "$jobs" --load "$load")
    if ((zip_output)); then
      build_options+=(--zip)
    fi
    nohup "$build_engine" "${build_args[@]}" "${build_options[@]}" \
      >"$log" 2>&1 &
    pid=$!
    variant_by_pid[$pid]=$variant
    active=$((active + 1))
    next_variant=$((next_variant + 1))
  done

  if ((active > 0)); then
    # Reap whichever build ends first, so its slot is refilled at once and
    # its duration is measured when it really finished.
    result=0
    wait -n -p finished_pid "${!variant_by_pid[@]}" || result=$?
    variant=${variant_by_pid[$finished_pid]}
    duration_by_variant[$variant]=$(( $(date +%s) - start_by_variant[$variant] ))
    if ((result == 0)); then
      status_by_variant[$variant]=ok
    else
      status_by_variant[$variant]=falha
      overall_status=1
    fi
    unset "variant_by_pid[$finished_pid]"
    active=$((active - 1))
  fi
done

printf '\nResumo da matriz\n'
for variant in "${variants[@]}"; do
  printf '%-24s %6ss %s\n' "$variant" "${duration_by_variant[$variant]}" \
    "${status_by_variant[$variant]}"
done

exit "$overall_status"
