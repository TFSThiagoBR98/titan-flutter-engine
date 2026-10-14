#!/usr/bin/env bash
# Builds the Flutter Engine from the pinned Flutter checkout, applies this
# repository's patches, and publishes a complete embedder bundle.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-engine.sh [options]

Build the Flutter Engine from the revision in flutter.lock.

Options:
  --mode debug|profile|release       Runtime mode (default: debug)
  --cpu x64|arm64|arm|riscv64       Linux target CPU (default: x64)
  --arm-float-abi hard|softfp        ARM float ABI (only with --cpu arm)
  --target-sysroot <dir>             Target sysroot for cross-compilation
  --out <dir>                        Bundle output directory
  --zip                              Also publish the bundle under dist/
  --work-dir <dir>                   Flutter/depot_tools workspace
  -h, --help                         Show this help
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

mode=debug
cpu=x64
arm_float_abi=
target_sysroot=
out_dir_arg=
zip_output=0
work_dir_arg=
while (($# > 0)); do
  case "$1" in
    --mode)
      (($# >= 2)) || die "--mode requires a value"
      mode=$2
      shift 2
      ;;
    --mode=*)
      mode=${1#*=}
      shift
      ;;
    --cpu)
      (($# >= 2)) || die "--cpu requires a value"
      cpu=$2
      shift 2
      ;;
    --cpu=*)
      cpu=${1#*=}
      shift
      ;;
    --arm-float-abi)
      (($# >= 2)) || die "--arm-float-abi requires a value"
      arm_float_abi=$2
      shift 2
      ;;
    --arm-float-abi=*)
      arm_float_abi=${1#*=}
      shift
      ;;
    --target-sysroot)
      (($# >= 2)) || die "--target-sysroot requires a value"
      target_sysroot=$2
      shift 2
      ;;
    --target-sysroot=*)
      target_sysroot=${1#*=}
      shift
      ;;
    --out)
      (($# >= 2)) || die "--out requires a value"
      out_dir_arg=$2
      shift 2
      ;;
    --out=*)
      out_dir_arg=${1#*=}
      shift
      ;;
    --zip)
      zip_output=1
      shift
      ;;
    --work-dir)
      (($# >= 2)) || die "--work-dir requires a value"
      work_dir_arg=$2
      shift 2
      ;;
    --work-dir=*)
      work_dir_arg=${1#*=}
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

case "$mode" in
  debug|profile|release) ;;
  *) die "invalid mode: $mode (expected debug, profile or release)" ;;
esac
case "$cpu" in
  x64|arm64|arm|riscv64) ;;
  *) die "invalid CPU: $cpu (expected x64, arm64, arm or riscv64)" ;;
esac
case "$arm_float_abi" in
  ''|hard|softfp) ;;
  *) die "invalid ARM float ABI: $arm_float_abi (expected hard or softfp)" ;;
esac
if [[ -n "$arm_float_abi" && "$cpu" != arm ]]; then
  die "--arm-float-abi is only valid with --cpu arm"
fi

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
caller_root=$(pwd -P)
if [[ -n "$work_dir_arg" ]]; then
  if [[ -d "$work_dir_arg" ]]; then
    work_root=$(cd "$work_dir_arg" && pwd -P)
  else
    mkdir -p "$work_dir_arg"
    work_root=$(cd "$work_dir_arg" && pwd -P)
  fi
else
  work_root="$caller_root/.build_flutter"
fi
if [[ -n "$out_dir_arg" ]]; then
  mkdir -p "$out_dir_arg"
  artifact_root=$(cd "$out_dir_arg" && pwd -P)
elif [[ -d "$caller_root/third_party/flutter-engine" ]]; then
  artifact_root="$caller_root/third_party/flutter-engine"
else
  artifact_root="$repository_root/artifacts"
fi

depot_tools="$work_root/depot_tools"
flutter_dir="$work_root/flutter"
engine_src="$flutter_dir/engine/src"
ccache_dir="$work_root/ccache"
patch_dir="$repository_root/patches"
lock="$repository_root/flutter.lock"

value() { sed -n "s/^$1=//p" "$lock"; }

flutter_commit=$(value flutter_commit)
[[ -n "$flutter_commit" ]] || die "flutter.lock is missing flutter_commit"

patches=()
if [[ -d "$patch_dir" ]]; then
  while IFS= read -r patch; do
    patches+=("$patch")
  done < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' -print | LC_ALL=C sort)
fi

patches_sha256() {
  if ((${#patches[@]} == 0)); then
    printf '' | sha256sum | cut -d' ' -f1
  else
    cat "${patches[@]}" | sha256sum | cut -d' ' -f1
  fi
}

patches_sha256_actual=$(patches_sha256)

mkdir -p "$work_root" "$ccache_dir" "$artifact_root"
export CCACHE_DIR="$ccache_dir"
export VPYTHON_VIRTUALENV_ROOT="$work_root/vpython-root"
export CIPD_CACHE_DIR="$work_root/cipd-cache"
export DEPOT_TOOLS_UPDATE=0
export DEPOT_TOOLS_METRICS=0
export PATH="$depot_tools:$PATH"

bootstrap=0
if [[ ! -d "$depot_tools" ]]; then
  printf 'bootstrapping depot_tools in %s\n' "$depot_tools"
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$depot_tools"
  bootstrap=1
fi

if [[ ! -d "$flutter_dir/.git" && ! -f "$flutter_dir/.git" ]]; then
  printf 'bootstrapping Flutter in %s\n' "$flutter_dir"
  git clone https://github.com/flutter/flutter.git "$flutter_dir"
  bootstrap=1
fi

if ((bootstrap)); then
  if [[ ! -f "$work_root/.gclient" ]]; then
    cat > "$work_root/.gclient" <<'EOF'
solutions = [
  {
    "managed": False,
    "name": "flutter",
    "url": "https://github.com/flutter/flutter.git",
    "custom_deps": {},
    "custom_vars": {},
  },
]
target_os = []
target_os_only = True
download_android_deps = False
download_fuchsia_deps = False
download_esbuild = False
setup_githooks = False
EOF
  fi
  git -C "$flutter_dir" fetch origin "$flutter_commit"
  git -C "$flutter_dir" checkout --detach "$flutter_commit"
  (cd "$work_root" && gclient sync -D --no-history)
fi

actual_commit=$(git -C "$flutter_dir" rev-parse HEAD)
if [[ "$actual_commit" != "$flutter_commit" ]]; then
  [[ -z "$(git -C "$flutter_dir" status --porcelain)" ]] || \
    die "Flutter checkout has local changes and is at $actual_commit, expected $flutter_commit"
  git -C "$flutter_dir" fetch origin "$flutter_commit"
  git -C "$flutter_dir" checkout --detach "$flutter_commit"
fi
[[ -d "$engine_src/flutter" ]] || die "Flutter engine source is missing: $engine_src"

fvm_root=${FVM_ROOT:-${HOME}/fvm}
fvm_sdk="$fvm_root/versions/custom_titan"
mkdir -p "$fvm_root/versions"
if [[ ! -e "$fvm_sdk" && ! -L "$fvm_sdk" ]]; then
  ln -s "$flutter_dir" "$fvm_sdk"
elif [[ "$(readlink -f "$fvm_sdk")" != "$(readlink -f "$flutter_dir")" ]]; then
  die "FVM custom_titan does not point to $flutter_dir: $fvm_sdk"
fi

for patch in "${patches[@]}"; do
  if git -C "$flutter_dir" apply --check "$patch"; then
    printf 'applying %s\n' "$patch"
    git -C "$flutter_dir" apply "$patch"
  elif git -C "$flutter_dir" apply --reverse --check "$patch"; then
    printf 'patch already applied: %s\n' "$patch"
  else
    die "cannot apply patch: $patch"
  fi
done

gn_args=(
  --runtime-mode "$mode"
  --enable-vulkan
  --ccache
  --no-rbe
  --no-goma
  --no-build-glfw-shell
  --no-build-embedder-examples
  --no-enable-unittests
)
if [[ "$cpu" != x64 ]]; then
  gn_args+=(--linux --linux-cpu "$cpu")
fi
if [[ -n "$arm_float_abi" ]]; then
  gn_args+=(--arm-float-abi "$arm_float_abi")
fi
if [[ -n "$target_sysroot" ]]; then
  [[ -d "$target_sysroot" ]] || die "target sysroot does not exist: $target_sysroot"
  target_sysroot=$(cd "$target_sysroot" && pwd -P)
  gn_args+=(--target-sysroot "$target_sysroot")
fi

printf 'configuring Flutter Engine: mode=%s cpu=%s\n' "$mode" "$cpu"
"$engine_src/flutter/tools/gn" "${gn_args[@]}"

out_name="host_$mode"
if [[ "$cpu" != x64 ]]; then
  out_name="linux_${mode}_$cpu"
fi
out_dir="$engine_src/out/$out_name"
printf 'building Flutter Engine in %s\n' "$out_dir"
ninja -C "$out_dir" \
  flutter/shell/platform/embedder:flutter_engine_library \
  flutter/shell/platform/embedder:copy_headers
if [[ "$mode" != debug ]]; then
  ninja -C "$out_dir" flutter/shell/common:gen_snapshot
fi

variant="$flutter_commit"
if [[ "$mode" != debug || "$cpu" != x64 ]]; then
  variant="$flutter_commit-$mode-$cpu"
  if [[ -n "$arm_float_abi" ]]; then
    variant+="-$arm_float_abi"
  fi
fi
dest="$artifact_root/$variant"
stage=$(mktemp -d "$artifact_root/.stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT

for artifact in libflutter_engine.so flutter_embedder.h icudtl.dat; do
  [[ -f "$out_dir/$artifact" ]] || die "engine build did not produce $out_dir/$artifact"
  cp -a "$out_dir/$artifact" "$stage/$artifact"
done
if [[ "$mode" != debug ]]; then
  [[ -f "$out_dir/gen_snapshot" ]] || die "engine build did not produce $out_dir/gen_snapshot"
  cp -a "$out_dir/gen_snapshot" "$stage/gen_snapshot"
fi

stamp="local:$flutter_commit:$patches_sha256_actual"
printf '%s\n' "$stamp" > "$stage/.complete"
rm -rf "$dest"
mv "$stage" "$dest"

if ((zip_output)); then
  dist="$artifact_root/dist"
  mkdir -p "$dist"
  zip_path="$dist/flutter-engine-$variant.zip"
  rm -f "$zip_path"
  (cd "$dest" && zip -q -r "$zip_path" .)
  printf 'Flutter Engine archive: %s\n' "$zip_path"
fi
printf 'Flutter Engine bundle: %s\n' "$dest"
