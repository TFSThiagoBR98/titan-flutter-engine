#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
ci_script="$repository_root/scripts/ci.sh"
workflow="$repository_root/.github/workflows/build.yml"
readme="$repository_root/README.md"

assert_contains() {
  local file=$1 expected=$2
  grep -Fq -- "$expected" "$file" || {
    printf 'missing %q in %s\n' "$expected" "$file" >&2
    exit 1
  }
}

sysroots_text=$(sed -n '/^run_sysroots()/,/^run_build()/p' "$ci_script")
for config in \
  titan_x64_musl_defconfig \
  titan_arm64_glibc_defconfig \
  titan_arm64_musl_defconfig \
  titan_armv7a_hf_glibc_defconfig \
  titan_armv7a_hf_musl_defconfig \
  titan_armv7a_softfp_glibc_defconfig \
  titan_armv7a_softfp_musl_defconfig \
  titan_riscv64_glibc_defconfig \
  titan_riscv64_musl_defconfig; do
  grep -Fq -- "$config" <<<"$sysroots_text" || {
    printf 'missing sysroot config: %s\n' "$config" >&2
    exit 1
  }
done
if grep -Fq riscv32 <<<"$sysroots_text"; then
  printf 'riscv32 must not be in the default sysroot job\n' >&2
  exit 1
fi
[[ "$(grep -Fc -- '--publish' <<<"$sysroots_text")" -eq 1 ]] || {
  printf 'sysroot stage must publish each configured sysroot\n' >&2
  exit 1
}

assert_contains "$workflow" 'runs-on: [self-hosted, linux, x64]'
assert_contains "$workflow" 'TITAN_CPU_SCOPE: 0'
assert_contains "$workflow" 'TITAN_JOBS: ${{ vars.TITAN_JOBS || '\''8'\'' }}'
assert_contains "$workflow" 'GH_TOKEN: ${{ github.token }}'
assert_contains "$workflow" 'needs: sysroots'
assert_contains "$workflow" 'actions/upload-artifact@v4'
if grep -Fq 'actions/cache' "$workflow"; then
  printf 'workflow must not use actions/cache\n' >&2
  exit 1
fi

assert_contains "$ci_script" 'gh release create'
if grep -Fq FORGEJO_TOKEN "$ci_script"; then
  printf 'ci release must not use Forgejo credentials\n' >&2
  exit 1
fi
assert_contains "$readme" 'GitHub Actions'
assert_contains "$readme" 'self-hosted'
assert_contains "$readme" 'vars.TITAN_JOBS'
assert_contains "$readme" '/srv/titan-flutter-engine'
assert_contains "$readme" 'sysroot-cache'

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
fake_bin="$temporary_directory/bin"
mkdir -p "$fake_bin" "$temporary_directory/bundles/dist"
cat > "$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TITAN_GH_LOG"
[[ "${1:-}" == release && "${2:-}" == create ]]
EOF
chmod +x "$fake_bin/gh"
: > "$temporary_directory/bundles/dist/engine.zip"
: > "$temporary_directory/bundles/dist/SHA256SUMS"
TITAN_BUNDLE_DIR="$temporary_directory/bundles" \
GITHUB_REF=refs/tags/v0.1.0 \
GITHUB_REPOSITORY=example/titan-flutter-engine \
TITAN_GH_LOG="$temporary_directory/gh.log" \
PATH="$fake_bin:$PATH" \
  bash "$ci_script" release
assert_contains "$temporary_directory/gh.log" 'release create v0.1.0'
assert_contains "$temporary_directory/gh.log" 'engine.zip'
assert_contains "$temporary_directory/gh.log" 'SHA256SUMS'

printf 'test_ci_workflow.sh: ok\n'
