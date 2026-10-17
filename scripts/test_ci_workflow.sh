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
sysroot = jobs.fetch('sysroot')
linux_platform = jobs.fetch('linux_platform')
macos = jobs.fetch('macos')
windows = jobs.fetch('windows')
release = jobs.fetch('release')
expected_jobs = %w[build sysroot linux_platform macos windows release]
raise "unexpected jobs: #{jobs.keys.inspect}" unless jobs.keys.sort == expected_jobs.sort
%w[build sysroot linux_platform macos windows].each do |job_name|
  build_job = jobs.fetch(job_name)
  log_upload = build_job.fetch('steps').find do |step|
    step['uses'] == 'actions/upload-artifact@v4' &&
      step.dig('with', 'name').to_s.start_with?('build-logs-')
  end
  raise "#{job_name} must upload build logs" unless log_upload
  raise "#{job_name} build logs must upload on every outcome" unless log_upload['if'] == 'always()'
end
raise 'build must use the hosted runner' unless build['runs-on'] == 'ubuntu-24.04'
raise 'sysroot job must use the hosted runner' unless sysroot['runs-on'] == 'ubuntu-24.04'
raise 'Linux platform job must use the hosted runner' unless linux_platform['runs-on'] == 'ubuntu-24.04'
raise 'macOS job must use the hosted runner' unless macos['runs-on'] == 'macos-15'
raise 'Windows job must use the hosted runner' unless windows['runs-on'] == 'windows-2025'
raise 'release must use the hosted runner' unless release['runs-on'] == 'ubuntu-24.04'
raise 'build must have a six-hour timeout' unless build['timeout-minutes'] == 360
raise 'release must publish contents' unless release.dig('permissions', 'contents') == 'write'
raise 'build must not use a container' if build.key?('container')
raise 'build matrix must not fail fast' unless build.dig('strategy', 'fail-fast') == false

sysroot_defconfigs = %w[
  titan_x64_musl_defconfig
  titan_arm64_glibc_defconfig
  titan_arm64_musl_defconfig
  titan_armv7a_hf_glibc_defconfig
  titan_armv7a_hf_musl_defconfig
  titan_armv7a_softfp_glibc_defconfig
  titan_armv7a_softfp_musl_defconfig
  titan_riscv64_glibc_defconfig
  titan_riscv64_musl_defconfig
]
raise 'sysroot matrix must have the nine Buildroot defconfigs' unless sysroot.dig('strategy', 'matrix', 'defconfig') == sysroot_defconfigs
raise 'build must wait for the shared sysroots' unless build['needs'] == 'sysroot'

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
raise 'checkout cache must not be configured' unless uses.count { |use| use.start_with?('actions/cache') } == 2
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
build_runs = steps.filter_map { |step| step['run'] }
if build_runs.any? { |run| run.match?(/scripts\/ci\.sh sysroot(?:\s|[\"'])/) || run.include?('make-buildroot-sysroot.sh') }
  raise 'build cells must not build sysroots'
end
sysroot_build_runs = sysroot.fetch('steps').filter_map { |step| step['run'] }.join("\n")
raise 'sysroot job must invoke the sysroot subcommand' unless sysroot_build_runs.include?('scripts/ci.sh sysroot "$1"') && sysroot_build_runs.include?('${{ matrix.defconfig }}')
raise 'sysroot job must build through the progress wrapper' unless sysroot_build_runs.include?('scripts/ci.sh with-progress')
sysroot_upload = sysroot.fetch('steps').find { |step| step['uses'] == 'actions/upload-artifact@v4' && step.dig('with', 'name').to_s.start_with?('sysroot-') }
raise 'sysroot archive upload is missing' unless sysroot_upload
raise 'sysroot artifacts must be retained for three days' unless sysroot_upload.dig('with', 'retention-days') == 3
raise 'sysroot archive must be compressed as tar.zst' unless sysroot_upload.dig('with', 'path').to_s.end_with?('.tar.zst')
sysroot_download = steps.find { |step| step['uses'] == 'actions/download-artifact@v4' && step.dig('with', 'name').to_s.start_with?('sysroot-') }
raise 'sysroot artifact download is missing' unless sysroot_download
raise 'sysroot artifact names must match between jobs' unless sysroot_upload.dig('with', 'name') == sysroot_download.dig('with', 'name')
raise 'sysroot extraction step is missing' unless build_runs.any? { |run| run.include?('scripts/ci.sh sysroot-extract') }
platform_matrix = linux_platform.fetch('strategy').fetch('matrix')
raise 'Android platform matrix CPUs are incomplete' unless platform_matrix['android_cpu'] == %w[arm arm64 x64]
raise 'Android platform matrix modes are incomplete' unless platform_matrix['mode'] == %w[debug profile release]
raise 'web-release platform cell is missing' unless platform_matrix['include'].include?('android_cpu' => 'web', 'mode' => 'release', 'variant' => 'web-release')
raise 'Linux platform variant must be selected from the matrix' unless linux_platform.fetch('env').fetch('TITAN_VARIANTS') == "${{ matrix.variant || format('android-{0}-{1}', matrix.mode, matrix.android_cpu) }}"
linux_platform_build = linux_platform.fetch('steps').find { |step| step['run']&.include?('build-matrix.sh') }
raise 'Linux platform build must use the progress wrapper' unless linux_platform_build&.fetch('run').to_s.include?('scripts/ci.sh with-progress')
raise 'Linux platform build must build one selected variant' unless linux_platform_build.fetch('run').include?('"$TITAN_VARIANTS"')
platform_upload = linux_platform.fetch('steps').find { |step| step['uses'] == 'actions/upload-artifact@v4' && step.dig('with', 'name').to_s.include?('flutter-sdk-') }
raise 'Linux platform archive upload is missing' unless platform_upload
raise 'Linux platform archive upload must be named per cell' unless platform_upload.dig('with', 'name') == "flutter-sdk-${{ matrix.variant || format('android-{0}-{1}', matrix.mode, matrix.android_cpu) }}"

macos_modes = macos.fetch('strategy').fetch('matrix').fetch('mode')
raise 'macOS matrix must have three profiles' unless macos_modes == %w[debug profile release]
macos_builds = macos.fetch('steps').select { |step| step['run']&.include?('build-engine-macos.sh') }
raise 'macOS build must use one per-profile step' unless macos_builds.length == 1
macos_build = macos_builds.fetch(0).fetch('run')
raise 'macOS build must use the progress wrapper' unless macos_build.include?('scripts/ci.sh with-progress') && macos_build.include?('$TITAN_WORK_DIR/matrix')
raise 'macOS build must be arm64-only' unless macos_build.include?('--cpu arm64') && !macos_build.include?('--cpu x64')
raise 'macOS build must include framework and gen_snapshot' unless macos_build.include?('--kind framework') && macos_build.include?('--kind gen-snapshot')
raise 'macOS build must include iOS device and arm64 simulator' unless macos_build.include?('--kind ios --mode "$mode" --cpu arm64') && macos_build.include?('--simulator --simulator-cpu arm64')
raise 'macOS profile/release Android snapshots are missing' unless macos_build.include?('macos-arm64-$mode-android-$android_cpu') && macos_build.include?('--kind android')
raise 'macOS archive upload must be named per profile' unless macos.fetch('steps').any? { |step| step.dig('with', 'name') == 'flutter-sdk-macos-arm64-${{ matrix.mode }}' }
raise 'macOS workflow must not build a macOS x64 CPU' if macos_build.match?(/--cpu x64(?:\s|['"]|$)/)
raise 'macOS official artifact exclusions are undocumented' unless File.read(ARGV.fetch(0).sub(%r{/.github/workflows/build.yml$}, '/sdk/official-artifacts.txt')).include?('# arm64 only (user, 2026-10-17)')

windows_matrix = windows.fetch('strategy').fetch('matrix')
raise 'Windows matrix CPUs are incomplete' unless windows_matrix['cpu'] == %w[x64 arm64]
raise 'Windows matrix modes are incomplete' unless windows_matrix['mode'] == %w[debug profile release]
windows_builds = windows.fetch('steps').select { |step| step['run']&.include?('build-engine-windows.ps1') }
raise 'Windows build must have one combined step' unless windows_builds.length == 1
windows_build = windows_builds.fetch(0).fetch('run')
raise 'Windows build must use a background heartbeat' unless windows_build.include?('Start-Job') && windows_build.include?('TITAN_PROGRESS_SECONDS') && windows_build.include?('TITAN_WORK_DIR')
raise 'Windows build must centralize argument construction' unless windows_build.include?('function Get-BuildArguments') && windows_build.include?('function Invoke-LoggedBuild')
raise 'Windows build must not use array-unwrapping ArgumentList syntax' if windows_build.include?('(,$')
raise 'Windows job must build host and Android artifacts from one step' unless windows_build.include?("Get-BuildArguments 'host'") && windows_build.include?("Get-BuildArguments 'android'")
raise 'sysroot cache must not be configured in engine cells' if build.fetch('steps').any? { |step| step['uses'] == 'actions/cache@v4' }
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
assert_contains "$ci_script" 'make-buildroot-sysroot.sh" --config "$1"'
assert_contains "$ci_script" 'expected probe hash'
assert_contains "$ci_script" 'probe hash mismatch for'

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
fixture_root="$temporary_directory/repository"
fake_bin="$temporary_directory/bin"
mkdir -p "$fixture_root/scripts/lib" "$fixture_root/tests/qemu" "$fake_bin" "$temporary_directory/bundles/dist"
cp "$ci_script" "$fixture_root/scripts/ci.sh"
cp "$repository_root/scripts/lib/paths.sh" "$fixture_root/scripts/lib/paths.sh"
cp "$repository_root/scripts/lib/sysroot.sh" "$fixture_root/scripts/lib/sysroot.sh"
cp "$repository_root/scripts/sysroot-cache.sh" "$fixture_root/scripts/sysroot-cache.sh"
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
assert_contains "$temporary_directory/ci.log" 'titan_arm64_glibc_defconfig'
sysroot_fixture="$temporary_directory/work/sysroots/titan_arm64_glibc"
mkdir -p "$sysroot_fixture"
printf '%s\n' fixture > "$sysroot_fixture/fixture.txt"
run_ci sysroot-package titan_arm64_glibc_defconfig
sysroot_archive="$temporary_directory/work/sysroot-titan_arm64_glibc_defconfig.tar.zst"
[[ -f "$sysroot_archive" ]] || {
  printf 'sysroot package archive is missing\n' >&2
  exit 1
}
rm -rf "$sysroot_fixture"
run_ci sysroot-extract titan_arm64_glibc_defconfig
assert_contains "$sysroot_fixture/fixture.txt" fixture
sysroot_link="$temporary_directory/work/flutter/engine/src/build/linux/titan_arm64_glibc-sysroot"
[[ -L "$sysroot_link" && "$(readlink "$sysroot_link")" == "$sysroot_fixture" ]] || {
  printf 'sysroot extraction did not recreate the engine link\n' >&2
  exit 1
}
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
