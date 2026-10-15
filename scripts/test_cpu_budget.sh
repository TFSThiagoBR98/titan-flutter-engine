#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

assert_contains() {
  local file=$1 expected=$2 description=$3
  grep -Fq -- "$expected" "$file" || {
    printf 'error: %s: expected %q in %s\n' "$description" "$expected" "$file" >&2
    exit 1
  }
}

fake_bin="$temporary_directory/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_SYSTEMD_RUN_LOG"
if [[ "$*" == *' true' ]]; then
  exit 0
fi
while (($# > 0)); do
  case "$1" in
    --user|--scope|--quiet) shift ;;
    -p) shift 2 ;;
    *) break ;;
  esac
done
exec "$@"
EOF
chmod +x "$fake_bin/systemd-run"

scope_log="$temporary_directory/scope.log"
scoped_output=$(
  PATH="$fake_bin:$PATH" \
  TITAN_JOBS=3 \
  TITAN_SYSTEMD_RUN_LOG="$scope_log" \
    bash -c "source '$repository_root/scripts/lib/cpu-budget.sh'; run_within_cpu_budget printf scoped"
)
[[ "$scoped_output" == scoped ]] || {
  printf 'error: scoped output: %s\n' "$scoped_output" >&2
  exit 1
}
assert_contains "$scope_log" 'CPUQuota=300%' 'CPU quota'
assert_contains "$scope_log" 'env TITAN_CPU_SCOPE=0 nice -n 10 printf scoped' 'nice command'

fallback_bin="$temporary_directory/fallback-bin"
mkdir -p "$fallback_bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$fallback_bin/systemd-run"
chmod +x "$fallback_bin/systemd-run"
fallback_output=$(
  PATH="$fallback_bin:$PATH" \
    bash -c "source '$repository_root/scripts/lib/cpu-budget.sh'; run_within_cpu_budget printf fallback"
)
[[ "$fallback_output" == fallback ]] || {
  printf 'error: fallback output: %s\n' "$fallback_output" >&2
  exit 1
}

disabled_output=$(
  PATH="$fake_bin:$PATH" \
  TITAN_CPU_SCOPE=0 \
    bash -c "source '$repository_root/scripts/lib/cpu-budget.sh'; run_within_cpu_budget printf disabled"
)
[[ "$disabled_output" == disabled ]] || {
  printf 'error: disabled output: %s\n' "$disabled_output" >&2
  exit 1
}

printf 'test_cpu_budget.sh: ok\n'
