#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"

# The -j option does not cap the total CPU use: GCC opens sub-makes, each with
# its own -j. Use a systemd CPU quota when the user's systemd is available.
run_within_cpu_budget() {
  (($# > 0)) || {
    printf 'error: run_within_cpu_budget requires a command\n' >&2
    return 2
  }

  if [[ "${TITAN_CPU_SCOPE:-1}" != 0 ]] &&
    command -v systemd-run >/dev/null 2>&1 &&
    systemd-run --user --scope --quiet true >/dev/null 2>&1; then
    systemd-run --user --scope --quiet \
      -p "CPUQuota=$((TITAN_JOBS * 100))%" \
      env TITAN_CPU_SCOPE=0 nice -n 10 "$@"
  else
    env TITAN_CPU_SCOPE=0 nice -n 10 "$@"
  fi
}
