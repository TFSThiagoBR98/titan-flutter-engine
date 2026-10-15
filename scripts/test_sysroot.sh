#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

defconfig=titan_x64_musl_defconfig
other_defconfig=titan_arm64_glibc_defconfig
work_root="$temporary_directory/work"
fake_bin="$temporary_directory/bin"
make_log="$temporary_directory/make.log"
sysroot="$temporary_directory/sysroot"
mkdir -p "$fake_bin" "$work_root/buildroot"

key=$(bash -c "source '$repository_root/scripts/lib/sysroot.sh'; sysroot_key '$defconfig'")
other_key=$(bash -c "source '$repository_root/scripts/lib/sysroot.sh'; sysroot_key '$other_defconfig'")
[[ "$key" =~ ^[0-9a-f]{64}$ ]] || {
  printf 'invalid sysroot key: %s\n' "$key" >&2
  exit 1
}
[[ "$key" != "$other_key" ]] || {
  printf 'different defconfigs produced the same sysroot key\n' >&2
  exit 1
}

buildroot_tag=$(sed -n 's/^tag=//p' "$repository_root/buildroot/buildroot.lock")
git -C "$work_root/buildroot" init --quiet
git -C "$work_root/buildroot" config user.email test@example.invalid
git -C "$work_root/buildroot" config user.name 'Sysroot Test'
git -C "$work_root/buildroot" commit --quiet --allow-empty -m 'test: fake Buildroot'
git -C "$work_root/buildroot" tag "$buildroot_tag"

cat > "$fake_bin/make" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_MAKE_LOG"
output=
for argument in "$@"; do
  case "$argument" in
    O=*) output=${argument#O=} ;;
  esac
done
[[ -n "$output" ]] || exit 1
mkdir -p "$output/staging/usr/include" "$output/host/lib/gcc/x86_64-linux-musl/14.3.0"
: > "$output/staging/usr/include/stdio.h"
: > "$output/host/lib/gcc/x86_64-linux-musl/14.3.0/crtbegin.o"
: > "$output/host/lib/gcc/x86_64-linux-musl/14.3.0/crtend.o"
: > "$output/host/lib/gcc/x86_64-linux-musl/14.3.0/libgcc.a"
: > "$output/host/lib/gcc/x86_64-linux-musl/14.3.0/libgcc_eh.a"
EOF
chmod +x "$fake_bin/make"

# Never reach the real sysroots-cache release: downloads miss, uploads are logged.
gh_log="$temporary_directory/gh.log"
cat > "$fake_bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TITAN_GH_LOG"
case "$1 $2" in
  "release view") exit 0 ;;
  "release upload") exit 0 ;;
  *) exit 1 ;;
esac
GH
chmod +x "$fake_bin/gh"

run_sysroot() {
  TITAN_WORK_DIR="$work_root" \
  TITAN_MAKE_LOG="$make_log" \
  TITAN_GH_LOG="$gh_log" \
  TITAN_CPU_SCOPE=0 \
  PATH="$fake_bin:$PATH" \
    "$repository_root/scripts/make-buildroot-sysroot.sh" \
      --config "$defconfig" --out "$sysroot" "$@"
}

run_sysroot > "$temporary_directory/first.log"
[[ "$(wc -l < "$make_log")" -eq 2 ]] || {
  printf 'expected two Buildroot invocations on first build\n' >&2
  cat "$make_log" >&2
  exit 1
}
[[ "$(<"$sysroot/.titan-sysroot-key")" == "$key" ]] || {
  printf 'sysroot stamp does not contain the key\n' >&2
  exit 1
}
engine_link="$work_root/flutter/engine/src/build/linux/titan_x64_musl-sysroot"
[[ -L "$engine_link" && "$(readlink "$engine_link")" == "$sysroot" ]] || {
  printf 'engine sysroot link is missing or incorrect\n' >&2
  exit 1
}

run_sysroot > "$temporary_directory/second.log"
[[ "$(wc -l < "$make_log")" -eq 2 ]] || {
  printf 'matching stamp did not skip Buildroot\n' >&2
  cat "$make_log" >&2
  exit 1
}

run_sysroot --publish > "$temporary_directory/publish.log"
[[ "$(wc -l < "$make_log")" -eq 2 ]] || {
  printf -- '--publish on an up-to-date sysroot ran Buildroot\n' >&2
  exit 1
}
grep -q '^release upload sysroots-cache ' "$gh_log" || {
  printf -- '--publish on an up-to-date sysroot did not upload it\n' >&2
  cat "$gh_log" >&2
  exit 1
}

run_sysroot --force > "$temporary_directory/forced.log"
[[ "$(wc -l < "$make_log")" -eq 4 ]] || {
  printf -- '--force did not rebuild the sysroot\n' >&2
  cat "$make_log" >&2
  exit 1
}

printf 'test_sysroot.sh: ok\n'
