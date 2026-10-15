#!/usr/bin/env bash
# Builds the Flutter Engine from the pinned Flutter checkout, applies this
# repository's patches, and publishes a complete embedder bundle.
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"

usage() {
  cat <<'EOF'
Usage: scripts/build-engine.sh [options]

Build the Flutter Engine from the revision in flutter.lock.

Options:
  --mode debug|profile|release       Runtime mode (default: debug)
  --cpu x64|arm64|arm|riscv64       Linux target CPU (default: x64)
  --arm-float-abi hard|softfp|soft  ARM float ABI (only with --cpu arm)
  --libc glibc|musl                 Target libc (default: glibc)
  --target-sysroot <dir>             Target sysroot for cross-compilation
  --gn-only                          Configure GN without running Ninja
  --jobs N                           Ninja parallel jobs (default: host CPU count)
  --load N                           Ninja load limit (default: host CPU count)
  --out <dir>                        Bundle output directory
  --out-name <name>                  Engine output directory name
  --gtk-shell                        Build the GTK shell
  --enable-fontconfig                Enable fontconfig in GN
  --ninja-target <target>             Build only the selected Ninja target (repeatable)
  --print-out-name                    Print the Engine output directory name and exit
  --zip                              Also publish the bundle under dist/
  --work-dir <dir>                   Flutter/depot_tools workspace
  -h, --help                         Show this help
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# The ELF header float-ABI flag is what the glibc loader checks. The
# .ARM.attributes section is not reliable: lld keeps the first input's, which
# comes from the sysroot's crti.o.
verify_arm_abi() {
  local engine_path=$1
  local expected_abi=$2
  local header_flags
  command -v readelf >/dev/null || die "readelf is required for ARM ABI verification"
  header_flags=$(LC_ALL=C readelf -h "$engine_path" | grep 'Flags:')
  printf '%s\n' "$header_flags"
  if [[ "$expected_abi" == hard ]]; then
    grep -Fq 'hard-float ABI' <<<"$header_flags" || \
      die "ARM hard-float ABI verification failed for $engine_path"
  else
    grep -Fq 'soft-float ABI' <<<"$header_flags" || \
      die "ARM soft-float ABI verification failed for $engine_path"
  fi
}

mode=debug
cpu=x64
arm_float_abi=
libc=glibc
target_sysroot=
out_dir_arg=
zip_output=0
work_dir_arg=
gn_only=0
jobs_arg=
load_arg=
gtk_shell=0
enable_fontconfig=0
ninja_targets=()
out_name_arg=
print_out_name=0
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
    --libc)
      (($# >= 2)) || die "--libc requires a value"
      libc=$2
      shift 2
      ;;
    --libc=*)
      libc=${1#*=}
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
    --gn-only)
      gn_only=1
      shift
      ;;
    --jobs)
      (($# >= 2)) || die "--jobs requires a value"
      jobs_arg=$2
      shift 2
      ;;
    --jobs=*)
      jobs_arg=${1#*=}
      shift
      ;;
    --load)
      (($# >= 2)) || die "--load requires a value"
      load_arg=$2
      shift 2
      ;;
    --load=*)
      load_arg=${1#*=}
      shift
      ;;
    --gtk-shell)
      gtk_shell=1
      shift
      ;;
    --enable-fontconfig)
      enable_fontconfig=1
      shift
      ;;
    --ninja-target)
      (($# >= 2)) || die "--ninja-target requires a value"
      ninja_targets+=("$2")
      shift 2
      ;;
    --out-name)
      (($# >= 2)) || die "--out-name requires a value"
      out_name_arg=$2
      shift 2
      ;;
    --print-out-name)
      print_out_name=1
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
  ''|hard|softfp|soft) ;;
  *) die "invalid ARM float ABI: $arm_float_abi (expected hard, softfp or soft)" ;;
esac
case "$libc" in
  glibc|musl) ;;
  *) die "invalid libc: $libc (expected glibc or musl)" ;;
esac
if [[ -n "$arm_float_abi" && "$cpu" != arm ]]; then
  die "--arm-float-abi is only valid with --cpu arm"
fi
[[ -z "$jobs_arg" || "$jobs_arg" =~ ^[1-9][0-9]*$ ]] || die "--jobs must be a positive integer"
[[ -z "$load_arg" || "$load_arg" =~ ^[1-9][0-9]*$ ]] || die "--load must be a positive integer"
jobs=${jobs_arg:-$(getconf _NPROCESSORS_ONLN)}
load=${load_arg:-$jobs}

if [[ "$cpu" == x64 && "$libc" == glibc ]]; then
  out_name="host_$mode"
else
  out_name="linux_${mode}_${cpu}"
  if [[ "$cpu" == arm && -n "$arm_float_abi" ]]; then
    out_name+="_$arm_float_abi"
  fi
  out_name+="_$libc"
fi
if [[ -n "$out_name_arg" ]]; then
  out_name=$out_name_arg
fi
if ((print_out_name)); then
  printf '%s\n' "$out_name"
  exit 0
fi

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
if [[ -n "$work_dir_arg" ]]; then
  mkdir -p "$work_dir_arg"
  TITAN_WORK_DIR=$(cd "$work_dir_arg" && pwd -P)
fi
if [[ -n "$out_dir_arg" ]]; then
  mkdir -p "$out_dir_arg"
  TITAN_BUNDLE_DIR=$(cd "$out_dir_arg" && pwd -P)
fi
work_root="$TITAN_WORK_DIR"
artifact_root="$TITAN_BUNDLE_DIR"

depot_tools="$work_root/depot_tools"
flutter_dir="$work_root/flutter"
engine_src="$flutter_dir/engine/src"
ccache_dir="$work_root/ccache"
patch_dir="$repository_root/patches"
series_file="$patch_dir/series"
lock="$repository_root/flutter.lock"

value() { sed -n "s/^$1=//p" "$lock"; }

flutter_commit=$(value flutter_commit)
[[ -n "$flutter_commit" ]] || die "flutter.lock is missing flutter_commit"

[[ -f "$series_file" ]] || die "patch series is missing: $series_file"

patch_folders=()
while IFS= read -r folder; do
  [[ -n "$folder" ]] || continue
  patch_folders+=("$patch_dir/$folder")
done < <(python3 "$repository_root/scripts/patch_series.py" --series "$series_file" --all)

patches=()
for folder in "${patch_folders[@]}"; do
  [[ -d "$folder" ]] || die "patch folder does not exist: $folder"
  while IFS= read -r patch; do
    patches+=("$patch")
  done < <(find "$folder" -maxdepth 1 -type f -name '*.patch' -print | LC_ALL=C sort)
done

all_patch_paths=()
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  all_patch_paths+=("$path")
done < <(python3 "$repository_root/scripts/patch_series.py" --patch-root "$patch_dir" --paths)

patches_sha256() {
  if ((${#patches[@]} == 0)); then
    printf '' | sha256sum | cut -d' ' -f1
  else
    {
      cat "$series_file"
      cat "${patches[@]}"
    } | sha256sum | cut -d' ' -f1
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

restore_patch_paths() {
  local path target
  local -a tracked_paths=()
  local -a created_paths=()

  for path in "${all_patch_paths[@]}"; do
    if git -C "$flutter_dir" cat-file -e "$flutter_commit:$path" 2>/dev/null; then
      tracked_paths+=("$path")
    else
      created_paths+=("$path")
    fi
  done

  for path in "${created_paths[@]}"; do
    target="$flutter_dir/$path"
    if [[ -e "$target" || -L "$target" ]]; then
      [[ -f "$target" || -L "$target" ]] || die "patch-created path is not a file: $path"
      rm -f -- "$target"
    fi
  done

  if ((${#tracked_paths[@]} > 0)); then
    git -C "$flutter_dir" checkout "$flutter_commit" -- "${tracked_paths[@]}"
  fi
  printf 'restored %d patch paths from %s\n' "${#all_patch_paths[@]}" "$flutter_commit"
}

patch_lock="$work_root/.titan-patches.lock"
patch_state="$flutter_dir/.titan-patches.sha256"

(
  flock 9
  if [[ -f "$patch_state" && "$(<"$patch_state")" == "$patches_sha256_actual" ]]; then
    printf 'patch series already applied: %s\n' "$patches_sha256_actual"
  else
    restore_patch_paths

    for patch in "${patches[@]}"; do
      printf 'applying %s\n' "$patch"
      git -C "$flutter_dir" apply "$patch"
    done
    printf '%s\n' "$patches_sha256_actual" > "$patch_state"
    printf 'applied patch series: %s\n' "$patches_sha256_actual"
  fi
) 9>"$patch_lock"

fvm_root=${FVM_ROOT:-${HOME}/fvm}
fvm_sdk="$fvm_root/versions/custom_titan"
mkdir -p "$fvm_root/versions"
if [[ ! -e "$fvm_sdk" && ! -L "$fvm_sdk" ]]; then
  ln -s "$flutter_dir" "$fvm_sdk"
elif [[ "$(readlink -f "$fvm_sdk")" != "$(readlink -f "$flutter_dir")" ]]; then
  die "FVM custom_titan does not point to $flutter_dir: $fvm_sdk"
fi

gn_args=(
  --runtime-mode "$mode"
  --enable-vulkan
  --ccache
  --no-rbe
  --no-goma
  --no-build-glfw-shell
  --no-build-embedder-examples
  --no-enable-unittests
  --enable-minimal-linux
  --gn-args
  "build_linux_gtk_shell=$([[ "$gtk_shell" == 1 ]] && printf true || printf false) titan_target_libc=\"$libc\""
)
if ((enable_fontconfig)); then
  gn_args+=(--enable-fontconfig)
fi
if [[ "$libc" == musl ]]; then
  # fml's backtrace needs glibc's execinfo.h; musl uses fml's stub.
  gn_args+=(--no-backtrace)
fi
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
if [[ "$libc" == musl || ("$cpu" == arm && "$arm_float_abi" != hard) || "$cpu" == riscv32 ]]; then
  # These targets link the GCC runtime from their sysroot; the bundled
  # compiler-rt/libunwind does not cover their ABI or libc.
  gcc_triple=
  sysroot_name=
  if [[ "$libc" == musl ]]; then
    case "$cpu" in
      x64) gcc_triple=x86_64-linux-musl; sysroot_name=titan_x64_musl ;;
      arm64) gcc_triple=aarch64-linux-musl; sysroot_name=titan_arm64_musl ;;
      arm)
        if [[ "$arm_float_abi" == hard ]]; then
          gcc_triple=arm-linux-musleabihf
          sysroot_name=titan_armv7a_hf_musl
        else
          gcc_triple=arm-linux-musleabi
          sysroot_name=titan_armv7a_softfp_musl
        fi
        ;;
      riscv64) gcc_triple=riscv64-linux-musl; sysroot_name=titan_riscv64_musl ;;
    esac
  elif [[ "$cpu" == arm ]]; then
    gcc_triple=arm-linux-gnueabi
    sysroot_name=titan_armv7a_softfp
  else
    gcc_triple=riscv32-linux-gnu
    sysroot_name=titan_riscv32_glibc
  fi
  runtime_sysroot=${target_sysroot:-$engine_src/build/linux/$sysroot_name-sysroot}
  gcc_runtime=("$runtime_sysroot"/usr/lib/gcc/"$gcc_triple"/*/libgcc_eh.a)
  [[ -f "${gcc_runtime[0]}" ]] || \
    die "target $cpu/$libc needs the GCC runtime in $runtime_sysroot (scripts/make-buildroot-sysroot.sh)"
fi

if [[ "$mode" != release ]]; then
  gn_args+=(--no-lto)
fi

printf 'configuring Flutter Engine: mode=%s cpu=%s\n' "$mode" "$cpu"
"${TITAN_GN:-$engine_src/flutter/tools/gn}" --target-dir "$out_name" "${gn_args[@]}"

if ((gn_only)); then
  printf 'GN configuration complete: %s\n' "$engine_src/out/$out_name"
  exit 0
fi

out_dir="$engine_src/out/$out_name"
printf 'building Flutter Engine in %s\n' "$out_dir"
if ((${#ninja_targets[@]} > 0)); then
  ninja -C "$out_dir" -j "$jobs" -l "$load" "${ninja_targets[@]}"
  printf 'selected Ninja targets complete: %s\n' "$out_dir"
  exit 0
fi
ninja -C "$out_dir" -j "$jobs" -l "$load" \
  flutter/shell/platform/embedder:flutter_engine_library \
  flutter/shell/platform/embedder:copy_headers
if [[ "$mode" != debug ]]; then
  ninja -C "$out_dir" -j "$jobs" -l "$load" flutter/shell/common:gen_snapshot
fi

variant="$flutter_commit"
if [[ "$mode" != debug || "$cpu" != x64 ]]; then
  variant="$flutter_commit-$mode-$cpu"
  if [[ -n "$arm_float_abi" ]]; then
    variant+="-$arm_float_abi"
  fi
fi
if [[ "$libc" == musl ]]; then
  variant+="-musl"
fi
dest="$artifact_root/$variant"
stage=$(mktemp -d "$artifact_root/.stage.XXXXXX")
chmod 755 "$stage"  # mktemp creates 0700; the bundle is read by other tools
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

if [[ "$cpu" == arm ]]; then
  verify_arm_abi "$dest/libflutter_engine.so" "${arm_float_abi:-softfp}"
fi

if [[ "$libc" == musl ]]; then
  # A shared library has no PT_INTERP; check that nothing binds to glibc.
  if LC_ALL=C objdump -T "$dest/libflutter_engine.so" | grep -q 'GLIBC_'; then
    die "musl verification failed: the engine references glibc symbol versions"
  fi
  mapfile -t needed_libraries < <(
    LC_ALL=C readelf -d "$dest/libflutter_engine.so" |
      sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p'
  )
  [[ "${#needed_libraries[@]}" -eq 1 && "${needed_libraries[0]}" == "libc.so" ]] || \
    die "musl NEEDED verification failed: ${needed_libraries[*]:-none}"
fi

if ((zip_output)); then
  dist="$artifact_root/dist"
  mkdir -p "$dist"
  zip_path="$dist/flutter-engine-$variant.zip"
  rm -f "$zip_path"
  (cd "$dest" && zip -q -r "$zip_path" .)
  printf 'Flutter Engine archive: %s\n' "$zip_path"
fi
printf 'Flutter Engine bundle: %s\n' "$dest"
