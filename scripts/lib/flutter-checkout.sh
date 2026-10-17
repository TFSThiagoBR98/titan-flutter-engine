#!/usr/bin/env bash

write_gclient() {
  local flutter_dir=$1
  local target_os=$2
  local gclient_path="$flutter_dir/.gclient"
  local temporary_gclient

  temporary_gclient=$(mktemp "$flutter_dir/.gclient.XXXXXX")
  if ! python3 - "$gclient_path" "$target_os" > "$temporary_gclient" <<'PY'
import json
import re
import sys
from pathlib import Path

gclient_path = Path(sys.argv[1])
target_os = sys.argv[2]
target_custom_vars = {
    "linux": {
        "download_android_deps": False,
        "download_emsdk": False,
        "download_esbuild": False,
        "download_fuchsia_deps": False,
        "setup_githooks": False,
    },
    "fuchsia": {
        "download_android_deps": False,
        "download_emsdk": False,
        "download_esbuild": False,
        "download_fuchsia_deps": False,
        "setup_githooks": False,
    },
    "android": {
        "download_android_deps": True,
        "download_emsdk": False,
        "download_esbuild": False,
        "download_fuchsia_deps": False,
        "setup_githooks": False,
    },
    "web": {
        "download_android_deps": False,
        "download_emsdk": True,
        "download_esbuild": True,
        "download_fuchsia_deps": False,
        "setup_githooks": False,
    },
    "macos": {
        "download_android_deps": True,
        "download_emsdk": False,
        "download_esbuild": True,
        "download_fuchsia_deps": False,
        "setup_githooks": False,
    },
}

try:
    custom_vars = target_custom_vars[target_os]
except KeyError as error:
    raise SystemExit(f"unsupported gclient target: {target_os}") from error

if gclient_path.exists():
    namespace = {}
    exec(gclient_path.read_text(encoding="utf-8"), {}, namespace)
    solutions = namespace.get("solutions")
    if not isinstance(solutions, list) or not solutions:
        raise SystemExit(f"invalid gclient solutions: {gclient_path}")
else:
    solutions = [
        {
            "custom_deps": {},
            "deps_file": "DEPS",
            "managed": False,
            "name": ".",
            "safesync_url": "",
            "url": "https://github.com/flutter/flutter.git",
        }
    ]

solution = solutions[0]
solution.setdefault("custom_vars", {}).update(custom_vars)
serialized_solutions = json.dumps(solutions, indent=2)
serialized_solutions = re.sub(r"\btrue\b", "True", serialized_solutions)
serialized_solutions = re.sub(r"\bfalse\b", "False", serialized_solutions)
serialized_solutions = re.sub(r"\bnull\b", "None", serialized_solutions)
print("solutions = " + serialized_solutions)
PY
  then
    rm -f "$temporary_gclient"
    return 2
  fi

  if [[ -f "$gclient_path" ]] && cmp -s "$temporary_gclient" "$gclient_path"; then
    rm -f "$temporary_gclient"
    return 1
  fi
  mv "$temporary_gclient" "$gclient_path"
  return 0
} # write_gclient

flutter_checkout() {
  local repository_root=$1
  local work_root=$2
  local target_os=$3
  local flutter_commit=$4
  local depot_tools="$work_root/depot_tools"
  local flutter_dir="$work_root/flutter"
  local engine_src="$flutter_dir/engine/src"
  local patch_dir="$repository_root/patches"
  local series_file="$patch_dir/series"
  local lock="$repository_root/flutter.lock"
  local bootstrap=0
  local flutter_checkout_new=0
  local gclient_needs_sync=0
  local patch_lock="$work_root/.titan-patches.lock"
  local patch_state="$flutter_dir/.titan-patches.sha256"
  local patches_sha256_actual
  local actual_commit
  local patch_repo
  local patch_root
  local patch
  local -a patch_folders=()
  local -a patches=()
  local -a all_patch_paths=()
  local -a all_patch_repositories=()

  [[ -f "$lock" ]] || die "Flutter lock is missing: $lock"
  [[ -f "$series_file" ]] || die "patch series is missing: $series_file"

  while IFS= read -r folder; do
    [[ -n "$folder" ]] || continue
    patch_folders+=("$patch_dir/$folder")
  done < <(python3 "$repository_root/scripts/patch_series.py" --series "$series_file" --all)

  for folder in "${patch_folders[@]}"; do
    [[ -d "$folder" ]] || die "patch folder does not exist: $folder"
    while IFS= read -r patch; do
      patches+=("$patch")
    done < <(find "$folder" -maxdepth 1 -type f -name '*.patch' -print | LC_ALL=C sort)
  done

  while IFS=$'\t' read -r repo path; do
    [[ -n "$repo" && -n "$path" ]] || continue
    all_patch_repositories+=("$repo")
    all_patch_paths+=("$path")
  done < <(python3 "$repository_root/scripts/patch_series.py" --patch-root "$patch_dir" --paths)

  if ((${#patches[@]} == 0)); then
    patches_sha256_actual=$(printf '' | sha256sum | cut -d' ' -f1)
  else
    patches_sha256_actual=$({ cat "$series_file"; cat "${patches[@]}"; } | sha256sum | cut -d' ' -f1)
  fi

  mkdir -p "$work_root"
  export DEPOT_TOOLS_UPDATE=0
  export DEPOT_TOOLS_METRICS=0
  export PATH="$depot_tools:$PATH"

  if [[ ! -d "$depot_tools" ]]; then
    printf 'bootstrapping depot_tools in %s\n' "$depot_tools"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$depot_tools"
    bootstrap=1
  fi
  if [[ ! -f "$depot_tools/python3_bin_reldir.txt" ]]; then
    "$depot_tools/ensure_bootstrap"
  fi

  if [[ ! -d "$flutter_dir/.git" && ! -f "$flutter_dir/.git" ]]; then
    printf 'bootstrapping Flutter in %s\n' "$flutter_dir"
    git init "$flutter_dir"
    git -C "$flutter_dir" remote add origin https://github.com/flutter/flutter.git
    bootstrap=1
    flutter_checkout_new=1
  fi

  if write_gclient "$flutter_dir" "$target_os"; then
    gclient_needs_sync=1
  fi

  if ((bootstrap)); then
    if ((flutter_checkout_new)); then
      git -C "$flutter_dir" fetch --depth 1 origin "$flutter_commit"
      git -C "$flutter_dir" checkout --detach FETCH_HEAD
    else
      git -C "$flutter_dir" fetch origin "$flutter_commit"
      git -C "$flutter_dir" checkout --detach "$flutter_commit"
    fi
  fi
  if ((bootstrap || gclient_needs_sync)); then
    (cd "$flutter_dir" && gclient sync -D --no-history)
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
    local repo repo_root revision path target index
    local -a tracked_paths=()
    local -a created_paths=()
    local -a repositories=()
    declare -A seen_repositories=()

    for repo in "${all_patch_repositories[@]}"; do
      if [[ -z "${seen_repositories[$repo]+present}" ]]; then
        seen_repositories["$repo"]=1
        repositories+=("$repo")
      fi
    done

    for repo in "${repositories[@]}"; do
      tracked_paths=()
      created_paths=()
      if [[ "$repo" == . ]]; then
        repo_root=$flutter_dir
        revision=$flutter_commit
      else
        repo_root="$flutter_dir/$repo"
        revision=HEAD
      fi
      [[ -d "$repo_root" ]] || die "patch repository does not exist: $repo"

      for index in "${!all_patch_paths[@]}"; do
        [[ "${all_patch_repositories[index]}" == "$repo" ]] || continue
        path=${all_patch_paths[index]}
        if git -C "$repo_root" cat-file -e "$revision:$path" 2>/dev/null; then
          tracked_paths+=("$path")
        else
          created_paths+=("$path")
        fi
      done

      for path in "${created_paths[@]}"; do
        target="$repo_root/$path"
        if [[ -e "$target" || -L "$target" ]]; then
          [[ -f "$target" || -L "$target" ]] || die "patch-created path is not a file: $repo/$path"
          rm -f -- "$target"
        fi
      done
      if ((${#tracked_paths[@]} > 0)); then
        git -C "$repo_root" checkout "$revision" -- "${tracked_paths[@]}"
      fi
    done
  }

  patch_repository() {
    local patch=$1 first_line repo=.
    IFS= read -r first_line < "$patch" || true
    if [[ "$first_line" == '# Repo: '* ]]; then
      repo=${first_line#'# Repo: '}
    fi
    printf '%s\n' "$repo"
  }

  patch_checkout() {
    local repo=$1
    if [[ "$repo" == . ]]; then
      printf '%s\n' "$flutter_dir"
    else
      [[ -d "$flutter_dir/$repo" ]] || die "patch repository does not exist: $repo"
      printf '%s\n' "$flutter_dir/$repo"
    fi
  }

  (
    flock 9
    if [[ -f "$patch_state" && "$(<"$patch_state")" == "$patches_sha256_actual" ]]; then
      printf 'patch series already applied: %s\n' "$patches_sha256_actual"
    else
      restore_patch_paths
      for patch in "${patches[@]}"; do
        patch_repo=$(patch_repository "$patch")
        patch_root=$(patch_checkout "$patch_repo")
        printf 'applying %s\n' "$patch"
        git -C "$patch_root" apply "$patch"
      done
      printf '%s\n' "$patches_sha256_actual" > "$patch_state"
      printf 'applied patch series: %s\n' "$patches_sha256_actual"
    fi
  ) 9>"$patch_lock"

  FLUTTER_CHECKOUT_DIR=$flutter_dir
  FLUTTER_ENGINE_SOURCE_DIR=$engine_src
  FLUTTER_PATCHES_SHA256=$patches_sha256_actual
}
