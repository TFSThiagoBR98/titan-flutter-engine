#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
check_script="$repository_root/scripts/check-runtime-spi.sh"
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

assert_not_contains() {
  local file=$1 unexpected=$2 description=$3
  if grep -Fq -- "$unexpected" "$file"; then
    fail "$description: found unexpected $unexpected"
  fi
}

assert_not_exact_line() {
  local file=$1 unexpected=$2 description=$3
  if grep -Fxq -- "$unexpected" "$file"; then
    fail "$description: found unexpected line $unexpected"
  fi
}

assert_matches() {
  local file=$1 pattern=$2 description=$3
  grep -Eq -- "$pattern" "$file" || fail "$description: pattern $pattern did not match"
}

work_directory="$temporary_directory/.build_flutter"
fake_bin="$temporary_directory/bin"
build_log="$temporary_directory/build.log"
ninja_log="$temporary_directory/ninja.log"
ninja_environment="$temporary_directory/ninja-environment.log"
runner_log="$temporary_directory/runner.log"
order_log="$temporary_directory/order.log"
output_log="$temporary_directory/output.log"
mkdir -p "$fake_bin" "$work_directory/depot_tools"

cat > "$fake_bin/build-engine" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${TITAN_BUILD_LOCK_HELD:-}" == 1 ]] || {
  printf 'build-engine was not called under the check lock\n' >&2
  exit 91
}
printf '%s\n' "$@" >> "$BUILD_LOG"
mkdir -p "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug"
printf '%s\n' "$FAKE_ARGS_GN" > \
  "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/args.gn"
printf 'build\n' >> "$ORDER_LOG"
if [[ " $* " == *' --out-name host_debug_no_unittests '* ]] &&
  ((FAKE_NO_UNIT_BUILD_STATUS != 0)); then
  exit "$FAKE_NO_UNIT_BUILD_STATUS"
fi
EOF
chmod +x "$fake_bin/build-engine"

cat > "$fake_bin/ninja" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" > "$NINJA_LOG"
{
  printf 'CCACHE_DIR=%s\n' "$CCACHE_DIR"
  printf 'VPYTHON_VIRTUALENV_ROOT=%s\n' "$VPYTHON_VIRTUALENV_ROOT"
  printf 'DEPOT_TOOLS_UPDATE=%s\n' "$DEPOT_TOOLS_UPDATE"
  printf 'PATH=%s\n' "$PATH"
} > "$NINJA_ENVIRONMENT"
printf 'ninja\n' >> "$ORDER_LOG"
exit "${FAKE_NINJA_STATUS:-0}"
EOF
chmod +x "$fake_bin/ninja"

cat > "$fake_bin/run-engine-tests" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" > "$RUNNER_LOG"
printf 'runner\n' >> "$ORDER_LOG"
EOF
chmod +x "$fake_bin/run-engine-tests"

run_check() {
  : > "$build_log"
  TITAN_WORK_DIR="$work_directory" \
  TITAN_BUILD_ENGINE="$fake_bin/build-engine" \
  TITAN_NINJA="$fake_bin/ninja" \
  TITAN_RUN_ENGINE_TESTS="$fake_bin/run-engine-tests" \
  BUILD_LOG="$build_log" \
  NINJA_LOG="$ninja_log" \
  NINJA_ENVIRONMENT="$ninja_environment" \
  RUNNER_LOG="$runner_log" \
  ORDER_LOG="$order_log" \
  FAKE_NO_UNIT_BUILD_STATUS="${FAKE_NO_UNIT_BUILD_STATUS:-0}" \
  FAKE_ARGS_GN="${FAKE_ARGS_GN:-enable_unittests = true}" \
  FAKE_NINJA_STATUS="${FAKE_NINJA_STATUS:-0}" \
    "$check_script" "$@"
}

start_lock_holder() {
  local lock_path=$1 ready_path=$2
  (
    exec 9>"$lock_path"
    flock -n 9
    : > "$ready_path"
    sleep 30
  ) &
  lock_holder_pid=$!
  for _ in {1..100}; do
    [[ -f "$ready_path" ]] && return 0
    sleep 0.01
  done
  fail 'the test lock holder did not become ready'
}

stop_lock_holder() {
  kill "$lock_holder_pid" 2>/dev/null || true
  wait "$lock_holder_pid" 2>/dev/null || true
}

if run_check >"$output_log" 2>&1; then
  :
else
  cat "$output_log" >&2
  fail 'the complete fake check should pass'
fi

[[ "$(tr '\n' ' ' < "$order_log")" == 'build build ninja runner ' ]] || \
  fail 'steps did not run in build, ninja, runner order'
assert_contains "$build_log" '--unittests' 'build arguments'
assert_contains "$build_log" '--gn-only' 'build arguments'
assert_contains "$build_log" '--out-name' 'build arguments'
assert_contains "$build_log" 'host_debug_no_unittests' 'build arguments'
assert_contains "$ninja_log" '-k' 'ninja arguments'
assert_contains "$ninja_log" '0' 'ninja arguments'
grep -Fxq 'flutter/fml:fml_unittests' "$ninja_log" || \
  fail 'ninja target was not passed as one argument'
assert_matches "$ninja_environment" 'CCACHE_DIR=.*/\.build_flutter/ccache$' 'ninja environment'
assert_contains "$ninja_environment" 'DEPOT_TOOLS_UPDATE=0' 'ninja environment'
assert_contains "$output_log" 'build: ok' 'stage summary'
assert_contains "$output_log" 'ninja: ok' 'stage summary'
assert_contains "$output_log" 'tests: ok' 'stage summary'

rm -f "$runner_log" "$order_log" "$ninja_log"
if FAKE_NO_UNIT_BUILD_STATUS=29 run_check >"$output_log" 2>&1; then
  fail 'GN without unit tests failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 29 ]] || fail "GN without unit tests failure returned $status instead of 29"
assert_contains "$output_log" 'gn without unit tests: failed' \
  'GN without unit tests diagnostic'
[[ ! -e "$ninja_log" ]] || fail 'ninja ran after GN without unit tests failure'

rm -f "$runner_log" "$order_log" "$ninja_log"
if FAKE_ARGS_GN='enable_unittests = false' run_check >"$output_log" 2>&1; then
  fail 'disabled unit tests should fail'
else
  status=$?
fi
[[ "$status" -ne 0 ]] || fail 'disabled unit tests returned success'
assert_contains "$output_log" 'unit tests are disabled in' 'disabled unit test diagnostic'
[[ ! -e "$runner_log" ]] || fail 'runner ran with disabled unit tests'

rm -f "$runner_log" "$order_log"
FAKE_ARGS_GN='# default is enabled' run_check >"$output_log" 2>&1
[[ "$(tr '\n' ' ' < "$order_log")" == 'build build ninja runner ' ]] || \
  fail 'steps did not continue when enable_unittests is absent'
assert_contains "$output_log" 'tests: ok' 'missing unit test setting summary'

rm -f "$runner_log" "$order_log"
if FAKE_NINJA_STATUS=23 run_check >"$output_log" 2>&1; then
  fail 'ninja failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 23 ]] || fail "ninja failure returned $status instead of 23"
[[ ! -e "$runner_log" ]] || fail 'runner ran after ninja failure'

rm -f "$runner_log" "$order_log"
run_check --skip-tests >"$output_log" 2>&1
[[ ! -e "$runner_log" ]] || fail 'runner ran with --skip-tests'
assert_not_exact_line "$output_log" 'tests: ok' 'skip-tests summary'

lock_directory="$work_directory/flutter/engine/src/out/host_debug"
lock_path="$lock_directory/.titan-build.lock"
lock_ready="$temporary_directory/check-lock-ready"
mkdir -p "$lock_directory"
start_lock_holder "$lock_path" "$lock_ready"
: > "$build_log"
rm -f "$ninja_log" "$runner_log"
if timeout 10 env \
  TITAN_WORK_DIR="$work_directory" \
  TITAN_BUILD_ENGINE="$fake_bin/build-engine" \
  TITAN_NINJA="$fake_bin/ninja" \
  TITAN_RUN_ENGINE_TESTS="$fake_bin/run-engine-tests" \
  BUILD_LOG="$build_log" \
  NINJA_LOG="$ninja_log" \
  NINJA_ENVIRONMENT="$ninja_environment" \
  RUNNER_LOG="$runner_log" \
  ORDER_LOG="$order_log" \
  FAKE_NO_UNIT_BUILD_STATUS=0 \
  FAKE_ARGS_GN='enable_unittests = true' \
  FAKE_NINJA_STATUS=0 \
  "$check_script" >"$output_log" 2>&1; then
  stop_lock_holder
  fail 'check should refuse a concurrent build'
else
  status=$?
fi
stop_lock_holder
[[ "$status" -ne 0 ]] || fail 'concurrent check returned success'
assert_contains "$output_log" "another build is running in $lock_directory" \
  'concurrent check diagnostic'
[[ ! -s "$build_log" ]] || fail 'build-engine ran while the check lock was held'
[[ ! -e "$ninja_log" ]] || fail 'ninja ran while the check lock was held'
[[ ! -e "$runner_log" ]] || fail 'runner ran while the check lock was held'

printf 'test_check_runtime_spi.sh: ok\n'
