#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/paths.sh"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
flutter="$TITAN_WORK_DIR/flutter/bin/flutter"
app_root="$repository_root/tests/qemu/app"
assets="$TITAN_WORK_DIR/probe-app/flutter_assets"

[[ -x "$flutter" ]] || die "Flutter checkout is missing: $flutter"
[[ -f "$app_root/pubspec.yaml" ]] || die "probe app pubspec is missing: $app_root/pubspec.yaml"
[[ -f "$app_root/lib/main.dart" ]] || die "probe app source is missing: $app_root/lib/main.dart"

mkdir -p "$(dirname "$assets")"
printf 'building probe app: %s\n' "$assets"
(
  cd "$app_root"
  "$flutter" build bundle --target lib/main.dart --asset-dir "$assets"
)
printf 'probe app assets: %s\n' "$assets"
