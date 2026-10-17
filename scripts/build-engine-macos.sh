#!/usr/bin/env bash
# Builds Flutter Engine artifacts produced by macOS builders.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-engine-macos.sh [options]

Options:
  --kind host|framework|gen-snapshot|ios|android
  --mode debug|profile|release
  --cpu x64|arm64
  --android-cpu arm|arm64|x64
  --simulator                     Build an iOS simulator target
  --simulator-cpu x64|arm64       iOS simulator CPU
  --out-name <name>               GN output directory name
  --ninja-target <target>         Build only the selected target (repeatable)
  --jobs N                        Ninja parallel jobs (default: 4)
  --load N                        Ninja load limit (default: jobs)
  --work-dir <dir>                Flutter/depot_tools workspace
  -h, --help                      Show this help
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

source "$(dirname "$0")/lib/flutter-checkout.sh"

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
kind=host
mode=debug
cpu=x64
android_cpu=arm
simulator=0
simulator_cpu=
out_name=
jobs=4
load=
work_dir_arg=${TITAN_WORK_DIR:-}
ninja_targets=()

while (($# > 0)); do
  case "$1" in
    --kind)
      (($# >= 2)) || die "--kind requires a value"
      kind=$2
      shift 2
      ;;
    --mode)
      (($# >= 2)) || die "--mode requires a value"
      mode=$2
      shift 2
      ;;
    --cpu)
      (($# >= 2)) || die "--cpu requires a value"
      cpu=$2
      shift 2
      ;;
    --android-cpu)
      (($# >= 2)) || die "--android-cpu requires a value"
      android_cpu=$2
      shift 2
      ;;
    --simulator)
      simulator=1
      shift
      ;;
    --simulator-cpu)
      (($# >= 2)) || die "--simulator-cpu requires a value"
      simulator_cpu=$2
      shift 2
      ;;
    --out-name)
      (($# >= 2)) || die "--out-name requires a value"
      out_name=$2
      shift 2
      ;;
    --ninja-target)
      (($# >= 2)) || die "--ninja-target requires a value"
      ninja_targets+=("$2")
      shift 2
      ;;
    --jobs)
      (($# >= 2)) || die "--jobs requires a value"
      jobs=$2
      shift 2
      ;;
    --load)
      (($# >= 2)) || die "--load requires a value"
      load=$2
      shift 2
      ;;
    --work-dir)
      (($# >= 2)) || die "--work-dir requires a value"
      work_dir_arg=$2
      shift 2
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

[[ "$(uname -s)" == Darwin ]] || die "build-engine-macos.sh must run on macOS"
case "$kind" in
  host|framework|gen-snapshot|ios|android) ;;
  *) die "invalid kind: $kind" ;;
esac
case "$mode" in
  debug|profile|release) ;;
  *) die "invalid mode: $mode" ;;
esac
case "$cpu" in
  x64|arm64) ;;
  *) die "invalid macOS CPU: $cpu" ;;
esac
case "$android_cpu" in
  arm|arm64|x64) ;;
  *) die "invalid Android CPU: $android_cpu" ;;
esac
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || die "--jobs must be a positive integer"
load=${load:-$jobs}
[[ "$load" =~ ^[1-9][0-9]*$ ]] || die "--load must be a positive integer"

work_root=${work_dir_arg:-$repository_root/.build_flutter}
flutter_commit=$(sed -n 's/^flutter_commit=//p' "$repository_root/flutter.lock")
[[ -n "$flutter_commit" ]] || die "flutter.lock is missing flutter_commit"
flutter_checkout "$repository_root" "$work_root" macos "$flutter_commit"
flutter_dir=$FLUTTER_CHECKOUT_DIR
engine_root=$FLUTTER_ENGINE_SOURCE_DIR

if [[ -z "$out_name" ]]; then
  cpu_suffix=
  [[ "$cpu" == arm64 ]] && cpu_suffix=_arm64
  case "$kind" in
    host) out_name="host_$mode$cpu_suffix" ;;
    framework) out_name="host_${mode}_framework$cpu_suffix" ;;
    gen-snapshot) out_name="host_${mode}_gen_snapshot$cpu_suffix" ;;
    ios) out_name="ios_${mode}" ;;
    android) out_name="android_${mode}_$android_cpu" ;;
  esac
fi

gn_args=(
  --target-dir "$out_name"
  --runtime-mode "$mode"
  --no-lto
  --no-rbe
  --no-goma
  --xcode-symlinks
)
ninja_targets_for_kind=()
case "$kind" in
  host)
    gn_args+=(--prebuilt-dart-sdk --build-embedder-examples --use-glfw-swiftshader)
    [[ "$cpu" == arm64 ]] && gn_args+=(--mac --mac-cpu arm64)
    if [[ "$mode" == debug ]]; then
      ninja_targets_for_kind=(
        flutter/build/archives:artifacts
        flutter/build/archives:dart_sdk_archive
        flutter/impeller/toolkit/interop:sdk
      )
    elif [[ "$mode" == profile ]]; then
      ninja_targets_for_kind=(flutter/build/archives:artifacts)
    else
      ninja_targets_for_kind=(flutter/build/archives:artifacts flutter/tools/font_subset)
    fi
    ;;
  framework)
    gn_args+=(--prebuilt-dart-sdk --build-embedder-examples)
    [[ "$cpu" == arm64 ]] && gn_args+=(--mac --mac-cpu arm64)
    ninja_targets_for_kind=(
      flutter/build/archives:flutter_embedder_framework
      flutter/shell/platform/darwin/macos:zip_macos_flutter_framework
    )
    ;;
  gen-snapshot)
    gn_args+=(--prebuilt-dart-sdk --build-embedder-examples)
    [[ "$cpu" == arm64 ]] && gn_args+=(--mac --mac-cpu arm64)
    ninja_targets_for_kind=(flutter/lib/snapshot:create_macos_gen_snapshots)
    ;;
  ios)
    gn_args+=(--ios)
    if ((simulator)); then
      gn_args+=(--simulator)
      [[ -n "$simulator_cpu" ]] && gn_args+=("--simulator-cpu=$simulator_cpu")
    fi
    ninja_targets_for_kind=(
      flutter/lib/snapshot:generate_snapshot_bins
      flutter/shell/platform/darwin/ios:flutter_framework
    )
    ;;
  android)
    gn_args+=(--android)
    [[ "$android_cpu" != arm ]] && gn_args+=("--android-cpu=$android_cpu")
    ninja_targets_for_kind=(flutter/lib/snapshot flutter/shell/platform/android:gen_snapshot)
    ;;
esac

if ((${#ninja_targets[@]} > 0)); then
  ninja_targets_for_kind=("${ninja_targets[@]}")
fi
gn_command=${TITAN_GN:-$flutter_dir/engine/src/flutter/tools/gn}
ninja_command=${TITAN_NINJA:-ninja}
"$gn_command" "${gn_args[@]}"
"$ninja_command" -C "$engine_root/out/$out_name" -j "$jobs" -l "$load" "${ninja_targets_for_kind[@]}"
printf 'macOS engine targets complete: %s\n' "$out_name"
