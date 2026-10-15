#!/usr/bin/env bash

TITAN_REPOSITORY_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
TITAN_SUPERPROJECT_ROOT=$(git -C "$TITAN_REPOSITORY_ROOT" rev-parse --show-superproject-working-tree 2>/dev/null || true)

if [[ -n "$TITAN_SUPERPROJECT_ROOT" ]]; then
  TITAN_DEFAULT_WORK_DIR="$TITAN_SUPERPROJECT_ROOT/.build_flutter"
  TITAN_DEFAULT_BUNDLE_DIR="$TITAN_SUPERPROJECT_ROOT/third_party/flutter-engine"
else
  TITAN_DEFAULT_WORK_DIR="$TITAN_REPOSITORY_ROOT/.build_flutter"
  TITAN_DEFAULT_BUNDLE_DIR="$TITAN_REPOSITORY_ROOT/artifacts"
fi

TITAN_WORK_DIR=${TITAN_WORK_DIR:-$TITAN_DEFAULT_WORK_DIR}
TITAN_BUNDLE_DIR=${TITAN_BUNDLE_DIR:-$TITAN_DEFAULT_BUNDLE_DIR}

# CPU budget for every build (Buildroot, ninja): half of the cores by
# default, so a full build never pins the desktop at 100%. Builds also run
# under `nice`. Override with TITAN_JOBS.
TITAN_JOBS=${TITAN_JOBS:-$(( $(getconf _NPROCESSORS_ONLN) / 2 > 0 ? $(getconf _NPROCESSORS_ONLN) / 2 : 1 ))}

export TITAN_WORK_DIR TITAN_BUNDLE_DIR TITAN_JOBS
