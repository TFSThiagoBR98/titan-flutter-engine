#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
ci_script="$repository_root/scripts/ci.sh"
workflow="$repository_root/.github/workflows/build.yml"

assert_contains() {
  local file=$1 expected=$2
  grep -Fq -- "$expected" "$file" || {
    printf 'missing %q in %s\n' "$expected" "$file" >&2
    exit 1
  }
}

ruby - "$workflow" <<'RUBY'
require 'yaml'

workflow = YAML.load_file(ARGV.fetch(0))
raise 'self-hosted runner is forbidden' if File.read(ARGV.fetch(0)).include?('self-hosted')
raise 'workflow must define global read permission' unless workflow['permissions'] == {'contents' => 'read'}
jobs = workflow.fetch('jobs')
build = jobs.fetch('build')
release = jobs.fetch('release')
raise 'build must use the hosted runner' unless build['runs-on'] == 'ubuntu-24.04'
raise 'release must use the hosted runner' unless release['runs-on'] == 'ubuntu-24.04'
raise 'build must have a six-hour timeout' unless build['timeout-minutes'] == 360
raise 'build must publish sysroots' unless build.dig('permissions', 'contents') == 'write'
raise 'release must publish contents' unless release.dig('permissions', 'contents') == 'write'
raise 'build must not depend on sysroots job' if build.key?('needs')
raise 'build must not use a container' if build.key?('container')
raise 'build matrix must not fail fast' unless build.dig('strategy', 'fail-fast') == false

expected = {
  'x64-debug' => '',
  'x64-musl-debug' => 'titan_x64_musl_defconfig',
  'arm64-debug' => 'titan_arm64_glibc_defconfig',
  'arm64-musl-debug' => 'titan_arm64_musl_defconfig',
  'arm-hard-debug' => 'titan_armv7a_hf_glibc_defconfig',
  'arm-hard-musl-debug' => 'titan_armv7a_hf_musl_defconfig',
  'arm-softfp-debug' => 'titan_armv7a_softfp_glibc_defconfig',
  'arm-softfp-musl-debug' => 'titan_armv7a_softfp_musl_defconfig',
  'riscv64-glibc-debug' => 'titan_riscv64_glibc_defconfig',
  'riscv64-musl-debug' => 'titan_riscv64_musl_defconfig',
}
actual = build.dig('strategy', 'matrix', 'include').to_h do |entry|
  [entry.fetch('variant'), entry.fetch('defconfig')]
end
raise "unexpected matrix: #{actual.inspect}" unless actual == expected
raise 'riscv32 must not be in the hosted matrix' if actual.keys.any? { |variant| variant.include?('riscv32') }

env = build.fetch('env')
raise 'unexpected work directory' unless env['TITAN_WORK_DIR'] == '/mnt/titan/work'
raise 'unexpected bundle directory' unless env['TITAN_BUNDLE_DIR'] == '/mnt/titan/bundles'
raise 'matrix variant is not exported' unless env['TITAN_VARIANTS'] == '${{ matrix.variant }}'
raise 'parallelism must be one' unless env['TITAN_PARALLEL'] == 1
raise 'GitHub token is not exported' unless env['GH_TOKEN'] == '${{ github.token }}'
raise 'ccache size is not capped at 900M' unless env['CCACHE_MAXSIZE'] == '900M'

steps = build.fetch('steps')
uses = steps.filter_map { |step| step['uses'] }
raise 'checkout is missing' unless uses.include?('actions/checkout@v4')
raise 'ccache restore is missing' unless uses.include?('actions/cache/restore@v4')
raise 'ccache save is missing' unless uses.include?('actions/cache/save@v4')
save = steps.find { |step| step['uses'] == 'actions/cache/save@v4' }
raise 'ccache must be saved even when the job fails' unless save['if'].to_s.include?('always()')
raise 'ccache must not be saved when the build was cancelled' unless save['if'].to_s.include?("steps.build.outcome == 'failure'") && !save['if'].to_s.include?('cancelled')
raise 'artifact upload is missing' unless uses.include?('actions/upload-artifact@v4')
raise 'checkout cache must not be configured' unless uses.count { |use| use.start_with?('actions/cache') } == 2
cache = steps.find { |step| step['uses'] == 'actions/cache/restore@v4' }.fetch('with')
raise 'wrong ccache path' unless cache['path'] == '/mnt/titan/work/ccache'
raise 'cache key must include the variant' unless cache['key'].include?('${{ matrix.variant }}')
raise 'cache key must include the run id' unless cache['key'].include?('${{ github.run_id }}')
raise 'cache key must include the Flutter lock' unless cache['key'].include?("hashFiles('flutter.lock', 'patches/**')")
raise 'cache restore keys are incomplete' unless cache['restore-keys'].include?('ccache-${{ matrix.variant }}-')

runs = steps.filter_map { |step| step['run'] }.join("\n")
%w[deps build probe package].each do |stage|
  raise "missing ci stage #{stage}" unless runs.include?("scripts/ci.sh #{stage}")
end
sysroot_step = steps.find { |step| step['run']&.include?('scripts/ci.sh sysroot') }
raise 'sysroot step is missing' unless sysroot_step
raise 'sysroot step must be conditional' unless sysroot_step['if'] == "matrix.defconfig != ''"
raise 'download-artifact must merge matrix artifacts' unless release['steps'].any? do |step|
  step['uses'] == 'actions/download-artifact@v4' && step.dig('with', 'merge-multiple') == true
end
raise 'release must run only for tags' unless release['if'].include?('refs/tags/v')
raise 'release must depend on build' unless release['needs'] == 'build'
RUBY

if "$ci_script" free-disk > /tmp/titan-ci-free-disk.out 2>&1; then
  printf 'free-disk unexpectedly accepted a non-CI invocation\n' >&2
  exit 1
fi
assert_contains /tmp/titan-ci-free-disk.out 'GITHUB_ACTIONS=true'
assert_contains "$ci_script" 'TITAN_JOBS=$(nproc)'
assert_contains "$ci_script" 'export TITAN_CPU_SCOPE=0'
assert_contains "$ci_script" 'make-buildroot-sysroot.sh" --config "$1" --publish'
assert_contains "$ci_script" 'expected probe hash'
assert_contains "$ci_script" 'probe hash mismatch for'

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
fixture_root="$temporary_directory/repository"
fake_bin="$temporary_directory/bin"
mkdir -p "$fixture_root/scripts/lib" "$fixture_root/tests/qemu" "$fake_bin" "$temporary_directory/bundles/dist"
cp "$ci_script" "$fixture_root/scripts/ci.sh"
cp "$repository_root/scripts/lib/paths.sh" "$fixture_root/scripts/lib/paths.sh"
printf '%s\n' 8dca0036f583054a > "$fixture_root/tests/qemu/expected-frame-hash"
printf 'flutter_commit=test-commit\n' > "$fixture_root/flutter.lock"
printf '%s\n' '#!/usr/bin/env bash' 'printf "jobs=%s scope=%s args=%s\\n" "$TITAN_JOBS" "${TITAN_CPU_SCOPE-}" "$*" >> "$TITAN_LOG"' > "$fixture_root/scripts/build-matrix.sh"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >> "$TITAN_LOG"' > "$fixture_root/scripts/make-buildroot-sysroot.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fixture_root/scripts/build-probe-app.sh"
printf '%s\n' '#!/usr/bin/env bash' 'printf "frame 320x240 hash=8dca0036f583054a\\nok\\n"' > "$fixture_root/scripts/qemu-probe.sh"
chmod +x "$fixture_root/scripts"/*.sh
printf '%s\n' '#!/usr/bin/env bash' 'printf "sudo %s\\n" "$*" >> "$TITAN_LOG"' 'if [[ "$1" == -n ]]; then shift; fi' '"$@"' > "$fake_bin/sudo"
printf '%s\n' '#!/usr/bin/env bash' 'if [[ "$1" == -u ]]; then printf "1000\\n"; else /usr/bin/id "$@"; fi' > "$fake_bin/id"
printf '%s\n' '#!/usr/bin/env bash' 'printf "df %s\\n" "$*"' > "$fake_bin/df"
printf '%s\n' '#!/usr/bin/env bash' 'printf "rm %s\\n" "$*" >> "$TITAN_LOG"' > "$fake_bin/rm"
printf '%s\n' '#!/usr/bin/env bash' 'printf "docker %s\\n" "$*" >> "$TITAN_LOG"' > "$fake_bin/docker"
printf '%s\n' '#!/usr/bin/env bash' 'printf "apt-get %s\\n" "$*" >> "$TITAN_LOG"' > "$fake_bin/apt-get"
printf '%s\n' '#!/usr/bin/env bash' 'printf "1000\\n"' > "$fake_bin/nproc"
chmod +x "$fake_bin"/*

run_ci() {
  env -u TITAN_JOBS -u TITAN_CPU_SCOPE \
    PATH="$fake_bin:$PATH" \
    TITAN_LOG="$temporary_directory/ci.log" \
    TITAN_WORK_DIR="$temporary_directory/work" \
    TITAN_BUNDLE_DIR="$temporary_directory/bundles" \
    "$fixture_root/scripts/ci.sh" "$@"
}

GITHUB_ACTIONS=true run_ci deps
assert_contains "$temporary_directory/ci.log" 'sudo -n apt-get update'
GITHUB_ACTIONS=true run_ci build
assert_contains "$temporary_directory/ci.log" 'jobs=1000 scope=0'
run_ci build
outside_jobs=$(( $(getconf _NPROCESSORS_ONLN) / 2 ))
((outside_jobs > 0)) || outside_jobs=1
assert_contains "$temporary_directory/ci.log" "jobs=$outside_jobs scope="
GITHUB_ACTIONS=true run_ci free-disk > "$temporary_directory/free-disk.out"
assert_contains "$temporary_directory/free-disk.out" 'df -h / /mnt'
assert_contains "$temporary_directory/ci.log" 'rm -rf /usr/share/dotnet'
assert_contains "$temporary_directory/ci.log" 'docker image prune -af'
GITHUB_ACTIONS=true run_ci sysroot titan_arm64_glibc_defconfig
assert_contains "$temporary_directory/ci.log" 'titan_arm64_glibc_defconfig --publish'
run_ci probe
: > "$temporary_directory/bundles/dist/flutter-engine-test-commit.zip"
: > "$temporary_directory/bundles/dist/flutter-engine-other.zip"
TITAN_VARIANTS=x64-debug run_ci package
assert_contains "$temporary_directory/bundles/dist/SHA256SUMS" 'flutter-engine-test-commit.zip'
if grep -Fq 'flutter-engine-other.zip' "$temporary_directory/bundles/dist/SHA256SUMS"; then
  printf 'package included an unselected variant\n' >&2
  exit 1
fi

release_bin="$temporary_directory/release-bin"
mkdir -p "$release_bin" "$temporary_directory/release-bundles/dist"
cat > "$release_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TITAN_GH_LOG"
[[ "${1:-}" == release && "${2:-}" == create ]]
EOF
chmod +x "$release_bin/gh"
: > "$temporary_directory/release-bundles/dist/engine.zip"
: > "$temporary_directory/release-bundles/dist/SHA256SUMS"
TITAN_BUNDLE_DIR="$temporary_directory/release-bundles" \
GITHUB_REF=refs/tags/v0.1.0 \
GITHUB_REF_NAME=v0.1.0 \
GITHUB_REPOSITORY=example/titan-flutter-engine \
TITAN_GH_LOG="$temporary_directory/gh.log" \
PATH="$release_bin:$PATH" \
  bash "$ci_script" release
assert_contains "$temporary_directory/gh.log" 'release create v0.1.0'
assert_contains "$temporary_directory/gh.log" 'engine.zip'
assert_contains "$temporary_directory/gh.log" 'SHA256SUMS'

printf 'test_ci_workflow.sh: ok\n'
