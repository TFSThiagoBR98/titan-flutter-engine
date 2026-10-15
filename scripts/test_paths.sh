#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  local expected=$1 actual=$2 description=$3
  [[ "$actual" == "$expected" ]] || fail "$description: expected '$expected', got '$actual'"
}

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

standalone_repository="$temporary_directory/titan-flutter-engine"
git clone --quiet --no-local "$repository_root" "$standalone_repository"
mkdir -p "$standalone_repository/scripts/lib"
cp "$repository_root/scripts/lib/paths.sh" "$standalone_repository/scripts/lib/paths.sh"
standalone_paths=$(cd "$standalone_repository" && bash -c '
  source scripts/lib/paths.sh
  printf "%s\n%s\n" "$TITAN_WORK_DIR" "$TITAN_BUNDLE_DIR"
')
mapfile -t standalone_values <<<"$standalone_paths"
assert_equal "$standalone_repository/.build_flutter" "${standalone_values[0]}" \
  "standalone work directory"
assert_equal "$standalone_repository/artifacts" "${standalone_values[1]}" \
  "standalone bundle directory"

superproject_root=$(git -C "$repository_root" rev-parse --show-superproject-working-tree)
superproject_paths=$(cd "$repository_root" && bash -c '
  source scripts/lib/paths.sh
  printf "%s\n%s\n" "$TITAN_WORK_DIR" "$TITAN_BUNDLE_DIR"
')
mapfile -t superproject_values <<<"$superproject_paths"
assert_equal "$superproject_root/.build_flutter" "${superproject_values[0]}" \
  "superproject work directory"
assert_equal "$superproject_root/third_party/flutter-engine" "${superproject_values[1]}" \
  "superproject bundle directory"

defined_work="$temporary_directory/defined-work"
defined_bundle="$temporary_directory/defined-bundle"
defined_paths=$(TITAN_WORK_DIR="$defined_work" TITAN_BUNDLE_DIR="$defined_bundle" \
  bash -c "cd '$repository_root' && source scripts/lib/paths.sh && printf '%s\\n%s\\n' \"\$TITAN_WORK_DIR\" \"\$TITAN_BUNDLE_DIR\"")
mapfile -t defined_values <<<"$defined_paths"
assert_equal "$defined_work" "${defined_values[0]}" "defined work directory"
assert_equal "$defined_bundle" "${defined_values[1]}" "defined bundle directory"

printf 'test_paths.sh: ok\n'
