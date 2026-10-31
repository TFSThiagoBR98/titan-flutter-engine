#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
check_script="$repository_root/scripts/check-runtime-spi.sh"
temporary_directory=$(mktemp -d)

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -f ${ninja_pid_log:-} ]]; then
    while read -r pid; do
      kill -TERM "$pid" 2>/dev/null || true
    done < "$ninja_pid_log"
  fi
  rm -rf "$temporary_directory"
}

trap cleanup EXIT

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
ninja_pid_log="$temporary_directory/ninja-pids.log"
ninja_environment="$temporary_directory/ninja-environment.log"
runner_log="$temporary_directory/runner.log"
dart_runner_log="$temporary_directory/dart-runner.log"
rust_conformance_log="$temporary_directory/rust-conformance.log"
rust_conformance_cargo_log="$temporary_directory/rust-conformance-cargo.log"
inventory_log="$temporary_directory/inventory.log"
order_log="$temporary_directory/order.log"
output_log="$temporary_directory/output.log"
baseline_output_log="$temporary_directory/baseline-output.log"
locale_output_log="$temporary_directory/locale-output.log"
mkdir -p "$fake_bin" "$work_directory/depot_tools"

fake_lavapipe_icd="$temporary_directory/lvp_icd.json"
: > "$fake_lavapipe_icd"

cat > "$fake_bin/build-engine" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${TITAN_BUILD_LOCK_HELD:-}" == 1 ]] || {
  printf 'build-engine was not called under the check lock\n' >&2
  exit 91
}
printf '%s\n' "$@" >> "$BUILD_LOG"
mkdir -p "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug"
 : > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/libflutter_engine_core.so"
: > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/libflutter_engine_core.a"
mkdir -p "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/gen/flutter/shell/platform/embedder/assets"
: > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/icudtl.dat"
cat > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/flutter_engine_core_smoke" <<'SMOKE_EOF'
#!/usr/bin/env bash
printf 'smoke\n' >> "$ORDER_LOG"
printf 'core smoke: ok\n'
SMOKE_EOF
chmod +x "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/flutter_engine_core_smoke"
cat > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/flutter_engine_core_gpu_triangle" <<'TRIANGLE_EOF'
#!/usr/bin/env bash
printf 'triangle\n' >> "$ORDER_LOG"
if ((FAKE_TRIANGLE_STATUS != 0)); then
  exit "$FAKE_TRIANGLE_STATUS"
fi
printf 'core gpu triangle: ok\n'
TRIANGLE_EOF
chmod +x "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/flutter_engine_core_gpu_triangle"
: > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/runtime_spi_unittests"
cat > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/runtime_spi_unittests" <<'RUNTIME_SPI_EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" > "$RUST_CONFORMANCE_LOG"
printf 'FLUTTER_SPI_CONFORMANCE_RUNTIME=%s\n' \
  "${FLUTTER_SPI_CONFORMANCE_RUNTIME:-}" >> "$RUST_CONFORMANCE_LOG"
printf 'rust-conformance\n' >> "$ORDER_LOG"
if ((FAKE_RUST_CONFORMANCE_FAILED != 0)); then
  printf '[  FAILED  ] SpiConformance.ExternalFailure\n'
fi
printf '[  PASSED  ] 28 tests.\n'
printf '[  SKIPPED ] 9 tests, listed below:\n'
exit "${FAKE_RUST_CONFORMANCE_STATUS:-0}"
RUNTIME_SPI_EOF
chmod +x "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/runtime_spi_unittests"
: > "$TITAN_WORK_DIR/flutter/engine/src/out/host_debug/playground.shaderbundle"
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
if ((FAKE_NINJA_SLEEP_SECONDS > 0)); then
  sleep "$FAKE_NINJA_SLEEP_SECONDS" &
  sleep_pid=$!
  printf '%s\n%s\n' "$$" "$sleep_pid" > "$NINJA_PID_LOG"
  wait "$sleep_pid"
fi
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

cat > "$fake_bin/run-dart-tests" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" > "$DART_RUNNER_LOG"
printf 'dart-runner\n' >> "$ORDER_LOG"
EOF
chmod +x "$fake_bin/run-dart-tests"

cat > "$fake_bin/readelf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

dynamic_label='Shared library'
case "${LC_ALL:-${LANG:-}}" in
  pt_BR*|pt_PT*)
    dynamic_label='Biblioteca partilhada'
    ;;
esac

if [[ "${@: -1}" == *flutter_engine_core_smoke ||
      "${@: -1}" == *flutter_engine_core_gpu_triangle ]]; then
  printf ' 0x0000000000000001 (NEEDED)             %s: [libflutter_engine_core.so]\n' \
    "$dynamic_label"
fi
if [[ "${@: -1}" == *core-static-link ]]; then
  if ((FAKE_RUST_UNEXPECTED != 0)); then
    printf ' 0x0000000000000001 (NEEDED)             %s: [libflutter_engine_core.so]\n' \
      "$dynamic_label"
  fi
fi
if [[ "${@: -1}" == *flutter_engine_core_gpu_triangle &&
      "${FAKE_GPU_UNEXPECTED:-0}" == 1 ]]; then
  printf ' 0x0000000000000001 (NEEDED)             %s: [libflutter_engine.so]\n' \
    "$dynamic_label"
fi
printf ' 0x0000000000000001 (NEEDED)             %s: [libc.so]\n' "$dynamic_label"
EOF
chmod +x "$fake_bin/readelf"

cat > "$fake_bin/nm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ " $* " == *libflutter_engine_core.a* ]]; then
  printf '0000000000000000 T FlutterCoreEngineRun\n'
  if ((FAKE_STATIC_EXTRA != 0)); then
    printf '0000000000000000 T UnexpectedStaticGlobal\n'
  fi
elif [[ " $* " == *libflutter_engine_core.so* ]]; then
  printf '0000000000000000 T FlutterCoreEngineRun\n'
elif [[ "${1:-}" == '-D' ]]; then
  printf '0000000000000000 T FlutterCoreEngineRun\n'
fi
EOF
chmod +x "$fake_bin/nm"

cat > "$fake_bin/cargo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" >> "$CARGO_LOG"
if [[ " $* " == *' xtask conformance-report '* ]]; then
  printf 'conformance-report\n' >> "$ORDER_LOG"
  printf 'flutter-rs conformance: api 0.00%%, tests 0.00%%, spi 28/37\n'
  exit 0
fi
if [[ " $* " == *' -p flutter-rs-conformance '* ]]; then
  mkdir -p "$CARGO_TARGET_DIR/debug"
  : > "$CARGO_TARGET_DIR/debug/libflutter_rs_conformance.so"
  exit "${FAKE_CONFORMANCE_BUILD_STATUS:-0}"
fi

mkdir -p "$CARGO_TARGET_DIR/debug"
cat > "$CARGO_TARGET_DIR/debug/core-static-link" <<'RUST_EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'rust\n' >> "$ORDER_LOG"
exit "${FAKE_RUST_RUN_STATUS:-0}"
RUST_EOF
chmod +x "$CARGO_TARGET_DIR/debug/core-static-link"
exit "${FAKE_RUST_BUILD_STATUS:-0}"
EOF
chmod +x "$fake_bin/cargo"

cat > "$fake_bin/fvm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == dart && "${2:-}" == run ]] || exit 91
printf '%s\n' "$@" > "$INVENTORY_LOG"
printf 'inventory\n' >> "$ORDER_LOG"
EOF
chmod +x "$fake_bin/fvm"

cat > "$fake_bin/strings" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
chmod +x "$fake_bin/strings"

run_check() {
  : > "$build_log"
  TITAN_WORK_DIR="$work_directory" \
  TITAN_BUILD_ENGINE="$fake_bin/build-engine" \
  TITAN_NINJA="$fake_bin/ninja" \
  TITAN_RUN_ENGINE_TESTS="$fake_bin/run-engine-tests" \
  TITAN_RUN_DART_TESTS="$fake_bin/run-dart-tests" \
  TITAN_LLVM_NM="$fake_bin/nm" \
  BUILD_LOG="$build_log" \
  NINJA_LOG="$ninja_log" \
  NINJA_PID_LOG="$ninja_pid_log" \
  NINJA_ENVIRONMENT="$ninja_environment" \
  RUNNER_LOG="$runner_log" \
  DART_RUNNER_LOG="$dart_runner_log" \
  RUST_CONFORMANCE_LOG="$rust_conformance_log" \
  CARGO_LOG="$rust_conformance_cargo_log" \
  INVENTORY_LOG="$inventory_log" \
  ORDER_LOG="$order_log" \
  TITAN_LAVAPIPE_ICD="${FAKE_LAVAPIPE_ICD:-$fake_lavapipe_icd}" \
  FAKE_TRIANGLE_STATUS="${FAKE_TRIANGLE_STATUS:-0}" \
  FAKE_GPU_UNEXPECTED="${FAKE_GPU_UNEXPECTED:-0}" \
  FAKE_STATIC_EXTRA="${FAKE_STATIC_EXTRA:-0}" \
  FAKE_RUST_BUILD_STATUS="${FAKE_RUST_BUILD_STATUS:-0}" \
  FAKE_RUST_RUN_STATUS="${FAKE_RUST_RUN_STATUS:-0}" \
  FAKE_RUST_UNEXPECTED="${FAKE_RUST_UNEXPECTED:-0}" \
  FAKE_RUST_CONFORMANCE_STATUS="${FAKE_RUST_CONFORMANCE_STATUS:-0}" \
  FAKE_RUST_CONFORMANCE_FAILED="${FAKE_RUST_CONFORMANCE_FAILED:-0}" \
  FAKE_CONFORMANCE_BUILD_STATUS="${FAKE_CONFORMANCE_BUILD_STATUS:-0}" \
  FAKE_NO_UNIT_BUILD_STATUS="${FAKE_NO_UNIT_BUILD_STATUS:-0}" \
  FAKE_ARGS_GN="${FAKE_ARGS_GN:-enable_unittests = true}" \
  FAKE_NINJA_STATUS="${FAKE_NINJA_STATUS:-0}" \
  FAKE_NINJA_SLEEP_SECONDS="${FAKE_NINJA_SLEEP_SECONDS:-0}" \
  PATH="$fake_bin:$PATH" \
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

[[ "$(tr '\n' ' ' < "$order_log")" == 'build build ninja runner dart-runner rust-conformance inventory conformance-report smoke rust triangle ' ]] || \
  fail 'steps did not run in build, ninja, runner order'
assert_contains "$build_log" '--unittests' 'build arguments'
assert_contains "$build_log" '--gn-only' 'build arguments'
assert_contains "$build_log" '--out-name' 'build arguments'
assert_contains "$build_log" 'host_debug_no_unittests' 'build arguments'
assert_contains "$ninja_log" '-k' 'ninja arguments'
assert_contains "$ninja_log" '0' 'ninja arguments'
grep -Fxq 'flutter/fml:fml_unittests' "$ninja_log" || \
  fail 'ninja target was not passed as one argument'
grep -Fxq 'flutter/shell/platform/embedder:flutter_engine_core_library' "$ninja_log" || \
  fail 'core engine target was not passed as one argument'
grep -Fxq 'flutter/shell/platform/embedder:flutter_engine_core_static' "$ninja_log" || \
  fail 'static core engine target was not passed as one argument'
grep -Fxq 'flutter/shell/platform/embedder:flutter_engine_core_smoke_entry' "$ninja_log" || \
  fail 'core smoke entry target was not passed as one argument'
grep -Fxq 'flutter/shell/platform/embedder:flutter_engine_core_gpu_triangle' "$ninja_log" || \
  fail 'core gpu triangle target was not passed as one argument'
grep -Fxq 'flutter/shell/testing:flutter_tester' "$ninja_log" || \
  fail 'flutter_tester target was not passed as one argument'
grep -Fxq 'flutter/testing/dart:compile_gpu_test.dart' "$ninja_log" || \
  fail 'gpu_test.dart compile target was not passed as one argument'
assert_matches "$ninja_environment" 'CCACHE_DIR=.*/\.build_flutter/ccache$' 'ninja environment'
assert_contains "$ninja_environment" 'DEPOT_TOOLS_UPDATE=0' 'ninja environment'
assert_contains "$output_log" 'build: ok' 'stage summary'
assert_contains "$output_log" 'ninja: ok' 'stage summary'
assert_contains "$output_log" 'tests: ok' 'stage summary'
assert_contains "$output_log" 'core artifact: ok' 'core artifact summary'
assert_contains "$output_log" 'core static symbols: ok' 'core static symbols summary'
assert_contains "$output_log" 'core static rust: ok' 'core static rust summary'
assert_contains "$output_log" 'core gpu triangle: ok' 'core gpu triangle summary'
assert_contains "$output_log" 'spi conformance rust: 28 passed, 9 skipped' \
  'Rust SPI conformance summary'
assert_contains "$output_log" 'flutter-rs conformance: api 0.00%, tests 0.00%, spi 28/37' \
  'flutter-rs conformance summary'
assert_contains "$inventory_log" '--engine-src' 'Dart inventory arguments'
assert_contains "$inventory_log" '--framework-src' 'Dart inventory arguments'
assert_contains "$inventory_log" '--check' 'Dart inventory arguments'
assert_contains "$rust_conformance_log" '--gtest_filter=SpiConformance.*' \
  'Rust SPI conformance filter'
assert_matches "$rust_conformance_log" \
  'FLUTTER_SPI_CONFORMANCE_RUNTIME=.*/libflutter_rs_conformance\.so$' \
  'Rust SPI conformance runtime path'
assert_contains "$rust_conformance_cargo_log" '-p' 'Rust SPI conformance cargo package'
assert_contains "$rust_conformance_cargo_log" 'flutter-rs-conformance' \
  'Rust SPI conformance cargo package name'
assert_contains "$rust_conformance_cargo_log" 'conformance-report' \
  'Flutter Dart conformance cargo command'
assert_contains "$rust_conformance_cargo_log" '--spi-log' \
  'Flutter Dart conformance cargo arguments'
cp "$output_log" "$baseline_output_log"

rm -f "$runner_log" "$dart_runner_log" "$order_log"
if FAKE_STATIC_EXTRA=1 run_check >"$output_log" 2>&1; then
  fail 'unexpected static core symbol should fail the check'
else
  status=$?
fi
[[ "$status" -eq 2 ]] || fail "unexpected static symbol returned $status instead of 2"
assert_contains "$output_log" 'core static archive has symbols different' \
  'core static symbols diagnostic'

rm -f "$runner_log" "$dart_runner_log" "$order_log"
if FAKE_RUST_RUN_STATUS=17 run_check >"$output_log" 2>&1; then
  fail 'core static rust failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 2 ]] || fail "core static rust failure returned $status instead of 2"
assert_contains "$output_log" 'core static rust executable failed' \
  'core static rust failure diagnostic'

rm -f "$runner_log" "$dart_runner_log" "$order_log"
if FAKE_RUST_UNEXPECTED=1 run_check >"$output_log" 2>&1; then
  fail 'unexpected Rust engine dependency should fail the check'
else
  status=$?
fi
[[ "$status" -eq 2 ]] || fail "unexpected Rust engine dependency returned $status instead of 2"
assert_contains "$output_log" 'core static rust executable links an unexpected engine library' \
  'core static rust dependency diagnostic'

rm -f "$runner_log" "$dart_runner_log" "$order_log"
if FAKE_TRIANGLE_STATUS=17 run_check >"$output_log" 2>&1; then
  fail 'core gpu triangle failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 2 ]] || fail "core gpu triangle failure returned $status instead of 2"
assert_contains "$output_log" 'core gpu triangle executable failed' \
  'core gpu triangle failure diagnostic'

rm -f "$runner_log" "$dart_runner_log" "$order_log"
if FAKE_GPU_UNEXPECTED=1 run_check >"$output_log" 2>&1; then
  fail 'unexpected core gpu triangle library should fail the check'
else
  status=$?
fi
[[ "$status" -eq 2 ]] || fail "unexpected library returned $status instead of 2"
assert_contains "$output_log" 'core executable links an unexpected engine library' \
  'core gpu triangle dependency diagnostic'

rm -f "$runner_log" "$dart_runner_log" "$order_log"
FAKE_LAVAPIPE_ICD="$temporary_directory/missing-lvp.json" \
  run_check >"$output_log" 2>&1
assert_contains "$output_log" \
  'core gpu triangle: skipped (lavapipe not installed)' \
  'lavapipe skip diagnostic'
assert_not_contains "$output_log" 'core gpu triangle: ok' \
  'lavapipe skip output'

non_c_locale=$(locale -a | awk '
  tolower($0) == "pt_br.utf8" || tolower($0) == "pt_br.utf-8" { print; exit }
')
if [[ -z "$non_c_locale" ]]; then
  non_c_locale=$(locale -a | awk '
    $0 != "C" && $0 != "POSIX" && $0 !~ /^C\./ { print; exit }
  ')
fi
if [[ -n "$non_c_locale" ]]; then
  rm -f "$runner_log" "$dart_runner_log" "$order_log" "$ninja_log" "$ninja_pid_log"
  if LC_ALL="$non_c_locale" LANG="$non_c_locale" run_check >"$locale_output_log" 2>&1; then
    :
  else
    cat "$locale_output_log" >&2
    fail "the complete fake check should pass under locale $non_c_locale"
  fi
  if ! cmp -s "$baseline_output_log" "$locale_output_log"; then
    diff -u "$baseline_output_log" "$locale_output_log" >&2 || true
    fail "the fake check result changed under locale $non_c_locale"
  fi
else
  printf 'locale-independent check: skipped; no non-C locale available\n'
fi

rm -f "$runner_log" "$dart_runner_log" "$order_log" "$ninja_log"
if FAKE_NO_UNIT_BUILD_STATUS=29 run_check >"$output_log" 2>&1; then
  fail 'GN without unit tests failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 29 ]] || fail "GN without unit tests failure returned $status instead of 29"
assert_contains "$output_log" 'gn without unit tests: failed' \
  'GN without unit tests diagnostic'
[[ ! -e "$ninja_log" ]] || fail 'ninja ran after GN without unit tests failure'

rm -f "$runner_log" "$dart_runner_log" "$order_log" "$ninja_log"
if FAKE_ARGS_GN='enable_unittests = false' run_check >"$output_log" 2>&1; then
  fail 'disabled unit tests should fail'
else
  status=$?
fi
[[ "$status" -ne 0 ]] || fail 'disabled unit tests returned success'
assert_contains "$output_log" 'unit tests are disabled in' 'disabled unit test diagnostic'
[[ ! -e "$runner_log" ]] || fail 'runner ran with disabled unit tests'

rm -f "$runner_log" "$dart_runner_log" "$order_log"
FAKE_ARGS_GN='# default is enabled' run_check >"$output_log" 2>&1
[[ "$(tr '\n' ' ' < "$order_log")" == 'build build ninja runner dart-runner rust-conformance inventory conformance-report smoke rust triangle ' ]] || \
  fail 'steps did not continue when enable_unittests is absent'
assert_contains "$output_log" 'tests: ok' 'missing unit test setting summary'

rm -f "$runner_log" "$dart_runner_log" "$order_log"
if FAKE_NINJA_STATUS=23 run_check >"$output_log" 2>&1; then
  fail 'ninja failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 23 ]] || fail "ninja failure returned $status instead of 23"
[[ ! -e "$runner_log" ]] || fail 'runner ran after ninja failure'

rm -f "$runner_log" "$dart_runner_log" "$rust_conformance_log" "$rust_conformance_cargo_log" \
  "$order_log"
if FAKE_RUST_CONFORMANCE_FAILED=1 run_check >"$output_log" 2>&1; then
  fail 'reported Rust conformance failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 2 ]] || fail "reported Rust conformance failure returned $status instead of 2"
assert_contains "$output_log" 'spi conformance rust failed' \
  'reported Rust conformance failure diagnostic'

rm -f "$runner_log" "$dart_runner_log" "$rust_conformance_log" "$rust_conformance_cargo_log" \
  "$order_log"
if FAKE_RUST_CONFORMANCE_STATUS=17 run_check >"$output_log" 2>&1; then
  fail 'Rust conformance exit failure should fail the check'
else
  status=$?
fi
[[ "$status" -eq 2 ]] || fail "Rust conformance exit failure returned $status instead of 2"
assert_contains "$output_log" 'spi conformance rust failed' \
  'Rust conformance exit failure diagnostic'

rm -f "$runner_log" "$dart_runner_log" "$rust_conformance_log" "$rust_conformance_cargo_log" \
  "$order_log"
missing_flutter_rs="$temporary_directory/missing-flutter-rs"
if TITAN_FLUTTER_RS_DIR="$missing_flutter_rs" run_check >"$output_log" 2>&1; then
  :
else
  cat "$output_log" >&2
  fail 'missing flutter-rs should skip the Rust conformance check'
fi
assert_contains "$output_log" 'spi conformance rust: skipped (flutter-rs not found)' \
  'missing flutter-rs skip diagnostic'
[[ ! -e "$rust_conformance_log" ]] || fail 'Rust conformance ran without flutter-rs'

rm -f "$runner_log" "$dart_runner_log" "$rust_conformance_log" "$rust_conformance_cargo_log" \
  "$order_log"
run_check --skip-tests >"$output_log" 2>&1
[[ ! -e "$runner_log" ]] || fail 'runner ran with --skip-tests'
[[ ! -e "$dart_runner_log" ]] || fail 'Dart runner ran with --skip-tests'
[[ ! -e "$rust_conformance_log" ]] || fail 'Rust conformance ran with --skip-tests'
assert_contains "$output_log" 'spi conformance rust: skipped (tests skipped)' \
  'Rust SPI conformance skip-tests diagnostic'
assert_not_exact_line "$output_log" 'tests: ok' 'skip-tests summary'

lock_directory="$work_directory/flutter/engine/src/out/host_debug"
lock_path="$lock_directory/.titan-build.lock"
lock_ready="$temporary_directory/check-lock-ready"
mkdir -p "$lock_directory"
start_lock_holder "$lock_path" "$lock_ready"
: > "$build_log"
rm -f "$ninja_log" "$runner_log" "$dart_runner_log"
if timeout 10 env \
  TITAN_WORK_DIR="$work_directory" \
  TITAN_BUILD_ENGINE="$fake_bin/build-engine" \
  TITAN_NINJA="$fake_bin/ninja" \
  TITAN_RUN_ENGINE_TESTS="$fake_bin/run-engine-tests" \
  TITAN_RUN_DART_TESTS="$fake_bin/run-dart-tests" \
  BUILD_LOG="$build_log" \
  NINJA_LOG="$ninja_log" \
  NINJA_ENVIRONMENT="$ninja_environment" \
  RUNNER_LOG="$runner_log" \
  DART_RUNNER_LOG="$dart_runner_log" \
  RUST_CONFORMANCE_LOG="$rust_conformance_log" \
  CARGO_LOG="$rust_conformance_cargo_log" \
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

rm -f "$ninja_log" "$runner_log" "$dart_runner_log" "$ninja_pid_log"
if timeout --foreground --preserve-status 2 env \
  TITAN_WORK_DIR="$work_directory" \
  TITAN_BUILD_ENGINE="$fake_bin/build-engine" \
  TITAN_NINJA="$fake_bin/ninja" \
  TITAN_RUN_ENGINE_TESTS="$fake_bin/run-engine-tests" \
  TITAN_RUN_DART_TESTS="$fake_bin/run-dart-tests" \
  BUILD_LOG="$build_log" \
  NINJA_LOG="$ninja_log" \
  NINJA_PID_LOG="$ninja_pid_log" \
  NINJA_ENVIRONMENT="$ninja_environment" \
  RUNNER_LOG="$runner_log" \
  DART_RUNNER_LOG="$dart_runner_log" \
  RUST_CONFORMANCE_LOG="$rust_conformance_log" \
  CARGO_LOG="$rust_conformance_cargo_log" \
  ORDER_LOG="$order_log" \
  FAKE_NO_UNIT_BUILD_STATUS=0 \
  FAKE_ARGS_GN='enable_unittests = true' \
  FAKE_NINJA_STATUS=0 \
  FAKE_NINJA_SLEEP_SECONDS=30 \
  "$check_script" >"$output_log" 2>&1; then
  fail 'interrupted check should fail'
else
  status=$?
fi
[[ "$status" -eq 143 ]] || fail "interrupted check returned $status instead of 143"
[[ -s "$ninja_pid_log" ]] || fail 'fake ninja did not start before interruption'
while read -r pid; do
  if kill -0 "$pid" 2>/dev/null; then
    fail "fake ninja process $pid survived interruption"
  fi
done < "$ninja_pid_log"
if (exec 9>"$lock_path"; flock -n 9); then
  :
else
  fail 'build lock remained held after interruption'
fi

printf 'test_check_runtime_spi.sh: ok\n'
