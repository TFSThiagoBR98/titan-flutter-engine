#!/usr/bin/env bash
set -euo pipefail

# binutils output and sort order must not depend on the user locale
export LC_ALL=C

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
run_dart_tests=${TITAN_RUN_DART_TESTS:-$repository_root/scripts/run-dart-tests.sh}
check_core_artifact="$repository_root/scripts/check-core-artifact.sh"
engine_source="$TITAN_WORK_DIR/flutter/engine/src"
output_directory="$engine_source/out/host_debug"
no_unittests_output_directory="$engine_source/out/host_debug_no_unittests"
args_file="$output_directory/args.gn"
core_smoke="$output_directory/flutter_engine_core_smoke"
icu_data="$output_directory/icudtl.dat"
assets_directory="$output_directory/gen/flutter/shell/platform/embedder/assets"

mkdir -p "$output_directory" "$no_unittests_output_directory"
exec {build_lock_fd}>"$output_directory/.titan-build.lock"
if ! flock -n "$build_lock_fd"; then
  die "another build is running in $output_directory"
fi
exec {no_unittests_build_lock_fd}>"$no_unittests_output_directory/.titan-build.lock"
if ! flock -n "$no_unittests_build_lock_fd"; then
  die "another build is running in $no_unittests_output_directory"
fi
export TITAN_BUILD_LOCK_HELD=1

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
        printf '%s\n' 'flutter/shell/testing:flutter_tester'
        awk -F'|' '
          {
            sub(/#.*/, "", $1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
            if ($1 != "" && !seen[$1]++) {
              print "flutter/testing/dart:compile_" $1
            }
          }
        ' "$repository_root/tests/runtime-spi/dart-tests.txt"
        printf '%s\n' 'flutter/shell/platform/embedder:flutter_engine'
        printf '%s\n' 'flutter/shell/platform/embedder:flutter_engine_core_library'
      } | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d'
    )
  fi

  setsid nice "$ninja" -C "$output_directory" -k 0 -j "$TITAN_JOBS" \
    "${targets[@]}" &
  ninja_pid=$!
  if wait "$ninja_pid"; then
    status=0
  else
    status=$?
  fi
  ninja_pid=''

  if ((status == 0)); then
    printf 'ninja: ok\n'
    return 0
  fi

  printf 'ninja: failed (%s)\n' "$status" >&2
  return "$status"
}

run_tests() {
  if ((skip_tests)); then
    printf 'tests: skipped\n'
    return 0
  fi

  local engine_tests_status=0
  if timeout 1500 "$run_engine_tests" "$output_directory" \
    --baseline "$repository_root/tests/runtime-spi/baseline-failures.txt"; then
    :
  else
    engine_tests_status=$?
  fi
  if ((engine_tests_status != 0)); then
    printf 'tests: failed (%s)\n' "$engine_tests_status" >&2
    return "$engine_tests_status"
  fi

  local dart_tests_status=0
  if "$run_dart_tests" "$output_directory"; then
    :
  else
    dart_tests_status=$?
  fi
  if ((dart_tests_status != 0)); then
    printf 'tests: failed (%s)\n' "$dart_tests_status" >&2
    return "$dart_tests_status"
  fi

  printf 'tests: ok\n'
}

run_core_smoke() {
  [[ -x "$core_smoke" ]] || die "core smoke executable is missing: $core_smoke"
  [[ -f "$icu_data" ]] || die "ICU data is missing: $icu_data"
  [[ -d "$assets_directory" ]] || die "core smoke assets are missing: $assets_directory"

  "$core_smoke" "$icu_data" "$assets_directory"

  local dynamic_output
  dynamic_output=$(mktemp)
  if ! readelf -d "$core_smoke" >"$dynamic_output"; then
    rm -f "$dynamic_output"
    die "readelf failed for $core_smoke"
  fi

  local found_core=0
  local dependency
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    if [[ "$dependency" == libflutter_engine_core.so ]]; then
      found_core=1
    else
      rm -f "$dynamic_output"
      die "core smoke links an unexpected engine library: $dependency"
    fi
  done < <(sed -n 's/.*Shared library: \[\(libflutter_engine[^]]*\)\].*/\1/p' "$dynamic_output")
  rm -f "$dynamic_output"

  ((found_core == 1)) || die "core smoke does not link libflutter_engine_core.so"
}

ninja_pid=''

stop_ninja() {
  local child_pid=${ninja_pid:-}
  if [[ -z "$child_pid" ]]; then
    return 0
  fi

  ninja_pid=''
  kill -TERM -- "-$child_pid" 2>/dev/null || \
    kill -TERM "$child_pid" 2>/dev/null || true
  wait "$child_pid" 2>/dev/null || true
}

handle_signal() {
  local signal=$1
  local status=143
  case "$signal" in
    HUP)
      status=129
      ;;
    INT)
      status=130
      ;;
  esac

  stop_ninja
  exit "$status"
}

trap 'handle_signal TERM' TERM
trap 'handle_signal INT' INT
trap 'handle_signal HUP' HUP
trap stop_ninja EXIT

run_build

if [[ -f "$args_file" ]] && grep -Eq \
  '^[[:space:]]*enable_unittests[[:space:]]*=[[:space:]]*false[[:space:]]*$' "$args_file"; then
  printf 'error: unit tests are disabled in %s\n' "$args_file" >&2
  exit 1
fi

run_build_without_unittests
run_ninja
run_tests
run_core_smoke
"$check_core_artifact" "$output_directory/libflutter_engine_core.so"
