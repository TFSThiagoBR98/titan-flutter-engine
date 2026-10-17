#!/usr/bin/env bash
set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  printf 'ci.sh: bash 4 or newer is required (found %s)\n' "$BASH_VERSION" >&2
  exit 1
fi

if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
  if [[ -z "${TITAN_JOBS+x}" ]]; then
    TITAN_JOBS=$(getconf _NPROCESSORS_ONLN)
  fi
  export TITAN_CPU_SCOPE=0
fi

source "$(dirname "$0")/lib/paths.sh"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
scripts_root="$repository_root/scripts"
linux_debug_variants='x64-debug x64-musl-debug arm64-debug arm64-musl-debug arm-hard-debug arm-hard-musl-debug arm-softfp-debug arm-softfp-musl-debug riscv64-glibc-debug riscv64-musl-debug'
linux_all_variants='x64-debug x64-musl-debug arm64-debug arm64-musl-debug arm-hard-debug arm-hard-musl-debug arm-softfp-debug arm-softfp-musl-debug riscv64-glibc-debug riscv64-musl-debug x64-profile x64-musl-profile arm64-profile arm64-musl-profile arm-hard-profile arm-hard-musl-profile arm-softfp-profile arm-softfp-musl-profile riscv64-glibc-profile riscv64-musl-profile x64-release x64-musl-release arm64-release arm64-musl-release arm-hard-release arm-hard-musl-release arm-softfp-release arm-softfp-musl-release riscv64-glibc-release riscv64-musl-release'

linux_sdk_variants_for_cell() {
  (($# == 2)) || return 2
  local target=$1 mode=$2
  local gtk_variant
  local -a variants

  case "$target" in
    x64)
      gtk_variant="sdk-desktop-$mode"
      ;;
    x64-musl|arm64|arm64-musl|arm-hard|arm-hard-musl|arm-softfp|arm-softfp-musl|riscv64-glibc|riscv64-musl)
      gtk_variant="sdk-desktop-$target-$mode"
      ;;
    *)
      return 1
      ;;
  esac

  case "$mode" in
    debug|profile|release)
      ;;
    *)
      return 1
      ;;
  esac

  variants=("$gtk_variant")
  case "$target-$mode" in
    x64-debug)
      variants+=(sdk-host-debug)
      ;;
    x64-release)
      variants+=(sdk-host-release)
      ;;
    arm64-debug)
      variants+=(sdk-host-arm64-debug)
      ;;
  esac
  printf '%s\n' "${variants[*]}"
}

run_deps() {
  local -a root_prefix=()
  if [[ "$(id -u)" -ne 0 ]]; then
    [[ "${GITHUB_ACTIONS:-}" == true ]] || die "ci.sh deps must run as root in a container"
    command -v sudo >/dev/null 2>&1 || die "ci.sh deps requires sudo on a GitHub Actions runner"
    root_prefix=(sudo -n)
  fi
  "${root_prefix[@]}" apt-get update
  "${root_prefix[@]}" apt-get install -y --no-install-recommends \
    git python3 curl ca-certificates xz-utils unzip zip binutils ccache file rsync bc cpio patch perl wget make \
    gcc g++ bzip2 qemu-user-static pkg-config libglib2.0-dev
}

run_free_disk() {
  [[ "${GITHUB_ACTIONS:-}" == true ]] || die "ci.sh free-disk requires GITHUB_ACTIONS=true"

  df -h / /mnt
  local -a root_prefix=()
  if [[ "$(id -u)" -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || die "ci.sh free-disk requires sudo on a GitHub Actions runner"
    root_prefix=(sudo -n)
  fi
  for path in \
    /usr/share/dotnet \
    /usr/local/lib/android \
    /opt/ghc \
    /usr/local/.ghcup \
    /opt/hostedtoolcache/CodeQL \
    /usr/share/swift; do
    "${root_prefix[@]}" rm -rf "$path"
  done
  if command -v docker >/dev/null 2>&1; then
    docker image prune -af
  fi
  df -h / /mnt
}

run_sysroots() {
  local config
  for config in \
    titan_x64_musl_defconfig \
    titan_arm64_glibc_defconfig \
    titan_arm64_musl_defconfig \
    titan_armv7a_hf_glibc_defconfig \
    titan_armv7a_hf_musl_defconfig \
    titan_armv7a_softfp_glibc_defconfig \
    titan_armv7a_softfp_musl_defconfig \
    titan_riscv64_glibc_defconfig \
    titan_riscv64_musl_defconfig; do
    "$scripts_root/make-buildroot-sysroot.sh" --config "$config" --publish
  done
}

run_sysroot() {
  (($# == 1)) || die "sysroot requires a defconfig"
  "$scripts_root/make-buildroot-sysroot.sh" --config "$1" --publish
}

# Prints "<variant>: <done>/<total> (<pct>%), <min> min, ~<min> min left" from
# the last Ninja status line in a variant log. The remaining time assumes the
# rate so far holds; links at the end make it a rough lower bound.
build_progress_line() {
  local variant=$1 log=$2 ninja_seconds=$3
  local status done total
  status=$(tail -c 65536 "$log" 2>/dev/null | tr '\r' '\n' | grep -oE '^\[[0-9]+/[0-9]+\]' | tail -n 1) || true
  if [[ -z "$status" ]]; then
    printf '%s: preparing (checkout, gclient, GN)\n' "$variant"
    return
  fi
  status=${status#[}
  status=${status%]}
  done=${status%/*}
  total=${status#*/}
  if ((done == 0 || ninja_seconds == 0)); then
    printf '%s: %s/%s\n' "$variant" "$done" "$total"
    return
  fi
  printf '%s: %s/%s (%s%%), %s min compiling, ~%s min left\n' "$variant" "$done" "$total" \
    "$((100 * done / total))" "$((ninja_seconds / 60))" \
    "$((ninja_seconds * (total - done) / done / 60))"
}

# Heartbeat for the job output: the build itself only writes to the variant
# logs, so print each variant's progress every TITAN_PROGRESS_SECONDS.
report_build_progress() {
  local interval=${TITAN_PROGRESS_SECONDS:-60} variant log
  local -A ninja_started=()
  while sleep "$interval"; do
    for variant in "$@"; do
      log="$TITAN_WORK_DIR/matrix/$variant.log"
      if [[ -z "${ninja_started[$variant]:-}" ]] && grep -qE '^\[[0-9]+/[0-9]+\]' "$log" 2>/dev/null; then
        ninja_started[$variant]=$SECONDS
      fi
      build_progress_line "$variant" "$log" "$((SECONDS - ${ninja_started[$variant]:-$SECONDS}))"
    done
  done
}

run_with_progress() {
  local -a variants=()
  while (($# > 0)) && [[ "$1" != -- ]]; do
    variants+=("$1")
    shift
  done
  (($# > 0)) || die "with-progress requires -- before the command"
  shift
  ((${#variants[@]} > 0 && $# > 0)) || die "with-progress requires variants and a command"

  report_build_progress "${variants[@]}" &
  local reporter=$!
  local status=0
  "$@" || status=$?
  kill "$reporter" 2>/dev/null || true
  wait "$reporter" 2>/dev/null || true
  return "$status"
}

run_build() {
  local variants_text=${TITAN_VARIANTS:-$linux_all_variants}
  local parallel=${TITAN_PARALLEL:-3}
  read -r -a variants <<<"$variants_text"
  local variant status=0
  run_with_progress "${variants[@]}" -- \
    "$scripts_root/build-matrix.sh" --parallel "$parallel" --zip "${variants[@]}" || status=$?
  if ((status != 0)); then
    # The per-variant logs live on the runner's disk; show the end of each one so
    # the failure is visible in the job output.
    for variant in "${variants[@]}"; do
      printf '::group::%s (last 200 lines)\n' "$variant"
      tail -n 200 "$TITAN_WORK_DIR/matrix/$variant.log" 2>/dev/null || true
      printf '::endgroup::\n'
    done
  fi
  return "$status"
}

run_probe() {
  local assets="$TITAN_WORK_DIR/probe-app/flutter_assets"
  local variants_text=${TITAN_VARIANTS:-$linux_debug_variants}
  local expected_hash_file="$repository_root/tests/qemu/expected-frame-hash"
  [[ -f "$expected_hash_file" ]] || die "expected probe hash is missing: $expected_hash_file"
  local expected_hash
  read -r expected_hash < "$expected_hash_file"
  [[ -n "$expected_hash" ]] || die "expected probe hash is empty: $expected_hash_file"
  local output hash
  local -a variants

  "$scripts_root/build-probe-app.sh"
  read -r -a variants <<<"$variants_text"
  for variant in "${variants[@]}"; do
    output=$("$scripts_root/qemu-probe.sh" --target "$variant" --assets "$assets")
    printf '%s\n' "$output"
    hash=$(sed -n 's/.*hash=\([0-9a-f][0-9a-f]*\).*/\1/p' <<<"$output" | tail -n 1)
    [[ -n "$hash" ]] || die "probe did not report a frame hash: $variant"
    if [[ "$hash" != "$expected_hash" ]]; then
      die "probe hash mismatch for $variant: expected $expected_hash, got $hash"
    fi
  done
  printf 'probe hash: %s\n' "$expected_hash"
}

archive_name_for_variant() {
  (($# == 2)) || return 2
  local flutter_commit=$1 variant=$2
  local mode=${variant##*-}
  local target=${variant%-$mode}
  local cpu libc=glibc arm_abi= suffix
  case "$target" in
    x64) cpu=x64 ;;
    x64-musl) cpu=x64; libc=musl ;;
    arm64) cpu=arm64 ;;
    arm64-musl) cpu=arm64; libc=musl ;;
    arm-hard) cpu=arm; arm_abi=hard ;;
    arm-hard-musl) cpu=arm; arm_abi=hard; libc=musl ;;
    arm-softfp) cpu=arm; arm_abi=softfp ;;
    arm-softfp-musl) cpu=arm; arm_abi=softfp; libc=musl ;;
    riscv64-glibc) cpu=riscv64 ;;
    riscv64-musl) cpu=riscv64; libc=musl ;;
    *) return 1 ;;
  esac
  if [[ "$mode" == debug && "$cpu" == x64 && "$libc" == glibc ]]; then
    suffix=
  else
    suffix="-$mode-$cpu"
    [[ -n "$arm_abi" ]] && suffix+="-$arm_abi"
  fi
  [[ "$libc" == musl ]] && suffix+="-musl"
  printf 'flutter-engine-%s%s.zip\n' "$flutter_commit" "$suffix"
}

run_package() {
  local dist="$TITAN_BUNDLE_DIR/dist"
  local flutter_commit
  flutter_commit=$(sed -n 's/^flutter_commit=//p' "$repository_root/flutter.lock")
  [[ -n "$flutter_commit" ]] || die "flutter.lock is missing flutter_commit"
  local variants_text=${TITAN_VARIANTS:-$linux_all_variants}
  local variant archive
  local -a variants archives archive_names
  mkdir -p "$dist"
  read -r -a variants <<<"$variants_text"
  for variant in "${variants[@]}"; do
    archive=$(archive_name_for_variant "$flutter_commit" "$variant") || \
      die "cannot package unknown variant: $variant"
    [[ -f "$dist/$archive" ]] || die "missing engine bundle for $variant: $dist/$archive"
    archives+=("$dist/$archive")
  done
  ((${#archives[@]} > 0)) || die "no engine bundles found in $dist"
  archive_names=("${archives[@]##*/}")
  (cd "$dist" && sha256sum "${archive_names[@]}" > SHA256SUMS)
  printf 'packages: %s\n' "$dist"
}

run_assemble() {
  "$scripts_root/assemble-sdk-artifacts.sh" --out "$TITAN_BUNDLE_DIR/sdk"
}

run_release() {
  [[ "${GITHUB_REF:-}" == refs/tags/v* ]] || {
    printf 'release skipped: not a v* tag\n'
    return 0
  }
  [[ -n "${GITHUB_REPOSITORY:-}" ]] || die "GITHUB_REPOSITORY is required for a tag release"

  local tag=${GITHUB_REF_NAME:-${GITHUB_REF#refs/tags/}}
  local dist="$TITAN_BUNDLE_DIR/dist"
  local -a assets
  mapfile -t assets < <(find "$dist" -maxdepth 1 -type f \( -name '*.zip' -o -name SHA256SUMS \) -print | LC_ALL=C sort)
  ((${#assets[@]} > 0)) || die "no release assets found in $dist"
  gh release create "$tag" --repo "$GITHUB_REPOSITORY" \
    --title "$tag" --notes "Titan Flutter Engine $tag" "${assets[@]}"
  printf 'release published: %s\n' "$tag"
}

run_all() {
  run_deps
  run_sysroots
  run_build
  run_probe
  run_package
  if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
    run_release
  fi
}

stage=${1:-}
case "$stage" in
  deps)
    (($# == 1)) || die "deps does not accept additional arguments"
    run_deps
    ;;
  sysroots)
    (($# == 1)) || die "sysroots does not accept additional arguments"
    run_sysroots
    ;;
  build)
    (($# == 1)) || die "build does not accept additional arguments"
    run_build
    ;;
  linux-sdk-variants)
    (($# == 3)) || die "linux-sdk-variants requires a target and mode"
    linux_sdk_variants_for_cell "$2" "$3" || die "unknown Linux SDK cell: $2-$3"
    ;;
  probe)
    (($# == 1)) || die "probe does not accept additional arguments"
    run_probe
    ;;
  package)
    (($# == 1)) || die "package does not accept additional arguments"
    run_package
    ;;
  assemble)
    (($# == 1)) || die "assemble does not accept additional arguments"
    run_assemble
    ;;
  release)
    (($# == 1)) || die "release does not accept additional arguments"
    run_release
    ;;
  all)
    (($# == 1)) || die "all does not accept additional arguments"
    run_all
    ;;
  free-disk)
    (($# == 1)) || die "free-disk does not accept additional arguments"
    run_free_disk
    ;;
  sysroot)
    (($# == 2)) || die "sysroot requires exactly one defconfig"
    run_sysroot "$2"
    ;;
  with-progress)
    (($# >= 3)) || die "with-progress requires variants and a command"
    shift
    run_with_progress "$@"
    ;;
  *)
    die "usage: scripts/ci.sh deps|free-disk|sysroot|sysroots|build|probe|package|assemble|release|all|with-progress"
    ;;
esac
