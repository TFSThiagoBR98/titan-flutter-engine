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
locale_core_output="$temporary_directory/locale-core.log"
locale_engine_output="$temporary_directory/locale-engine.log"
non_c_locale=$(locale -a | awk '
  tolower($0) == "pt_br.utf8" || tolower($0) == "pt_br.utf-8" { print; exit }
')
if [[ -z "$non_c_locale" ]]; then
  non_c_locale=$(locale -a | awk '
    $0 != "C" && $0 != "POSIX" && $0 !~ /^C\./ { print; exit }
  ')
fi

bash "$check_script" "$core_library" >"$core_output" 2>&1
assert_contains "$core_output" 'core artifact: ok' 'core artifact result'
if [[ -n "$non_c_locale" ]]; then
  if LC_ALL="$non_c_locale" LANG="$non_c_locale" \
    bash "$check_script" "$core_library" >"$locale_core_output" 2>&1; then
    :
  else
    cat "$locale_core_output" >&2
    fail "the core artifact check should pass under locale $non_c_locale"
  fi
  if ! cmp -s "$core_output" "$locale_core_output"; then
    diff -u "$core_output" "$locale_core_output" >&2 || true
    fail "the core artifact result changed under locale $non_c_locale"
  fi
fi

engine_output="$temporary_directory/engine.log"
if bash "$check_script" "$engine_library" >"$engine_output" 2>&1; then
  fail 'the Dart engine library was accepted as a core artifact'
fi
assert_contains "$engine_output" '(c)' 'Dart symbol diagnostic'
assert_contains "$engine_output" '(d)' 'Dart snapshot diagnostic'
if [[ -n "$non_c_locale" ]]; then
  if LC_ALL="$non_c_locale" LANG="$non_c_locale" \
    bash "$check_script" "$engine_library" >"$locale_engine_output" 2>&1; then
    fail "the Dart engine library was accepted under locale $non_c_locale"
  fi
  if ! cmp -s "$engine_output" "$locale_engine_output"; then
    diff -u "$engine_output" "$locale_engine_output" >&2 || true
    fail "the Dart engine result changed under locale $non_c_locale"
  fi
else
  printf 'locale-independent check: skipped; no non-C locale available\n'
fi

printf 'test_check_core_artifact.sh: ok\n'
