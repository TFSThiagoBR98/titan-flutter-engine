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

assert_file_contains_only_comments() {
  local file=$1 description=$2
  if grep -Ev '^[[:space:]]*(#|$)' "$file"; then
    printf 'error: %s contains a non-comment line\n' "$description" >&2
    exit 1
  fi
}

gtest_targets="$repository_root/tests/runtime-spi/gtest-targets.txt"
benchmark_targets="$repository_root/tests/runtime-spi/benchmark-targets.txt"
baseline_failures="$repository_root/tests/runtime-spi/baseline-failures.txt"
[[ "$(grep -Ev '^[[:space:]]*(#|$)' "$gtest_targets" | wc -l)" -eq 6 ]] || {
  printf 'error: gtest-targets.txt must contain exactly six targets\n' >&2
  exit 1
}
grep -Fq 'flutter/shell/common:shell_benchmarks' "$benchmark_targets" || {
  printf 'error: shell benchmark is missing from benchmark-targets.txt\n' >&2
  exit 1
}
grep -Fq 'flutter/lib/ui:ui_benchmarks' "$benchmark_targets" || {
  printf 'error: ui benchmark is missing from benchmark-targets.txt\n' >&2
  exit 1
}
if grep -Eq 'benchmarks' "$gtest_targets"; then
  printf 'error: benchmark target leaked into gtest-targets.txt\n' >&2
  exit 1
fi
assert_file_contains_only_comments "$baseline_failures" 'baseline-failures.txt'

test_repository="$temporary_directory/test-repository"
caller_directory="$temporary_directory/caller"
relative_out_directory="out/host_debug"
out_directory="$caller_directory/$relative_out_directory"
working_directory_file="$temporary_directory/working-directory"
json_argument_file="$temporary_directory/json-argument"
json_created_marker="$temporary_directory/json-created"
mkdir -p "$test_repository/scripts" "$test_repository/tests/runtime-spi" "$out_directory"
cp "$repository_root/scripts/run-engine-tests.sh" "$test_repository/scripts/run-engine-tests.sh"
chmod +x "$test_repository/scripts/run-engine-tests.sh"
cat > "$test_repository/tests/runtime-spi/gtest-targets.txt" <<'EOF'
fake-suite:fake_gtest
EOF
cat > "$test_repository/tests/runtime-spi/benchmark-targets.txt" <<'EOF'
fake-suite:should_not_run
EOF
cat > "$out_directory/fake_gtest" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

json_output=
for argument in "$@"; do
  case "$argument" in
    --gtest_output=json:*) json_output=${argument#--gtest_output=json:} ;;
  esac
done
[[ -n "$json_output" ]] || {
  printf 'missing absolute gtest output path\n' >&2
  exit 1
}
[[ "$json_output" == /* ]] || {
  printf 'gtest output path is not absolute: %s\n' "$json_output" >&2
  exit 1
}
printf '%s\n' "$PWD" > "$WORKING_DIRECTORY_FILE"
printf '%s\n' "$json_output" > "$JSON_ARGUMENT_FILE"
cat > "$json_output" <<'JSON'
{"testsuites":[{"name":"FakeSuite","testsuite":[{"name":"Passes","failures":[]}]}]}
JSON
: > "$JSON_CREATED_MARKER"
EOF
chmod +x "$out_directory/fake_gtest"

run_output="$temporary_directory/run-output"
if ! (
  cd "$caller_directory"
  WORKING_DIRECTORY_FILE="$working_directory_file" \
  JSON_ARGUMENT_FILE="$json_argument_file" \
  JSON_CREATED_MARKER="$json_created_marker" \
    "$test_repository/scripts/run-engine-tests.sh" "$relative_out_directory"
) >"$run_output" 2>&1; then
  cat "$run_output" >&2
  exit 1
fi

expected_working_directory=$(cd "$out_directory/../.." && pwd -P)
[[ "$(<"$working_directory_file")" == "$expected_working_directory" ]] || {
  printf 'error: gtest ran from the wrong directory: expected %s, got %s\n' \
    "$expected_working_directory" "$(<"$working_directory_file")" >&2
  exit 1
}
[[ "$(<"$json_argument_file")" == /* ]] || {
  printf 'error: gtest JSON path was not absolute\n' >&2
  exit 1
}
[[ -f "$json_created_marker" ]] || {
  printf 'error: fake gtest did not receive a JSON output path\n' >&2
  exit 1
}
assert_contains "$run_output" 'PASS FakeSuite.Passes' 'gtest result'

cat > "$test_repository/tests/runtime-spi/gtest-targets.txt" <<'EOF'
fake-suite:pass_binary
fake-suite:fail_binary
EOF
cat > "$out_directory/pass_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

json_output=
for argument in "$@"; do
  case "$argument" in
    --gtest_output=json:*) json_output=${argument#--gtest_output=json:} ;;
  esac
done
[[ -n "$json_output" ]] || {
  printf 'missing absolute gtest output path\n' >&2
  exit 1
}
cat > "$json_output" <<'JSON'
{"testsuites":[{"name":"GoodSuite","testsuite":[{"name":"Passes","result":"COMPLETED","status":"RUN","failures":[]}]}]}
JSON
EOF
cat > "$out_directory/fail_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

json_output=
for argument in "$@"; do
  case "$argument" in
    --gtest_output=json:*) json_output=${argument#--gtest_output=json:} ;;
  esac
done
[[ -n "$json_output" ]] || {
  printf 'missing absolute gtest output path\n' >&2
  exit 1
}
cat > "$json_output" <<'JSON'
{"testsuites":[{"name":"FailSuite","testsuite":[{"name":"Fails","result":"COMPLETED","status":"RUN","failures":[{"failure":"expected failure"}]}]}]}
JSON
exit 1
EOF
chmod +x "$out_directory/pass_binary" "$out_directory/fail_binary"

runtime_test_failure="$temporary_directory/runtime-test-failure.log"
if (
  cd "$test_repository"
  timeout 600 scripts/run-engine-tests.sh "$out_directory"
) >"$runtime_test_failure" 2>&1; then
  printf 'run-engine-tests accepted a failing test without a baseline\n' >&2
  exit 1
fi
assert_contains "$runtime_test_failure" 'PASS GoodSuite.Passes' 'passing gtest result'
assert_contains "$runtime_test_failure" 'FAIL FailSuite.Fails' 'failing gtest result'
printf '%s\n' 'FailSuite.Fails' > "$temporary_directory/runtime-baseline.txt"
runtime_test_baseline="$temporary_directory/runtime-test-baseline.log"
(
  cd "$test_repository"
  timeout 600 scripts/run-engine-tests.sh "$out_directory" \
    --baseline "$temporary_directory/runtime-baseline.txt"
) >"$runtime_test_baseline" 2>&1
assert_contains "$runtime_test_baseline" 'FAIL FailSuite.Fails' 'baseline gtest result'

printf 'test_run_engine_tests.sh: ok\n'
