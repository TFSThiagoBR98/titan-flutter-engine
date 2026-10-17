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

macos_build_script=$(cat "$repository_root/scripts/build-engine-macos.sh")
windows_build_script=$(cat "$repository_root/scripts/build-engine-windows.ps1")
standalone_rbe_argument='(?<![A-Za-z0-9_-])[\x27\x22]?--rbe[\x27\x22]?(?![A-Za-z0-9_-])'
raise_standalone_rbe() {
  local script_name=$1 script_content=$2
  if ruby -e 'exit(ARGV.fetch(0).match?(Regexp.new(ARGV.fetch(1))) ? 0 : 1)' "$script_content" "$standalone_rbe_argument"; then
    printf '%s must not pass --rbe\n' "$script_name" >&2
    exit 1
  fi
}

assert_contains "$repository_root/scripts/build-engine-macos.sh" '--no-rbe'
assert_contains "$repository_root/scripts/build-engine-windows.ps1" "'--no-rbe'"
raise_standalone_rbe macOS "$macos_build_script"
raise_standalone_rbe Windows "$windows_build_script"

assert_sdk_variants() {
  local expected=$1 target=$2 mode=$3 actual
  actual=$($ci_script linux-sdk-variants "$target" "$mode")
  [[ "$actual" == "$expected" ]] || {
    printf 'unexpected SDK variants for %s-%s: %s\n' "$target" "$mode" "$actual" >&2
    exit 1
  }
}

assert_sdk_variants 'sdk-desktop-debug sdk-host-debug' x64 debug
assert_sdk_variants 'sdk-desktop-arm64-debug sdk-host-arm64-debug' arm64 debug
assert_sdk_variants 'sdk-desktop-riscv64-musl-release' riscv64-musl release

ruby - "$workflow" <<'RUBY'
require 'yaml'

workflow = YAML.load_file(ARGV.fetch(0))
raise 'self-hosted runner is forbidden' if File.read(ARGV.fetch(0)).include?('self-hosted')
raise 'workflow must define global read permission' unless workflow['permissions'] == {'contents' => 'read'}
jobs = workflow.fetch('jobs')
build = jobs.fetch('build')
linux_platform = jobs.fetch('linux_platform')
macos = jobs.fetch('macos')
windows = jobs.fetch('windows')
release = jobs.fetch('release')
expected_jobs = %w[build linux_platform macos windows release]
raise "unexpected jobs: #{jobs.keys.inspect}" unless jobs.keys.sort == expected_jobs.sort
%w[build linux_platform macos windows].each do |job_name|
  build_job = jobs.fetch(job_name)
  log_upload = build_job.fetch('steps').find do |step|
    step['uses'] == 'actions/upload-artifact@v4' &&
      step.dig('with', 'name').to_s.start_with?('build-logs-')
  end
  raise "#{job_name} must upload build logs" unless log_upload
  raise "#{job_name} build logs must upload on every outcome" unless log_upload['if'] == 'always()'
end
raise 'build must use the hosted runner' unless build['runs-on'] == 'ubuntu-24.04'
raise 'Linux platform job must use the hosted runner' unless linux_platform['runs-on'] == 'ubuntu-24.04'
raise 'macOS job must use the hosted runner' unless macos['runs-on'] == 'macos-15'
raise 'Windows job must use the hosted runner' unless windows['runs-on'] == 'windows-2025'
raise 'release must use the hosted runner' unless release['runs-on'] == 'ubuntu-24.04'
raise 'build must have a six-hour timeout' unless build['timeout-minutes'] == 360
raise 'release must publish contents' unless release.dig('permissions', 'contents') == 'write'
raise 'build must not use a container' if build.key?('container')
raise 'build matrix must not fail fast' unless build.dig('strategy', 'fail-fast') == false

targets = %w[x64 x64-musl arm64 arm64-musl arm-hard arm-hard-musl arm-softfp arm-softfp-musl riscv64-glibc riscv64-musl]
modes = %w[debug profile release]
raise 'Linux engine matrix must have ten targets' unless build.dig('strategy', 'matrix', 'target') == targets
raise 'Linux engine matrix must have three modes' unless build.dig('strategy', 'matrix', 'mode') == modes
raise 'Linux engine matrix must produce thirty bundles' unless targets.length * modes.length == 30
raise 'riscv32 must not be in the hosted matrix' if build.to_s.include?('riscv32')

env = build.fetch('env')
raise 'unexpected work directory' unless env['TITAN_WORK_DIR'] == '/mnt/titan/work'
raise 'unexpected bundle directory' unless env['TITAN_BUNDLE_DIR'] == '/mnt/titan/bundles'
raise 'matrix variant is not exported' unless env['TITAN_VARIANTS'] == '${{ matrix.target }}-${{ matrix.mode }}'
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
raise 'checkout cache must not be configured' unless uses.count { |use| use.start_with?('actions/cache') } == 3
cache = steps.find { |step| step['uses'] == 'actions/cache/restore@v4' }.fetch('with')
raise 'wrong ccache path' unless cache['path'] == '/mnt/titan/work/ccache'
raise 'cache key must include the target and mode' unless cache['key'].include?('${{ matrix.target }}') && cache['key'].include?('${{ matrix.mode }}')
raise 'cache key must include the run id' unless cache['key'].include?('${{ github.run_id }}')
raise 'cache key must include the Flutter lock' unless cache['key'].include?("hashFiles('flutter.lock', 'patches/**')")
raise 'cache restore keys are incomplete' unless cache['restore-keys'].include?('ccache-${{ matrix.target }}-${{ matrix.mode }}-')

runs = steps.filter_map { |step| step['run'] }.join("\n")
%w[deps build probe package].each do |stage|
  raise "missing ci stage #{stage}" unless runs.include?("scripts/ci.sh #{stage}")
end
sdk_step = steps.find { |step| step['run']&.include?('linux-sdk-variants') }
raise 'Linux SDK build step is missing' unless sdk_step
raise 'Linux SDK build must use the progress wrapper' unless sdk_step.fetch('run').include?('scripts/ci.sh with-progress')
raise 'Linux SDK build must use the matrix builder' unless sdk_step.fetch('run').include?('scripts/build-matrix.sh --parallel 1 --zip')
sdk_upload = steps.find { |step| step['uses'] == 'actions/upload-artifact@v4' && step.dig('with', 'name') == 'flutter-build-${{ matrix.target }}-${{ matrix.mode }}' }
raise 'Linux engine and SDK upload is missing' unless sdk_upload
raise 'Linux engine and SDK upload must include both archive roots' unless sdk_upload.dig('with', 'path').to_s.include?('/mnt/titan/bundles/dist/*.zip') && sdk_upload.dig('with', 'path').to_s.include?('/mnt/titan/work/flutter/engine/src/out/*/zip_archives/**')
sysroot_step = steps.find { |step| step['run']&.include?('scripts/ci.sh sysroot') }
raise 'sysroot step is missing' unless sysroot_step
raise 'sysroot step must be conditional' unless sysroot_step['if'] == "matrix.defconfig != ''"
raise 'Linux platform job must include Android and web' unless %w[android-debug-arm web-release].all? { |variant| linux_platform.fetch('env').fetch('TITAN_VARIANTS').include?(variant) }
# Fuchsia is kept out of the CI matrix on purpose (user decision, 2026-10-17).
raise 'Linux platform job must not build Fuchsia' if linux_platform.fetch('env').fetch('TITAN_VARIANTS').include?('fuchsia')
linux_platform_build = linux_platform.fetch('steps').find { |step| step['run']&.include?('build-matrix.sh') }
raise 'Linux platform build must use the progress wrapper' unless linux_platform_build&.fetch('run').to_s.include?('scripts/ci.sh with-progress')

macos_builds = macos.fetch('steps').select { |step| step['run']&.include?('build-engine-macos.sh') }
raise 'macOS build steps are incomplete' unless macos_builds.length == 2
raise 'macOS build must use the progress wrapper' unless macos_builds.all? do |step|
  run = step.fetch('run')
  run.include?('scripts/ci.sh with-progress') && run.include?('$TITAN_WORK_DIR/matrix')
end
raise 'macOS job must build Darwin and iOS' unless macos_builds.any? { |step| step['run'].include?('--kind ios') } && macos_builds.any? { |step| step['run'].include?('--kind framework') }

windows_builds = windows.fetch('steps').select { |step| step['run']&.include?('build-engine-windows.ps1') }
raise 'Windows build steps are incomplete' unless windows_builds.length == 2
raise 'Windows build must use a background heartbeat' unless windows_builds.all? do |step|
  run = step.fetch('run')
  run.include?('Start-Job') && run.include?('TITAN_PROGRESS_SECONDS') && run.include?('TITAN_WORK_DIR')
end
raise 'Windows job must build Windows and Android' unless windows_builds.any? { |step| step['run'].include?("-Kind', 'host") } && windows_builds.any? { |step| step['run'].include?("-Kind', 'android") }
raise 'sysroot cache must be keyed per defconfig' unless build.fetch('steps').any? { |step| step['uses'] == 'actions/cache@v4' && step.dig('with', 'key').to_s.include?('${{ matrix.defconfig }}') && step.dig('with', 'key').to_s.include?('hashFiles(format(') }
raise 'download-artifact must merge matrix artifacts' unless release['steps'].any? do |step|
  step['uses'] == 'actions/download-artifact@v4' && step.dig('with', 'merge-multiple') == true
end
raise 'release must run only for tags' unless release['if'].include?('refs/tags/v')
raise 'release must depend on every host job' unless release['needs'].sort == %w[build linux_platform macos windows].sort
raise 'release must assemble the full SDK' unless release['steps'].any? { |step| step['run']&.include?('scripts/ci.sh assemble') }
download = release['steps'].find { |step| step['uses'] == 'actions/download-artifact@v4' }
raise 'release must download the combined Linux build artifacts' unless download&.dig('with', 'pattern') == 'flutter-build-*' && download.dig('with', 'path') == '/mnt/titan'
RUBY

if "$ci_script" free-disk > /tmp/titan-ci-free-disk.out 2>&1; then
  printf 'free-disk unexpectedly accepted a non-CI invocation\n' >&2
  exit 1
fi
assert_contains /tmp/titan-ci-free-disk.out 'GITHUB_ACTIONS=true'
assert_contains "$ci_script" 'TITAN_JOBS=$(getconf _NPROCESSORS_ONLN)'
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
printf '%s\n' '#!/usr/bin/env bash' 'printf "1000\\n"' > "$fake_bin/getconf"
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
outside_jobs=$(( $(PATH="$fake_bin:$PATH" getconf _NPROCESSORS_ONLN) / 2 ))
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
