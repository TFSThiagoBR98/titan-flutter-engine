#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
scripts_root="$repository_root/scripts"

run_deps() {
  [[ "$(id -u)" -eq 0 ]] || die "ci.sh deps must run as root in a container"
  apt-get update
  apt-get install -y --no-install-recommends \
    git python3 curl ca-certificates xz-utils unzip zip binutils ccache file rsync bc cpio patch perl wget make \
    gcc g++ bzip2 qemu-user-static pkg-config libglib2.0-dev
}

run_sysroots() {
  local config
  for config in \
    titan_armv7a_hf_glibc_defconfig \
    titan_armv7a_softfp_glibc_defconfig \
    titan_armv7a_softfp_musl_defconfig; do
    "$scripts_root/make-buildroot-sysroot.sh" --config "$config"
  done
}

run_build() {
  local variants_text=${TITAN_VARIANTS:-x64-debug x64-musl-debug arm64-debug arm64-musl-debug arm-hard-debug arm-hard-musl-debug arm-softfp-debug arm-softfp-musl-debug riscv32-glibc-debug riscv32-musl-debug riscv64-glibc-debug riscv64-musl-debug}
  local parallel=${TITAN_PARALLEL:-3}
  read -r -a variants <<<"$variants_text"
  "$scripts_root/build-matrix.sh" --parallel "$parallel" --zip "${variants[@]}"
}

run_probe() {
  local assets="$TITAN_WORK_DIR/probe-app/flutter_assets"
  local variants_text=${TITAN_VARIANTS:-x64-debug x64-musl-debug arm64-debug arm64-musl-debug arm-hard-debug arm-hard-musl-debug arm-softfp-debug arm-softfp-musl-debug riscv32-glibc-debug riscv32-musl-debug riscv64-glibc-debug riscv64-musl-debug}
  local output hash expected_hash=
  local -a variants

  "$scripts_root/build-probe-app.sh"
  read -r -a variants <<<"$variants_text"
  for variant in "${variants[@]}"; do
    output=$("$scripts_root/qemu-probe.sh" --target "$variant" --assets "$assets")
    printf '%s\n' "$output"
    hash=$(sed -n 's/.*hash=\([0-9a-f][0-9a-f]*\).*/\1/p' <<<"$output" | tail -n 1)
    [[ -n "$hash" ]] || die "probe did not report a frame hash: $variant"
    if [[ -z "$expected_hash" ]]; then
      expected_hash=$hash
    elif [[ "$hash" != "$expected_hash" ]]; then
      die "probe hash mismatch for $variant: expected $expected_hash, got $hash"
    fi
  done
  printf 'probe hash: %s\n' "$expected_hash"
}

run_package() {
  local dist="$TITAN_BUNDLE_DIR/dist"
  local -a archives archive_names
  mkdir -p "$dist"
  while IFS= read -r -d '' archive; do
    [[ "$archive" == "$dist/"* ]] && continue
    cp -f "$archive" "$dist/"
  done < <(find "$TITAN_BUNDLE_DIR" -mindepth 2 -maxdepth 2 -type f -name '*.zip' -print0)
  mapfile -t archives < <(find "$dist" -maxdepth 1 -type f -name '*.zip' -print | LC_ALL=C sort)
  ((${#archives[@]} > 0)) || die "no engine bundles found in $dist"
  archive_names=("${archives[@]##*/}")
  (cd "$dist" && sha256sum "${archive_names[@]}" > SHA256SUMS)
  printf 'packages: %s\n' "$dist"
}

run_release() {
  [[ "${GITHUB_REF:-}" == refs/tags/v* ]] || {
    printf 'release skipped: not a v* tag\n'
    return 0
  }
  [[ -n "${FORGEJO_TOKEN:-}" ]] || die "FORGEJO_TOKEN is required for a tag release"
  [[ -n "${GITHUB_SERVER_URL:-}" ]] || die "GITHUB_SERVER_URL is required for a tag release"
  [[ -n "${GITHUB_REPOSITORY:-}" ]] || die "GITHUB_REPOSITORY is required for a tag release"

  local tag=${GITHUB_REF#refs/tags/}
  local api_url="$GITHUB_SERVER_URL/api/v1/repos/$GITHUB_REPOSITORY/releases"
  local payload response release_id asset asset_name asset_url
  payload=$(GITHUB_TAG="$tag" python3 -c \
    'import json, os; print(json.dumps({"tag_name": os.environ["GITHUB_TAG"], "name": os.environ["GITHUB_TAG"]}))')
  response=$(curl --fail-with-body --silent --show-error \
    -X POST \
    -H "Authorization: token $FORGEJO_TOKEN" \
    -H 'Content-Type: application/json' \
    --data "$payload" \
    "$api_url")
  release_id=$(python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])' <<<"$response")
  [[ -n "$release_id" ]] || die "Forgejo release response did not contain an id"

  while IFS= read -r -d '' asset; do
    asset_name=$(basename "$asset")
    asset_url="$api_url/$release_id/assets?name=$asset_name"
    curl --fail-with-body --silent --show-error \
      -X POST \
      -H "Authorization: token $FORGEJO_TOKEN" \
      -F "attachment=@$asset" \
      "$asset_url" >/dev/null
  done < <(find "$TITAN_BUNDLE_DIR/dist" -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)
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
  probe)
    (($# == 1)) || die "probe does not accept additional arguments"
    run_probe
    ;;
  package)
    (($# == 1)) || die "package does not accept additional arguments"
    run_package
    ;;
  release)
    (($# == 1)) || die "release does not accept additional arguments"
    run_release
    ;;
  all)
    (($# == 1)) || die "all does not accept additional arguments"
    run_all
    ;;
  *)
    die "usage: scripts/ci.sh deps|sysroots|build|probe|package|release|all"
    ;;
esac
