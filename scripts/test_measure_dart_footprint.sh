#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

assert_contains() {
  local file=$1 expected=$2 description=$3
  grep -Fq -- "$expected" "$file" || {
    printf 'error: %s: expected %q in %s\n' "$description" "$expected" "$file" >&2
    sed -n '1,160p' "$file" >&2
    exit 1
  }
}

cat > "$temporary_directory/fixture.c" <<'EOF'
__attribute__((visibility("default"), used)) unsigned char Dart_Fake[64];
extern unsigned char Dart_Alias[64] __attribute__((alias("Dart_Fake")));
__attribute__((visibility("default"), used)) unsigned char kDartSnapshotData[128];
__attribute__((visibility("default"), used)) unsigned char kPlatformStrongDill[256];
unsigned char dart_foo[16] __asm__("_ZN4dart3FooE");
EOF
cc -shared -fPIC -o "$temporary_directory/libfixture.so" "$temporary_directory/fixture.c"
cp "$temporary_directory/libfixture.so" "$temporary_directory/libfixture-stripped.so"
strip --strip-all "$temporary_directory/libfixture-stripped.so"

stripped_error="$temporary_directory/stripped-error"
if bash "$repository_root/scripts/measure-dart-footprint.sh" \
  "$temporary_directory/libfixture-stripped.so" >"$stripped_error" 2>&1; then
  printf 'error: stripped library was accepted without a symbol table\n' >&2
  exit 1
fi
assert_contains "$stripped_error" \
  "error: no symbol table in $temporary_directory/libfixture-stripped.so; use lib.unstripped/libfixture-stripped.so" \
  'missing symbol table diagnostic'

output="$temporary_directory/footprint.md"
bash "$repository_root/scripts/measure-dart-footprint.sh" \
  "$temporary_directory/libfixture.so" > "$output"

assert_contains "$output" '| File size |' 'file size row'
assert_contains "$output" '| .text |' 'text row'
assert_contains "$output" '| .rodata |' 'rodata row'
assert_contains "$output" '| .data |' 'data row'
assert_contains "$output" '| dart::/Dart_ (VM) | 80 |' 'VM group row'
assert_contains "$output" '| Dart snapshots and kernel | 384 |' 'snapshot row'

printf 'test_measure_dart_footprint.sh: ok\n'
