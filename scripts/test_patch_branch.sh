#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

assert_contains() {
  local file=$1 expected=$2 description=$3
  grep -Fq -- "$expected" "$file" || {
    printf 'error: %s: expected %q in %s\n' "$description" "$expected" "$file" >&2
    exit 1
  }
}

assert_same_tree() {
  local first_tree=$1 second_tree=$2
  if ! diff -ru --exclude=.git "$first_tree" "$second_tree"; then
    printf 'error: patch series did not reproduce the prepared tree\n' >&2
    exit 1
  fi
}

standalone_repository="$temporary_directory/titan-flutter-engine"
flutter_directory="$temporary_directory/flutter"
worktree_directory="$temporary_directory/runtime-spi-src"
clone_directory="$temporary_directory/clean-clone"
mkdir -p "$standalone_repository/scripts" "$standalone_repository/patches/base-series" \
  "$standalone_repository/patches/runtime-spi"
cp "$repository_root/scripts/patch_series.py" "$standalone_repository/scripts/patch_series.py"
cp "$repository_root/scripts/patch-branch.sh" "$standalone_repository/scripts/patch-branch.sh"
chmod +x "$standalone_repository/scripts/patch-branch.sh"
printf '%s\n' base-series runtime-spi > "$standalone_repository/patches/series"

git init --quiet "$flutter_directory"
git -C "$flutter_directory" config user.email test@example.invalid
git -C "$flutter_directory" config user.name "Patch Branch Test"
printf '%s\n' 'base content' > "$flutter_directory/README"
git -C "$flutter_directory" add -- README
git -C "$flutter_directory" commit --quiet -m 'test: Flutter base'
flutter_head_before=$(git -C "$flutter_directory" rev-parse HEAD)
status_before=$(git -C "$flutter_directory" status --porcelain)
printf 'flutter_commit=%s\n' "$flutter_head_before" > "$standalone_repository/flutter.lock"

cat > "$standalone_repository/patches/base-series/0001-base.patch" <<'EOF'
# Why: apply the base series
diff --git a/README b/README
--- a/README
+++ b/README
@@ -1 +1 @@
-base content
+base series content
EOF

cat > "$standalone_repository/patches/base-series/0002-dependency.patch" <<'EOF'
# Repo: third_party/dep
# Why: skip dependency repository
diff --git a/README b/README
--- a/README
+++ b/README
@@ -1 +1 @@
-base content
+dependency content
EOF

run_patch_branch() {
  (
    cd "$standalone_repository"
    "$standalone_repository/scripts/patch-branch.sh" "$@"
  )
}

relative_worktree_path=relative-runtime-spi-src
relative_worktree_directory="$temporary_directory/$relative_worktree_path"
relative_flutter_path=flutter
relative_prepare_output="$temporary_directory/relative-prepare.out"
(
  cd "$temporary_directory"
  "$standalone_repository/scripts/patch-branch.sh" prepare "$relative_flutter_path" \
    "$relative_worktree_path"
) >"$relative_prepare_output"
assert_contains "$relative_prepare_output" \
  "skipping $standalone_repository/patches/base-series/0002-dependency.patch: targets third_party/dep" \
  'dependency repository patch skip'
[[ -d "$relative_worktree_directory" ]] || {
  printf 'error: relative prepare did not create the worktree beside the source\n' >&2
  exit 1
}
[[ ! -d "$flutter_directory/$relative_worktree_path" ]] || {
  printf 'error: relative prepare created the worktree inside the source\n' >&2
  exit 1
}
relative_worktree_absolute=$(cd "$relative_worktree_directory" && pwd -P)
assert_contains <(git -C "$flutter_directory" worktree list --porcelain) \
  "worktree $relative_worktree_absolute" 'relative worktree path'
printf '%s\n' 'relative runtime change' > "$relative_worktree_directory/relative.txt"
git -C "$relative_worktree_directory" add -- relative.txt
git -C "$relative_worktree_directory" commit --quiet -m 'feat: relative seam' -m 'relative runtime reason'
(
  cd "$temporary_directory"
  "$standalone_repository/scripts/patch-branch.sh" export \
    "$relative_worktree_path" runtime-spi
)
relative_patch="$standalone_repository/patches/runtime-spi/0001-feat-relative-seam.patch"
[[ -f "$relative_patch" ]] || {
  printf 'error: relative export did not create the expected patch\n' >&2
  exit 1
}
assert_contains "$relative_patch" '# Why: relative runtime reason' 'relative Why header'
assert_contains "$relative_patch" 'diff --git' 'relative diff header'
rm -f "$relative_patch"
git -C "$flutter_directory" worktree remove --force "$relative_worktree_directory"

cat > "$standalone_repository/patches/runtime-spi/0001-invalid-repository.patch" <<'EOF'
# Repo: third_party/dep
# Why: invalid runtime repository
diff --git a/README b/README
--- a/README
+++ b/README
@@ -1 +1 @@
-base content
+invalid runtime content
EOF
runtime_repository_output="$temporary_directory/runtime-repository.out"
if run_patch_branch prepare "$flutter_directory" "$worktree_directory" >"$runtime_repository_output" 2>&1; then
  printf 'error: prepare accepted a runtime patch for another repository\n' >&2
  exit 1
fi
assert_contains "$runtime_repository_output" \
  "runtime-spi patches must target the Flutter repository: $standalone_repository/patches/runtime-spi/0001-invalid-repository.patch" \
  'runtime repository rejection'
rm -f "$standalone_repository/patches/runtime-spi/0001-invalid-repository.patch"

prepare_output="$temporary_directory/prepare.out"
run_patch_branch prepare "$flutter_directory" "$worktree_directory" >"$prepare_output"
[[ "$(git -C "$flutter_directory" rev-parse HEAD)" == "$flutter_head_before" ]] || {
  printf 'error: prepare changed the source HEAD\n' >&2
  exit 1
}
[[ "$(git -C "$flutter_directory" status --porcelain)" == "$status_before" ]] || {
  printf 'error: prepare changed the source status\n' >&2
  exit 1
}
[[ "$(git -C "$worktree_directory" branch --show-current)" == titan/runtime-spi ]] || {
  printf 'error: prepare did not create titan/runtime-spi\n' >&2
  exit 1
}
[[ "$(<"$worktree_directory/README")" == 'base series content' ]] || {
  printf 'error: base series was not applied\n' >&2
  exit 1
}
[[ "$(git -C "$worktree_directory" log --format=%s --reverse -2 | tail -n 1)" == 'titan: base series' ]] || {
  printf 'error: base series commit is missing\n' >&2
  exit 1
}

printf '%s\n' 'unexported change' > "$worktree_directory/unexported.txt"
git -C "$worktree_directory" add -- unexported.txt
git -C "$worktree_directory" commit --quiet -m 'test: unexported change'
unexported_output="$temporary_directory/unexported.out"
if run_patch_branch prepare "$flutter_directory" "$worktree_directory" >"$unexported_output" 2>&1; then
  printf 'error: prepare accepted an unexported commit\n' >&2
  exit 1
fi
assert_contains "$unexported_output" "unexported commits in $worktree_directory" \
  'unexported commit rejection'

git -C "$flutter_directory" worktree remove --force "$worktree_directory"
run_patch_branch prepare "$flutter_directory" "$worktree_directory"
rm -f "$standalone_repository/patches/base-series/0002-dependency.patch"
printf '%s\n' 'first runtime change' > "$worktree_directory/first.txt"
git -C "$worktree_directory" add -- first.txt
git -C "$worktree_directory" commit --quiet -m 'feat: first seam' -m 'first runtime reason'
printf '%s\n' 'second runtime change' > "$worktree_directory/second.txt"
git -C "$worktree_directory" add -- second.txt
git -C "$worktree_directory" commit --quiet -m 'feat: second seam' -m 'second runtime reason'

run_patch_branch export "$worktree_directory" runtime-spi
first_patch="$standalone_repository/patches/runtime-spi/0001-feat-first-seam.patch"
second_patch="$standalone_repository/patches/runtime-spi/0002-feat-second-seam.patch"
[[ -f "$first_patch" && -f "$second_patch" ]] || {
  printf 'error: export did not create the numbered patches\n' >&2
  exit 1
}
assert_contains "$first_patch" '# Why: first runtime reason' 'first Why header'
assert_contains "$first_patch" 'diff --git' 'first diff header'
assert_contains "$second_patch" '# Why: second runtime reason' 'second Why header'
assert_contains "$second_patch" 'diff --git' 'second diff header'

git clone --quiet --no-local "$flutter_directory" "$clone_directory"
while IFS= read -r folder; do
  [[ -n "$folder" ]] || continue
  while IFS= read -r patch_path; do
    git -C "$clone_directory" apply "$standalone_repository/$patch_path"
  done < <(find "$standalone_repository/patches/$folder" -maxdepth 1 -type f -name '*.patch' -print | LC_ALL=C sort | sed "s#^$standalone_repository/##")
done < <(python3 "$standalone_repository/scripts/patch_series.py" --series "$standalone_repository/patches/series" --all)
assert_same_tree "$worktree_directory" "$clone_directory"

patches_before=$(find "$standalone_repository/patches/runtime-spi" -maxdepth 1 -type f -name '*.patch' -print0 | xargs -0 sha256sum)
run_patch_branch export "$worktree_directory" runtime-spi
patches_after=$(find "$standalone_repository/patches/runtime-spi" -maxdepth 1 -type f -name '*.patch' -print0 | xargs -0 sha256sum)
[[ "$patches_before" == "$patches_after" ]] || {
  printf 'error: export without new commits was not idempotent\n' >&2
  exit 1
}

printf '%s\n' 'invalid runtime change' > "$worktree_directory/invalid.txt"
git -C "$worktree_directory" add -- invalid.txt
git -C "$worktree_directory" commit --quiet -m 'feat: missing why body'
invalid_sha=$(git -C "$worktree_directory" rev-parse HEAD)
invalid_output="$temporary_directory/invalid.out"
if run_patch_branch export "$worktree_directory" runtime-spi >"$invalid_output" 2>&1; then
  printf 'error: export accepted a commit without a body\n' >&2
  exit 1
fi
assert_contains "$invalid_output" "commit $invalid_sha has no Why body" 'missing Why body error'

printf 'test_patch_branch.sh: ok\n'
