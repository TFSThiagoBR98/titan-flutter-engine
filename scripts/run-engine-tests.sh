#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
target_file="$repository_root/tests/runtime-spi/gtest-targets.txt"
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

usage() {
  printf 'Usage: %s <out_dir> [--baseline <file>]\n' "$0"
}

out_dir=${1:-}
baseline_file=
[[ -n "$out_dir" ]] || { usage >&2; exit 2; }
shift
while (($# > 0)); do
  case "$1" in
    --baseline)
      (($# >= 2)) || die '--baseline requires a file'
      baseline_file=$2
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done
[[ -d "$out_dir" ]] || die "output directory does not exist: $out_dir"
[[ -f "$target_file" ]] || die "gtest target list does not exist: $target_file"
if [[ -n "$baseline_file" && ! -f "$baseline_file" ]]; then
  die "baseline file does not exist: $baseline_file"
fi

declare -A baseline_failures=()
if [[ -n "$baseline_file" ]]; then
  while IFS= read -r test_name; do
    test_name=${test_name%%#*}
    test_name=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$test_name")
    [[ -n "$test_name" ]] || continue
    baseline_failures["$test_name"]=1
  done < "$baseline_file"
fi

declare -A observed_status=()
new_failure=0

while IFS= read -r target; do
  target=${target%%#*}
  target=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$target")
  [[ -n "$target" ]] || continue
  binary=${target##*:}
  binary_path="$out_dir/$binary"
  [[ -x "$binary_path" ]] || die "gtest binary does not exist or is not executable: $binary_path"

  test_directory="$temporary_directory/$binary"
  mkdir -p "$test_directory"
  binary_status=0
  reported_failure=0
  (
    cd "$test_directory"
    "$binary_path" --gtest_output=json
  ) || binary_status=$?
  result_file="$test_directory/test_detail.json"
  if [[ ! -f "$result_file" ]]; then
    printf 'FAIL %s\n' "$target"
    new_failure=1
    continue
  fi

  while IFS=$'\t' read -r status test_name; do
    [[ -n "$test_name" ]] || continue
    observed_status["$test_name"]=$status
    printf '%s %s\n' "$status" "$test_name"
    [[ "$status" == FAIL ]] && reported_failure=1
    if [[ "$status" == FAIL && -z "${baseline_failures[$test_name]+present}" ]]; then
      new_failure=1
    fi
  done < <(
    python3 - "$result_file" <<'PY'
import json
import sys

result = json.loads(open(sys.argv[1], encoding="utf-8").read())
for suite in result.get("testsuites", []):
    suite_name = suite.get("name", "unknown")
    for test in suite.get("testsuite", []):
        test_name = test.get("name", "unknown")
        status = "FAIL" if test.get("failures") else "PASS"
        print(f"{status}\t{suite_name}.{test_name}")
PY
  )

  if ((binary_status != 0)) && [[ "$reported_failure" == 0 ]]; then
    # A non-zero gtest exit without a reported failing test is still a failure.
    new_failure=1
  fi
done < "$target_file"

for test_name in "${!baseline_failures[@]}"; do
  if [[ "${observed_status[$test_name]:-}" == PASS ]]; then
    printf 'WARNING baseline test passed: %s\n' "$test_name"
  fi
done

exit "$new_failure"
