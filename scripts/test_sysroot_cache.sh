#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

defconfig=titan_x64_musl_defconfig
other_defconfig=titan_arm64_glibc_defconfig
work_root="$temporary_directory/work"
state_root="$temporary_directory/gh-state"
fake_bin="$temporary_directory/bin"
sysroot_name=titan_x64_musl
sysroot="$work_root/sysroots/$sysroot_name"
mkdir -p "$sysroot" "$state_root/assets" "$fake_bin"

key=$(bash -c "source '$repository_root/scripts/lib/sysroot.sh'; sysroot_key '$defconfig'")
other_key=$(bash -c "source '$repository_root/scripts/lib/sysroot.sh'; sysroot_key '$other_defconfig'")
printf '%s\n' "$key" > "$sysroot/.titan-sysroot-key"
printf '%s\n' cache-fixture > "$sysroot/fixture.txt"

cat > "$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_root=${TITAN_GH_STATE:?}
release_directory="$state_root/releases/sysroots-cache"
assets_directory="$release_directory/assets"
mkdir -p "$state_root/releases"
[[ "${1:-}" == release ]] || exit 2
command=${2:-}
tag=${3:-}
[[ "$tag" == sysroots-cache ]] || exit 2
case "$command" in
  view)
    if [[ "${4:-}" == --json ]]; then
      [[ -d "$assets_directory" ]] || exit 1
      find "$assets_directory" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort
    else
      [[ -d "$release_directory" ]]
    fi
    ;;
  create)
    mkdir -p "$assets_directory"
    printf '%s\n' "$*" >> "$state_root/operations.log"
    ;;
  download)
    pattern=
    destination=.
    while (($# > 0)); do
      case "$1" in
        --pattern) pattern=$2; shift 2 ;;
        --dir) destination=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -f "$assets_directory/$pattern" ]] || exit 1
    mkdir -p "$destination"
    cp "$assets_directory/$pattern" "$destination/$pattern"
    ;;
  upload)
    archive=${4:-}
    [[ -f "$archive" ]] || exit 1
    mkdir -p "$assets_directory"
    [[ ! -e "$assets_directory/$(basename "$archive")" ]] || exit 1
    cp "$archive" "$assets_directory/"
    printf '%s\n' "$*" >> "$state_root/operations.log"
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$fake_bin/gh"
cat > "$fake_bin/make" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_MAKE_LOG"
exit 99
EOF
chmod +x "$fake_bin/make"

run_cache() {
  TITAN_WORK_DIR="$work_root" \
  TITAN_CACHE_REPO=example/titan-flutter-engine \
  TITAN_GH_STATE="$state_root" \
  PATH="$fake_bin:$PATH" \
    "$repository_root/scripts/sysroot-cache.sh" "$@"
}

run_cache publish "$defconfig"
archive="sysroot-$sysroot_name-${key:0:16}.tar.zst"
[[ -f "$work_root/sysroot-cache/$archive" ]] || {
  printf 'local cache archive is missing\n' >&2
  exit 1
}
[[ -f "$state_root/releases/sysroots-cache/assets/$archive" ]] || {
  printf 'published cache archive is missing\n' >&2
  exit 1
}
[[ "$(grep -c 'upload' "$state_root/operations.log")" -eq 1 ]] || {
  printf 'initial publish did not upload exactly once\n' >&2
  exit 1
}

run_cache publish "$defconfig"
[[ "$(grep -c 'upload' "$state_root/operations.log")" -eq 1 ]] || {
  printf 'idempotent publish uploaded the same asset again\n' >&2
  exit 1
}

rm -rf "$sysroot"
run_cache fetch "$defconfig"
[[ "$(<"$sysroot/fixture.txt")" == cache-fixture ]] || {
  printf 'local cache fetch did not restore the sysroot\n' >&2
  exit 1
}

rm "$work_root/sysroot-cache/$archive"
rm -rf "$sysroot"
run_cache fetch "$defconfig"
[[ "$(<"$sysroot/fixture.txt")" == cache-fixture ]] || {
  printf 'release cache fetch did not restore the sysroot\n' >&2
  exit 1
}

make_work="$temporary_directory/make-work"
make_sysroot="$make_work/sysroots/$sysroot_name"
mkdir -p "$make_work/buildroot"
git -C "$make_work/buildroot" init --quiet
git -C "$make_work/buildroot" config user.email test@example.invalid
git -C "$make_work/buildroot" config user.name 'Sysroot Cache Test'
git -C "$make_work/buildroot" commit --quiet --allow-empty -m 'test: fake Buildroot'
git -C "$make_work/buildroot" tag "$(sed -n 's/^tag=//p' "$repository_root/buildroot/buildroot.lock")"
TITAN_WORK_DIR="$make_work" \
TITAN_CACHE_REPO=example/titan-flutter-engine \
TITAN_GH_STATE="$state_root" \
TITAN_CPU_SCOPE=0 \
TITAN_MAKE_LOG="$temporary_directory/make-integration.log" \
PATH="$fake_bin:$PATH" \
  "$repository_root/scripts/make-buildroot-sysroot.sh" \
    --config "$defconfig" --out "$make_sysroot" > "$temporary_directory/make-integration.log.out"
[[ -f "$make_sysroot/.titan-sysroot-key" ]] || {
  printf 'make-buildroot-sysroot did not restore the fetched cache\n' >&2
  exit 1
}
[[ ! -s "$temporary_directory/make-integration.log" ]] || {
  printf 'make-buildroot-sysroot invoked Buildroot after a cache hit\n' >&2
  cat "$temporary_directory/make-integration.log" >&2
  exit 1
}

missing_status=0
if run_cache fetch "$other_defconfig" > "$temporary_directory/missing.log" 2>&1; then
  printf 'missing cache unexpectedly succeeded\n' >&2
  exit 1
else
  missing_status=$?
fi
[[ "$missing_status" -eq 3 ]] || {
  printf 'missing cache returned %s instead of 3\n' "$missing_status" >&2
  exit 1
}
grep -Fq 'no sysroot cache' "$temporary_directory/missing.log"
[[ "$key" != "$other_key" ]] || {
  printf 'different defconfigs produced the same cache key\n' >&2
  exit 1
}

printf 'test_sysroot_cache.sh: ok\n'
