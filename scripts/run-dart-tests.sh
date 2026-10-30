#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
target_file="$repository_root/tests/runtime-spi/dart-tests.txt"
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

usage() {
  printf 'Usage: %s <out_dir>\n' "$0"
}

out_dir=${1:-}
[[ -n "$out_dir" ]] || { usage >&2; exit 2; }
[[ $# -eq 1 ]] || { usage >&2; exit 2; }
[[ -d "$out_dir" ]] || die "output directory does not exist: $out_dir"
out_dir=$(cd "$out_dir" && pwd -P)
[[ -f "$target_file" ]] || die "Dart test list does not exist: $target_file"

tester=${TITAN_FLUTTER_TESTER:-$out_dir/flutter_tester}
[[ -x "$tester" ]] || die "flutter_tester does not exist or is not executable: $tester"

icu_data="$out_dir/icudtl.dat"
assets_directory="$out_dir/gen/flutter/lib/ui/assets"
failed_tests=0

while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%%#*}
  line=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$line")
  [[ -n "$line" ]] || continue

  IFS='|' read -r test_file label minimum_passes flags <<<"$line"
  [[ -n "$test_file" && -n "$label" && -n "$minimum_passes" ]] || \
    die "invalid Dart test entry: $line"

  dill_file="$out_dir/gen/$test_file.dill"
  [[ -f "$dill_file" ]] || die "Dart kernel file does not exist: $dill_file"

  read -r -a flag_arguments <<<"$flags"
  output_file="$temporary_directory/${label}.log"
  tester_status=0
  timeout 600 "$tester" \
    --disable-vm-service \
    "${flag_arguments[@]}" \
    --use-test-fonts \
    --icu-data-file-path="$icu_data" \
    --flutter-assets-dir="$assets_directory" \
    --disable-asset-fonts \
    "$dill_file" >"$output_file" 2>&1 || tester_status=$?

  summary=$(grep -E '^\+[0-9]+( ~[0-9]+)?( -[0-9]+)?: .+' "$output_file" | tail -n 1 || true)
  result_prefix="dart:$test_file[$label]"
  if ((tester_status != 0)); then
    printf 'FAIL %s exit %s\n' "$result_prefix" "$tester_status"
    failed_tests=$((failed_tests + 1))
    continue
  fi
  if [[ -z "$summary" ]]; then
    printf 'FAIL %s no summary\n' "$result_prefix"
    failed_tests=$((failed_tests + 1))
    continue
  fi

  [[ "$summary" =~ ^\+([0-9]+)( ~([0-9]+))?( -([0-9]+))?:\ .+ ]] || {
    printf 'FAIL %s invalid summary\n' "$result_prefix"
    failed_tests=$((failed_tests + 1))
    continue
  }
  pass_count=${BASH_REMATCH[1]}
  failed_count=${BASH_REMATCH[5]:-0}
  if ((failed_count > 0)); then
    printf 'FAIL %s %s failed\n' "$result_prefix" "$failed_count"
    failed_tests=$((failed_tests + 1))
    continue
  fi
  if ((pass_count < minimum_passes)); then
    printf 'FAIL %s %s expected passes, got %s\n' \
      "$result_prefix" "$minimum_passes" "$pass_count"
    failed_tests=$((failed_tests + 1))
    continue
  fi

  skipped_count=${BASH_REMATCH[3]:-0}
  if ((skipped_count > 0)); then
    printf 'PASS %s +%s ~%s\n' "$result_prefix" "$pass_count" "$skipped_count"
  else
    printf 'PASS %s +%s\n' "$result_prefix" "$pass_count"
  fi
done < "$target_file"

((failed_tests == 0)) || exit 1
