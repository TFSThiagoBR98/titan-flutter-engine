#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"

# Bump when make-buildroot-sysroot.sh changes what goes into a sysroot (for
# example the GCC runtime copy). The key hashes this instead of the whole script,
# so edits that do not change the content keep the published caches valid.
sysroot_layout_version=1

sysroot_key() {
  (($# == 1)) || {
    printf 'error: sysroot_key requires a defconfig\n' >&2
    return 2
  }

  local config_name=$(basename "$1")
  local config_path="$TITAN_REPOSITORY_ROOT/buildroot/configs/$config_name"
  local lock_path="$TITAN_REPOSITORY_ROOT/buildroot/buildroot.lock"
  [[ -f "$config_path" ]] || {
    printf 'error: Buildroot config does not exist: %s\n' "$config_path" >&2
    return 1
  }
  [[ -f "$lock_path" ]] || {
    printf 'error: Buildroot lock does not exist: %s\n' "$lock_path" >&2
    return 1
  }

  {
    printf 'defconfig:%s\n' "$config_name"
    sha256sum < "$config_path"
    while IFS= read -r -d '' path; do
      printf 'buildroot-file:%s\n' "${path#"$TITAN_REPOSITORY_ROOT/"}"
      sha256sum < "$path"
    done < <(find "$TITAN_REPOSITORY_ROOT/buildroot" -type f -print0 | LC_ALL=C sort -z)
    printf 'buildroot-lock\n'
    sha256sum < "$lock_path"
    printf 'sysroot-layout:%s\n' "$sysroot_layout_version"
  } | sha256sum | awk '{print $1}'
}

sysroot_stamp_path() {
  (($# == 1)) || return 2
  printf '%s/.titan-sysroot-key\n' "$1"
}

sysroot_stamp_matches() {
  (($# == 2)) || return 2
  local stamp
  stamp=$(sysroot_stamp_path "$1")
  [[ -s "$stamp" ]] && [[ "$(<"$stamp")" == "$2" ]]
}

sysroot_has_stamp() {
  (($# == 1)) || return 2
  [[ -s "$(sysroot_stamp_path "$1")" ]]
}
