#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

run_script="$repository_root/scripts/run-dart-tests.sh"
test_repository="$temporary_directory/test-repository"
out_directory="$test_repository/out/host_debug"
fake_tester="$temporary_directory/flutter_tester"
output_file="$temporary_directory/output.log"
dill_file="$out_directory/gen/gpu_test.dart.dill"

mkdir -p "$test_repository/scripts" "$out_directory/gen/flutter/lib/ui/assets"
cp "$run_script" "$test_repository/scripts/run-dart-tests.sh"
chmod +x "$test_repository/scripts/run-dart-tests.sh"
touch "$out_directory/icudtl.dat" "$dill_file"
cat > "$test_repository/tests-runtime-spi-dart-tests.txt" <<'EOF'
gpu_test.dart|flutter-gpu|104|--enable-impeller --impeller-backend=vulkan --enable-flutter-gpu
EOF
mkdir -p "$test_repository/tests/runtime-spi"
cp "$test_repository/tests-runtime-spi-dart-tests.txt" \
  "$test_repository/tests/runtime-spi/dart-tests.txt"

cat > "$fake_tester" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${DART_TEST_SCENARIO:?}" in
  passes_summary)
    printf '\n\n+104 ~1: \n\n+104 ~1: All other tests passed!\n\n'
    ;;
  crash_without_summary)
    ;;
  all_skipped)
    printf '+5 ~100: All other tests passed!\n'
    ;;
  failures_with_exit_zero)
    printf '+100 ~1 -3: Some tests failed.\n'
    ;;
  *)
    printf 'unknown test scenario\n' >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_tester"

run_case() {
  local scenario=$1 expected_status=$2 expected_line=$3
  local actual_status=0
  if DART_TEST_SCENARIO="$scenario" \
    TITAN_FLUTTER_TESTER="$fake_tester" \
      "$test_repository/scripts/run-dart-tests.sh" "$out_directory" >"$output_file" 2>&1; then
    actual_status=0
  else
    actual_status=$?
  fi
  [[ "$actual_status" -eq "$expected_status" ]] || {
    cat "$output_file" >&2
    printf 'error: %s returned %s instead of %s\n' \
      "$scenario" "$actual_status" "$expected_status" >&2
    exit 1
  }
  grep -Fxq -- "$expected_line" "$output_file" || {
    cat "$output_file" >&2
    printf 'error: %s did not print the expected result\n' "$scenario" >&2
    exit 1
  }
}

run_case passes_summary 0 'PASS dart:gpu_test.dart[flutter-gpu] +104 ~1'
run_case crash_without_summary 1 'FAIL dart:gpu_test.dart[flutter-gpu] no summary'
run_case all_skipped 1 'FAIL dart:gpu_test.dart[flutter-gpu] 104 expected passes, got 5'
run_case failures_with_exit_zero 1 'FAIL dart:gpu_test.dart[flutter-gpu] 3 failed'

rm -f "$dill_file"
if DART_TEST_SCENARIO=passes_summary \
  TITAN_FLUTTER_TESTER="$fake_tester" \
    "$test_repository/scripts/run-dart-tests.sh" "$out_directory" >"$output_file" 2>&1; then
  printf 'error: missing_dill was accepted\n' >&2
  exit 1
else
  actual_status=$?
fi
[[ "$actual_status" -eq 2 ]] || {
  cat "$output_file" >&2
  printf 'error: missing_dill returned %s instead of 2\n' "$actual_status" >&2
  exit 1
}
grep -Fq -- "error: Dart kernel file does not exist: $dill_file" "$output_file" || {
  cat "$output_file" >&2
  printf 'error: missing_dill did not report the .dill path\n' >&2
  exit 1
}

printf 'test_run_dart_tests.sh: ok\n'
