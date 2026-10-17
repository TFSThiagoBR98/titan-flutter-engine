#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
patch_root="$repository_root/patches"
series_file="$patch_root/series"
runtime_folder=runtime-spi
runtime_branch=titan/runtime-spi
base_subject='titan: base series'

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

absolute_path() {
  local path=$1 parent_directory path_name
  parent_directory=$(dirname -- "$path")
  path_name=$(basename -- "$path")
  parent_directory=$(cd -- "$parent_directory" && pwd -P) || \
    die "path parent does not exist: $path"
  printf '%s/%s\n' "$parent_directory" "$path_name"
}

usage() {
  printf 'Usage: %s prepare <flutter_dir> <worktree_dir> | export <worktree_dir> <folder>\n' "$0"
}

read_flutter_commit() {
  local flutter_commit
  flutter_commit=$(sed -n 's/^flutter_commit=//p' "$repository_root/flutter.lock")
  [[ -n "$flutter_commit" ]] || die "flutter.lock is missing flutter_commit"
  printf '%s\n' "$flutter_commit"
}

series_folders() {
  python3 "$repository_root/scripts/patch_series.py" --series "$series_file" --all
}

patch_files() {
  local folder=$1
  find "$patch_root/$folder" -maxdepth 1 -type f -name '*.patch' -print | LC_ALL=C sort
}

patch_why() {
  local patch=$1 first_line=
  IFS= read -r first_line < "$patch" || true
  [[ "$first_line" == '# Why: '* ]] || die "patch $patch has no Why header"
  printf '%s\n' "${first_line:7}"
}

patch_repository() {
  local patch=$1 first_line= repo=.
  IFS= read -r first_line < "$patch" || true
  if [[ "$first_line" == '# Repo: '* ]]; then
    repo=${first_line#'# Repo: '}
  fi
  printf '%s\n' "$repo"
}

apply_patch_file() {
  local flutter_dir=$1 patch=$2 repo repo_root
  repo=$(patch_repository "$patch")
  if [[ "$repo" == . ]]; then
    repo_root=$flutter_dir
  else
    repo_root="$flutter_dir/$repo"
  fi
  [[ -d "$repo_root" ]] || die "patch repository does not exist: $repo"
  git -C "$repo_root" apply "$patch"
}

apply_base_patch() {
  local worktree_dir=$1 patch=$2 repo
  repo=$(patch_repository "$patch")
  if [[ "$repo" != . ]]; then
    printf 'skipping %s: targets %s\n' "$patch" "$repo"
    return 0
  fi
  apply_patch_file "$worktree_dir" "$patch"
}

validate_runtime_patch_repository() {
  local patch=$1 repo
  repo=$(patch_repository "$patch")
  [[ "$repo" == . ]] || \
    die "runtime-spi patches must target the Flutter repository: $patch"
}

stage_changes() {
  local worktree_dir=$1 path
  local -a changed_paths=()
  while IFS= read -r -d '' path; do
    changed_paths+=("$path")
  done < <(git -C "$worktree_dir" diff --name-only -z)
  while IFS= read -r -d '' path; do
    changed_paths+=("$path")
  done < <(git -C "$worktree_dir" ls-files --others --exclude-standard -z)
  if ((${#changed_paths[@]} > 0)); then
    git -C "$worktree_dir" add -- "${changed_paths[@]}"
  fi
}

runtime_patch_whys() {
  local patch
  RUNTIME_WHYS=()
  while IFS= read -r patch; do
    [[ -n "$patch" ]] || continue
    RUNTIME_WHYS+=("$(patch_why "$patch")")
  done < <(patch_files "$runtime_folder")
}

existing_worktree_matches_series() {
  local flutter_commit=$1 worktree_dir=$2 base_commit base_subject_actual commit index
  local -a commits=()
  runtime_patch_whys
  while IFS= read -r commit; do
    [[ -n "$commit" ]] || continue
    commits+=("$commit")
  done < <(git -C "$worktree_dir" rev-list --reverse "$flutter_commit"..HEAD)

  if ((${#commits[@]} == 0)); then
    return 1
  fi
  base_commit=${commits[0]}
  base_subject_actual=$(git -C "$worktree_dir" log -1 --format=%s "$base_commit")
  [[ "$base_subject_actual" == "$base_subject" ]] || return 2
  if ((${#commits[@]} - 1 != ${#RUNTIME_WHYS[@]})); then
    return 2
  fi
  for index in "${!RUNTIME_WHYS[@]}"; do
    commit=${commits[index + 1]}
    [[ "$(git -C "$worktree_dir" log -1 --format=%b "$commit")" == "${RUNTIME_WHYS[index]}" ]] || return 2
  done
  return 0
}

create_worktree() {
  local flutter_dir=$1 worktree_dir=$2 flutter_commit=$3 folder patch
  git -C "$flutter_dir" worktree add -B "$runtime_branch" "$worktree_dir" "$flutter_commit"

  while IFS= read -r folder; do
    [[ -n "$folder" && "$folder" != "$runtime_folder" ]] || break
    while IFS= read -r patch; do
      [[ -n "$patch" ]] || continue
      apply_base_patch "$worktree_dir" "$patch"
    done < <(patch_files "$folder")
  done < <(series_folders)

  stage_changes "$worktree_dir"
  git -C "$worktree_dir" commit --quiet --allow-empty -m "$base_subject"

  while IFS= read -r patch; do
    [[ -n "$patch" ]] || continue
    validate_runtime_patch_repository "$patch"
    apply_patch_file "$worktree_dir" "$patch"
    stage_changes "$worktree_dir"
    git -C "$worktree_dir" commit --quiet --allow-empty -m "$(patch_why "$patch")"
  done < <(patch_files "$runtime_folder")
}

prepare() {
  local flutter_dir=$1 worktree_dir=$2 flutter_commit existing_result
  flutter_dir=$(absolute_path "$flutter_dir")
  worktree_dir=$(absolute_path "$worktree_dir")
  [[ -d "$flutter_dir" ]] || die "Flutter repository does not exist: $flutter_dir"
  flutter_commit=$(read_flutter_commit)
  git -C "$flutter_dir" rev-parse --verify "$flutter_commit^{commit}" >/dev/null || \
    die "Flutter commit does not exist: $flutter_commit"

  if [[ -e "$worktree_dir" ]]; then
    git -C "$worktree_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
      die "worktree path is not a Git worktree: $worktree_dir"
    if existing_worktree_matches_series "$flutter_commit" "$worktree_dir"; then
      printf 'prepared worktree already matches the patch series: %s\n' "$worktree_dir"
      return 0
    else
      existing_result=$?
    fi
    if ((existing_result == 2)); then
      die "unexported commits in $worktree_dir"
    fi
    git -C "$flutter_dir" worktree remove --force "$worktree_dir"
  fi

  create_worktree "$flutter_dir" "$worktree_dir" "$flutter_commit"
  printf 'prepared %s on %s\n' "$worktree_dir" "$runtime_branch"
}

commit_body() {
  local worktree_dir=$1 commit=$2 body
  body=$(git -C "$worktree_dir" log -1 --format=%b "$commit")
  [[ -n "$(printf '%s' "$body" | sed '/^[[:space:]]*$/d')" ]] || \
    die "commit $commit has no Why body"
  printf '%s\n' "$body"
}

commit_slug() {
  local subject=$1
  printf '%s' "$subject" | python3 -c \
    'import re, sys; print(re.sub(r"[^a-z0-9]+", "-", sys.stdin.read().strip().lower()).strip("-"))'
}

why_header() {
  local body=$1
  printf '%s' "$body" | python3 -c \
    'import re, sys, textwrap; body = re.sub(r"(?i)^\s*why\s*:\s*", "", sys.stdin.read().strip(), count=1); print(textwrap.fill("# Why: " + body, width=78, subsequent_indent="# "))'
}

export_patches() {
  local worktree_dir=$1 folder=$2 flutter_commit base_commit commit subject body slug output why index
  local target_directory="$repository_root/patches/$folder"
  local temporary_output
  local -a commits=()
  worktree_dir=$(absolute_path "$worktree_dir")
  [[ -d "$worktree_dir" ]] || die "worktree does not exist: $worktree_dir"
  [[ -d "$target_directory" ]] || die "patch folder does not exist: $target_directory"
  flutter_commit=$(read_flutter_commit)
  while IFS= read -r commit; do
    [[ -n "$commit" ]] || continue
    commits+=("$commit")
  done < <(git -C "$worktree_dir" rev-list --reverse "$flutter_commit"..HEAD)
  ((${#commits[@]} > 0)) || die "worktree has no $base_subject commit"
  base_commit=${commits[0]}
  [[ "$(git -C "$worktree_dir" log -1 --format=%s "$base_commit")" == "$base_subject" ]] || \
    die "worktree has no $base_subject commit"
  ((${#commits[@]} > 1)) || {
    printf 'no new commits to export from %s\n' "$worktree_dir"
    return 0
  }

  temporary_output=$(mktemp -d)
  trap 'rm -rf "$temporary_output"' RETURN
  for index in "${!commits[@]}"; do
    ((index > 0)) || continue
    commit=${commits[index]}
    body=$(commit_body "$worktree_dir" "$commit")
    subject=$(git -C "$worktree_dir" log -1 --format=%s "$commit")
    slug=$(commit_slug "$subject")
    [[ -n "$slug" ]] || die "commit $commit has no slug"
    output=$(printf '%s/%04d-%s.patch' "$temporary_output" "$index" "$slug")
    {
      why_header "$body"
      git -C "$worktree_dir" diff --binary "$commit^" "$commit"
    } > "$output"
  done

  find "$target_directory" -maxdepth 1 -type f -name '*.patch' -delete
  mv "$temporary_output"/*.patch "$target_directory/"
  trap - RETURN
  rm -rf "$temporary_output"
  printf 'exported %d patch(es) to %s\n' "$(( ${#commits[@]} - 1 ))" "$target_directory"
}

main() {
  local command=${1:-}
  case "$command" in
    prepare)
      [[ $# -eq 3 ]] || { usage >&2; exit 2; }
      prepare "$2" "$3"
      ;;
    export)
      [[ $# -eq 3 ]] || { usage >&2; exit 2; }
      export_patches "$2" "$3"
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
