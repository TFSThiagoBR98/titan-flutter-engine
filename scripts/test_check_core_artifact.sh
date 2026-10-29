#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
source "$repository_root/scripts/lib/paths.sh"

check_script="$repository_root/scripts/check-core-artifact.sh"
output_directory="$TITAN_WORK_DIR/flutter/engine/src/out/host_debug"
core_library="$output_directory/libflutter_engine_core.so"
engine_library="$output_directory/libflutter_engine.so"
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file=$1 expected=$2 description=$3
  grep -Fq -- "$expected" "$file" || fail "$description: missing $expected"
}

[[ -f "$core_library" ]] || fail "missing core library: $core_library"
[[ -f "$engine_library" ]] || fail "missing engine library: $engine_library"

core_output="$temporary_directory/core.log"
bash "$check_script" "$core_library" >"$core_output" 2>&1
assert_contains "$core_output" 'core artifact: ok' 'core artifact result'

engine_output="$temporary_directory/engine.log"
if bash "$check_script" "$engine_library" >"$engine_output" 2>&1; then
  fail 'the Dart engine library was accepted as a core artifact'
fi
assert_contains "$engine_output" '(c)' 'Dart symbol diagnostic'
assert_contains "$engine_output" '(d)' 'Dart snapshot diagnostic'

printf 'test_check_core_artifact.sh: ok\n'
