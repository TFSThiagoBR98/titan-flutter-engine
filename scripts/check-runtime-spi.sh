#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
source "$repository_root/scripts/lib/paths.sh"

usage() {
  cat <<'EOF'
Usage: scripts/check-runtime-spi.sh [--skip-tests] [--target <ninja-target>]...
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

skip_tests=0
requested_targets=()
while (($# > 0)); do
  case "$1" in
    --skip-tests)
      skip_tests=1
      shift
      ;;
    --target)
      (($# >= 2)) || die '--target requires a value'
      requested_targets+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

build_engine=${TITAN_BUILD_ENGINE:-$repository_root/scripts/build-engine.sh}
ninja=${TITAN_NINJA:-$TITAN_WORK_DIR/depot_tools/ninja}
run_engine_tests=${TITAN_RUN_ENGINE_TESTS:-$repository_root/scripts/run-engine-tests.sh}
engine_source="$TITAN_WORK_DIR/flutter/engine/src"
output_directory="$engine_source/out/host_debug"
args_file="$output_directory/args.gn"

export CCACHE_DIR="$TITAN_WORK_DIR/ccache"
export VPYTHON_VIRTUALENV_ROOT="$TITAN_WORK_DIR/vpython-root"
export DEPOT_TOOLS_UPDATE=0
export PATH="$TITAN_WORK_DIR/depot_tools:$PATH"

run_build() {
  if "$build_engine" --mode debug --unittests --gn-only; then
    printf 'build: ok\n'
    return 0
  else
    status=$?
  fi

  printf 'build: failed (%s)\n' "$status" >&2
  return "$status"
}

run_build_without_unittests() {
  if "$build_engine" --mode debug --gn-only --out-name host_debug_no_unittests; then
    printf 'gn without unit tests: ok\n'
    return 0
  else
    status=$?
  fi

  printf 'gn without unit tests: failed (%s)\n' "$status" >&2
  return "$status"
}

run_ninja() {
  local -a targets
  if ((${#requested_targets[@]} > 0)); then
    targets=("${requested_targets[@]}")
  else
    mapfile -t targets < <(
      {
        cat "$repository_root/tests/runtime-spi/gtest-targets.txt"
        cat "$repository_root/tests/runtime-spi/benchmark-targets.txt"
        printf '%s\n' 'flutter/shell/platform/embedder:flutter_engine'
      } | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d'
    )
  fi

  if nice "$ninja" -C "$output_directory" -k 0 -j "$TITAN_JOBS" "${targets[@]}"; then
    printf 'ninja: ok\n'
    return 0
  else
    status=$?
  fi

  printf 'ninja: failed (%s)\n' "$status" >&2
  return "$status"
}

run_tests() {
  if ((skip_tests)); then
    printf 'tests: skipped\n'
    return 0
  fi

  if timeout 1500 "$run_engine_tests" "$output_directory" \
    --baseline "$repository_root/tests/runtime-spi/baseline-failures.txt"; then
    printf 'tests: ok\n'
    return 0
  else
    status=$?
  fi

  printf 'tests: failed (%s)\n' "$status" >&2
  return "$status"
}

run_build

if [[ -f "$args_file" ]] && grep -Eq \
  '^[[:space:]]*enable_unittests[[:space:]]*=[[:space:]]*false[[:space:]]*$' "$args_file"; then
  printf 'error: unit tests are disabled in %s\n' "$args_file" >&2
  exit 1
fi

run_build_without_unittests
run_ninja
run_tests
