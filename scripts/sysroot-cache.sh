#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"
source "$(dirname "$0")/lib/sysroot.sh"

sysroot_cache_name() {
  case "$(basename "$1")" in
    titan_x64_musl_defconfig) printf 'titan_x64_musl\n' ;;
    titan_arm64_glibc_defconfig) printf 'titan_arm64_glibc\n' ;;
    titan_arm64_musl_defconfig) printf 'titan_arm64_musl\n' ;;
    titan_armv7a_hf_glibc_defconfig) printf 'titan_armv7a_hf\n' ;;
    titan_armv7a_hf_musl_defconfig) printf 'titan_armv7a_hf_musl\n' ;;
    titan_armv7a_softfp_glibc_defconfig) printf 'titan_armv7a_softfp\n' ;;
    titan_armv7a_softfp_musl_defconfig) printf 'titan_armv7a_softfp_musl\n' ;;
    titan_riscv32_glibc_defconfig) printf 'titan_riscv32_glibc\n' ;;
    titan_riscv32_musl_defconfig) printf 'titan_riscv32_musl\n' ;;
    titan_riscv64_glibc_defconfig) printf 'titan_riscv64_glibc\n' ;;
    titan_riscv64_musl_defconfig) printf 'titan_riscv64_musl\n' ;;
    *)
      printf 'error: unsupported Buildroot config: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

sysroot_cache_archive_name() {
  (($# == 1)) || return 2
  local config_name=$(basename "$1")
  local name key
  name=$(sysroot_cache_name "$config_name")
  key=$(sysroot_key "$config_name")
  printf 'sysroot-%s-%s.tar.zst\n' "$name" "${key:0:16}"
}

sysroot_cache_dir() {
  printf '%s/sysroot-cache\n' "$TITAN_WORK_DIR"
}

sysroot_cache_default_sysroot() {
  local config_name=$(basename "$1")
  printf '%s/sysroots/%s\n' "$TITAN_WORK_DIR" "$(sysroot_cache_name "$config_name")"
}

sysroot_cache_link() {
  (($# == 2)) || return 2
  local sysroot_name=$1 sysroot_directory=$2
  local engine_sysroot="$TITAN_WORK_DIR/flutter/engine/src/build/linux/${sysroot_name}-sysroot"
  mkdir -p "$(dirname "$engine_sysroot")"
  ln -sfn "$sysroot_directory" "$engine_sysroot"
}

sysroot_cache_create() {
  (($# >= 1 && $# <= 2)) || return 2
  local config_name=$(basename "$1")
  local sysroot_directory=${2:-$(sysroot_cache_default_sysroot "$config_name")}
  local archive_directory archive
  archive_directory=$(sysroot_cache_dir)
  archive="$archive_directory/$(sysroot_cache_archive_name "$config_name")"
  [[ -d "$sysroot_directory" ]] || {
    printf 'error: sysroot directory is missing: %s\n' "$sysroot_directory" >&2
    return 1
  }
  sysroot_has_stamp "$sysroot_directory" || {
    printf 'error: sysroot stamp is missing: %s\n' "$sysroot_directory" >&2
    return 1
  }
  command -v zstd >/dev/null 2>&1 || {
    printf 'error: zstd is required to create the sysroot cache\n' >&2
    return 1
  }
  mkdir -p "$archive_directory"
  tar --sort=name --owner=0 --group=0 --mtime=@0 -I zstd \
    -cf "$archive" -C "$sysroot_directory" .
  printf '%s\n' "$archive"
}

sysroot_cache_extract() {
  (($# == 2)) || return 2
  local archive=$1 sysroot_directory=$2
  command -v zstd >/dev/null 2>&1 || {
    printf 'error: zstd is required to extract the sysroot cache\n' >&2
    return 1
  }
  mkdir -p "$sysroot_directory"
  tar -I zstd -xf "$archive" -C "$sysroot_directory"
}

sysroot_cache_fetch() {
  (($# >= 1 && $# <= 2)) || return 2
  local config_name=$(basename "$1")
  local sysroot_name archive_directory archive sysroot_directory
  sysroot_name=$(sysroot_cache_name "$config_name")
  archive_directory=$(sysroot_cache_dir)
  archive="$archive_directory/$(sysroot_cache_archive_name "$config_name")"
  sysroot_directory=${2:-$(sysroot_cache_default_sysroot "$config_name")}
  mkdir -p "$archive_directory"

  if [[ ! -f "$archive" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
      printf 'no sysroot cache: gh is unavailable\n' >&2
      return 3
    fi
    local repository=${TITAN_CACHE_REPO:-TFSThiagoBR98/titan-flutter-engine}
    if ! gh release download sysroots-cache --repo "$repository" \
      --pattern "$(basename "$archive")" --dir "$archive_directory" >/dev/null 2>&1; then
      printf 'no sysroot cache: %s\n' "$archive"
      return 3
    fi
  fi

  if ! sysroot_cache_extract "$archive" "$sysroot_directory" || \
    ! sysroot_has_stamp "$sysroot_directory"; then
    printf 'no sysroot cache: invalid archive %s\n' "$archive" >&2
    return 3
  fi
  sysroot_cache_link "$sysroot_name" "$sysroot_directory"
  printf 'sysroot cache fetched: %s\n' "$sysroot_directory"
}

sysroot_cache_publish() {
  (($# >= 1 && $# <= 2)) || return 2
  local config_name=$(basename "$1")
  local sysroot_directory=${2:-$(sysroot_cache_default_sysroot "$config_name")}
  local archive repository temporary_directory
  archive=$(sysroot_cache_create "$config_name" "$sysroot_directory")
  command -v gh >/dev/null 2>&1 || {
    printf 'error: gh is required to publish the sysroot cache\n' >&2
    return 1
  }
  repository=${TITAN_CACHE_REPO:-TFSThiagoBR98/titan-flutter-engine}
  if ! gh release view sysroots-cache --repo "$repository" >/dev/null 2>&1; then
    gh release create sysroots-cache --repo "$repository" --prerelease \
      --title sysroots-cache --notes 'Buildroot sysroot cache'
  fi
  temporary_directory=$(mktemp -d)
  if gh release download sysroots-cache --repo "$repository" \
    --pattern "$(basename "$archive")" --dir "$temporary_directory" >/dev/null 2>&1; then
    rm -rf "$temporary_directory"
    printf 'sysroot cache already published: %s\n' "$archive"
    return 0
  fi
  rm -rf "$temporary_directory"
  gh release upload sysroots-cache "$archive" --repo "$repository"
  printf 'sysroot cache published: %s\n' "$archive"
}

usage() {
  printf 'Usage: scripts/sysroot-cache.sh fetch|publish <defconfig>\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  action=${1:-}
  config=${2:-}
  [[ $# -eq 2 ]] || {
    usage >&2
    exit 2
  }
  case "$action" in
    fetch) sysroot_cache_fetch "$config" ;;
    publish) sysroot_cache_publish "$config" ;;
    *) usage >&2; exit 2 ;;
  esac
fi
