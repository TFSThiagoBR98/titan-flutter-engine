#!/usr/bin/env bash
# ci.sh build prints each variant's Ninja progress while the build runs.
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

ci_repository="$temporary_directory/ci-repository"
mkdir -p "$ci_repository/scripts/lib"
cp "$repository_root/scripts/ci.sh" "$ci_repository/scripts/ci.sh"
cp "$repository_root/scripts/lib/paths.sh" "$ci_repository/scripts/lib/paths.sh"
cat > "$ci_repository/scripts/build-matrix.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$TITAN_WORK_DIR/matrix/x64-debug.log"
mkdir -p "$(dirname "$log")"
printf 'bootstrapping depot_tools\n' > "$log"
sleep 2
for step in 100 200 300; do
  printf '[%s/1000] CXX obj/file%s.o\n' "$step" "$step" >> "$log"
  sleep 1
done
EOF
chmod +x "$ci_repository/scripts/build-matrix.sh"

output="$temporary_directory/output.log"
TITAN_WORK_DIR="$temporary_directory/work" \
TITAN_BUNDLE_DIR="$temporary_directory/bundles" \
TITAN_VARIANTS=x64-debug \
TITAN_PARALLEL=1 \
TITAN_PROGRESS_SECONDS=1 \
  bash "$ci_repository/scripts/ci.sh" build > "$output"

grep -q '^x64-debug: preparing (checkout, gclient, GN)$' "$output" || {
  printf 'missing the preparing line before Ninja starts\n' >&2
  cat "$output" >&2
  exit 1
}
grep -qE '^x64-debug: [123]00/1000 \([123]0%\)' "$output" || {
  printf 'missing a Ninja progress line\n' >&2
  cat "$output" >&2
  exit 1
}

generic_output="$temporary_directory/generic-output.log"
TITAN_WORK_DIR="$temporary_directory/generic-work" \
TITAN_BUNDLE_DIR="$temporary_directory/bundles" \
TITAN_PROGRESS_SECONDS=1 \
  bash "$ci_repository/scripts/ci.sh" with-progress x64-debug -- \
    bash "$ci_repository/scripts/build-matrix.sh" > "$generic_output"

grep -q '^x64-debug: preparing (checkout, gclient, GN)$' "$generic_output" || {
  printf 'generic progress mode did not report preparation\n' >&2
  cat "$generic_output" >&2
  exit 1
}
grep -qE '^x64-debug: [123]00/1000 \([123]0%\)' "$generic_output" || {
  printf 'generic progress mode did not report Ninja progress\n' >&2
  cat "$generic_output" >&2
  exit 1
}
printf 'test_ci_progress.sh: ok\n'
