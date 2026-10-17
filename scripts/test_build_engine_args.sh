#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

standalone_repository="$temporary_directory/titan-flutter-engine"
flutter_directory="$temporary_directory/work/flutter"
fake_bin="$temporary_directory/bin"
gn_log="$temporary_directory/gn.log"
ninja_log="$temporary_directory/ninja.log"
python_log="$temporary_directory/python.log"
real_python=$(command -v python3)

mkdir -p "$standalone_repository/scripts/lib" "$standalone_repository/patches/test-patches" \
  "$temporary_directory/work/depot_tools" \
  "$flutter_directory/engine/src/flutter/tools" "$fake_bin"
# An already bootstrapped depot_tools has this marker.
: > "$temporary_directory/work/depot_tools/python3_bin_reldir.txt"
cp "$repository_root/scripts/build-engine.sh" "$standalone_repository/scripts/build-engine.sh"
cp "$repository_root/scripts/patch_series.py" "$standalone_repository/scripts/patch_series.py"
cp "$repository_root/scripts/lib/paths.sh" "$standalone_repository/scripts/lib/paths.sh"
cp "$repository_root/scripts/lib/cpu-budget.sh" "$standalone_repository/scripts/lib/cpu-budget.sh"
cp "$repository_root/scripts/lib/sysroot.sh" "$standalone_repository/scripts/lib/sysroot.sh"
printf '%s\n' test-patches > "$standalone_repository/patches/series"

git init --quiet "$flutter_directory"
git -C "$flutter_directory" config user.email test@example.invalid
git -C "$flutter_directory" config user.name "Build Engine Test"
printf '%s\n' 'fake Flutter checkout' > "$flutter_directory/README"
git -C "$flutter_directory" add README
git -C "$flutter_directory" commit --quiet -m 'test: fake Flutter checkout'
flutter_commit=$(git -C "$flutter_directory" rev-parse HEAD)
printf 'flutter_commit=%s\n' "$flutter_commit" > "$standalone_repository/flutter.lock"

host_sysroot="$flutter_directory/engine/src/build/linux/debian_bullseye_i386-sysroot"
cat > "$fake_bin/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_PYTHON_LOG"
if [[ "${1:-}" == */install-sysroot.py && "${2:-}" == '--arch=i386' ]]; then
  mkdir -p "$TITAN_HOST_SYSROOT"
  exit 0
fi
exec "$TITAN_REAL_PYTHON" "$@"
EOF
chmod +x "$fake_bin/python3"

dependency_repository="$flutter_directory/engine/src/flutter/third_party/fake-dependency"
mkdir -p "$dependency_repository"
git init --quiet "$dependency_repository"
git -C "$dependency_repository" config user.email test@example.invalid
git -C "$dependency_repository" config user.name "Build Engine Test"
printf '%s\n' 'fake dependency' > "$dependency_repository/dependency.txt"
git -C "$dependency_repository" add dependency.txt
git -C "$dependency_repository" commit --quiet -m 'test: fake dependency repository'

cat > "$standalone_repository/patches/test-patches/0001-fake-flutter.patch" <<'EOF'
diff --git a/README b/README
--- a/README
+++ b/README
@@ -1 +1 @@
-fake Flutter checkout
+patched Flutter checkout
EOF

cat > "$standalone_repository/patches/test-patches/0002-fake-dependency.patch" <<'EOF'
# Repo: engine/src/flutter/third_party/fake-dependency
diff --git a/dependency.txt b/dependency.txt
--- a/dependency.txt
+++ b/dependency.txt
@@ -1 +1 @@
-fake dependency
+patched dependency
diff --git a/created.txt b/created.txt
new file mode 100644
--- /dev/null
+++ b/created.txt
@@ -0,0 +1 @@
+created by patch
EOF

fake_gn="$flutter_directory/engine/src/flutter/tools/fake-gn"
cat > "$fake_gn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_GN_LOG"
EOF
chmod +x "$fake_gn"

fake_ninja="$fake_bin/ninja"
cat > "$fake_ninja" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_NINJA_LOG"
if [[ "${1:-}" == -C ]]; then
  output_directory=$2
  mkdir -p "$output_directory"
  : > "$output_directory/libflutter_engine.so"
  : > "$output_directory/flutter_embedder.h"
  : > "$output_directory/icudtl.dat"
fi
EOF
chmod +x "$fake_ninja"

cat > "$fake_bin/readelf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  -h)
    cat <<'OUTPUT'
ELF Header:
  Class:                             ELF64
  Machine:                           Advanced Micro Devices X86-64
  Flags:                             0x0
OUTPUT
    ;;
  -d)
    printf ' 0x0000000000000001 (NEEDED)             Shared library: [libc.so]\n'
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x "$fake_bin/readelf"

cat > "$fake_bin/objdump" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '0000000000000000 g    DF .text  0000000000000001 GLIBC_2.38 fake_symbol\n'
EOF
chmod +x "$fake_bin/objdump"

run_engine() {
  TITAN_GN="$fake_gn" \
  TITAN_GN_LOG="$gn_log" \
  TITAN_PYTHON_LOG="$python_log" \
  TITAN_REAL_PYTHON="$real_python" \
  TITAN_HOST_SYSROOT="$host_sysroot" \
  TITAN_NINJA_LOG="$ninja_log" \
  TITAN_WORK_DIR="$temporary_directory/work" \
  TITAN_BUNDLE_DIR="$temporary_directory/bundle" \
  FVM_ROOT="$temporary_directory/fvm" \
  PATH="$fake_bin:$PATH" \
    "$standalone_repository/scripts/build-engine.sh" "$@"
}

start_lock_holder() {
  local lock_path=$1 ready_path=$2
  (
    exec 9>"$lock_path"
    flock -n 9
    : > "$ready_path"
    sleep 30
  ) &
  lock_holder_pid=$!
  for _ in {1..100}; do
    [[ -f "$ready_path" ]] && return 0
    sleep 0.01
  done
  printf 'the test lock holder did not become ready\n' >&2
  exit 1
}

stop_lock_holder() {
  kill "$lock_holder_pid" 2>/dev/null || true
  wait "$lock_holder_pid" 2>/dev/null || true
}

bootstrap_repository="$temporary_directory/bootstrap-repository"
bootstrap_work="$temporary_directory/bootstrap-work"
bootstrap_remote="$temporary_directory/bootstrap-remote"
bootstrap_bin="$temporary_directory/bootstrap-bin"
bootstrap_flutter="$bootstrap_work/flutter"
bootstrap_commit=
mkdir -p "$bootstrap_repository/scripts/lib" "$bootstrap_repository/patches" \
  "$bootstrap_remote/engine/src/flutter/tools" "$bootstrap_work/depot_tools" "$bootstrap_bin"
cp "$repository_root/scripts/build-engine.sh" "$bootstrap_repository/scripts/build-engine.sh"
cp "$repository_root/scripts/patch_series.py" "$bootstrap_repository/scripts/patch_series.py"
cp "$repository_root/scripts/lib/paths.sh" "$bootstrap_repository/scripts/lib/paths.sh"
cp "$repository_root/scripts/lib/cpu-budget.sh" "$bootstrap_repository/scripts/lib/cpu-budget.sh"
cp "$repository_root/scripts/lib/sysroot.sh" "$bootstrap_repository/scripts/lib/sysroot.sh"
: > "$bootstrap_repository/patches/series"

git init --quiet "$bootstrap_remote"
git -C "$bootstrap_remote" config user.email test@example.invalid
git -C "$bootstrap_remote" config user.name "Build Engine Test"
printf '%s\n' 'first remote Flutter commit' > "$bootstrap_remote/README"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$bootstrap_remote/engine/src/flutter/tools/gn"
chmod +x "$bootstrap_remote/engine/src/flutter/tools/gn"
git -C "$bootstrap_remote" add README engine
git -C "$bootstrap_remote" commit --quiet -m 'test: first remote Flutter commit'
printf '%s\n' 'second remote Flutter commit' > "$bootstrap_remote/README"
git -C "$bootstrap_remote" add README
git -C "$bootstrap_remote" commit --quiet -m 'test: second remote Flutter commit'
bootstrap_commit=$(git -C "$bootstrap_remote" rev-parse HEAD)
printf 'flutter_commit=%s\n' "$bootstrap_commit" > "$bootstrap_repository/flutter.lock"

# Record where gclient runs; the .gclient must sit in that directory.
gclient_log="$temporary_directory/gclient.log"
printf '%s\n' '#!/usr/bin/env bash' "pwd >> '$gclient_log'" 'exit 0' > "$bootstrap_work/depot_tools/gclient"
chmod +x "$bootstrap_work/depot_tools/gclient"
# Fresh depot_tools: no marker yet; ensure_bootstrap must create it once.
ensure_bootstrap_log="$temporary_directory/ensure-bootstrap.log"
cat > "$bootstrap_work/depot_tools/ensure_bootstrap" <<EOF
#!/usr/bin/env bash
printf 'bootstrap\n' >> '$ensure_bootstrap_log'
: > '$bootstrap_work/depot_tools/python3_bin_reldir.txt'
EOF
chmod +x "$bootstrap_work/depot_tools/ensure_bootstrap"
cat > "$bootstrap_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == clone && "${2:-}" == https://github.com/flutter/flutter.git ]]; then
  exec "$REAL_GIT" clone "$FAKE_FLUTTER_REMOTE" "$3"
fi
if [[ "${1:-}" == -C && "${3:-}" == remote && "${4:-}" == add && "${5:-}" == origin ]]; then
  exec "$REAL_GIT" -C "$2" remote add origin "$FAKE_FLUTTER_REMOTE"
fi
exec "$REAL_GIT" "$@"
EOF
chmod +x "$bootstrap_bin/git"

run_bootstrap_engine() {
  REAL_GIT="$(command -v git)" \
  FAKE_FLUTTER_REMOTE="$bootstrap_remote" \
  TITAN_GN_LOG="$gn_log" \
  TITAN_PYTHON_LOG="$python_log" \
  TITAN_REAL_PYTHON="$real_python" \
  TITAN_HOST_SYSROOT="$host_sysroot" \
  TITAN_NINJA_LOG="$ninja_log" \
  TITAN_GN="$fake_gn" \
  TITAN_WORK_DIR="$bootstrap_work" \
  TITAN_BUNDLE_DIR="$temporary_directory/bootstrap-bundle" \
  FVM_ROOT="$temporary_directory/bootstrap-fvm" \
  PATH="$bootstrap_bin:$fake_bin:$PATH" \
    "$bootstrap_repository/scripts/build-engine.sh" "$@"
}

assert_log_contains() {
  local log_path=$1
  local expected=$2
  grep -Fq -- "$expected" "$log_path" || {
    printf 'missing log entry: %s\nlog:\n' "$expected" >&2
    sed -n '1,120p' "$log_path" >&2
    exit 1
  }
}

assert_log_not_contains() {
  local log_path=$1
  local unexpected=$2
  if grep -Fq -- "$unexpected" "$log_path"; then
    printf 'unexpected log entry: %s\nlog:\n' "$unexpected" >&2
    sed -n '1,120p' "$log_path" >&2
    exit 1
  fi
}

run_bootstrap_engine --gn-only
[[ "$(<"$gclient_log")" == "$bootstrap_flutter" ]] || {
  printf 'gclient did not run at the root of the Flutter checkout: %s\n' "$(<"$gclient_log")" >&2
  exit 1
}
[[ "$(wc -l < "$ensure_bootstrap_log")" -eq 1 ]] || {
  printf 'a fresh depot_tools was not bootstrapped exactly once\n' >&2
  exit 1
}
grep -Fq '"name": ".",' "$bootstrap_flutter/.gclient" || {
  printf 'the .gclient does not declare the Flutter checkout as solution "."\n' >&2
  exit 1
}
if grep -q 'target_os_only' "$bootstrap_flutter/.gclient"; then
  printf 'the .gclient sets target_os_only, which gclient rejects without target_os\n' >&2
  exit 1
fi
[[ "$(git -C "$bootstrap_flutter" rev-parse --is-shallow-repository)" == true ]] || {
  printf 'new Flutter checkout is not shallow\n' >&2
  exit 1
}
[[ "$(git -C "$bootstrap_flutter" rev-parse HEAD)" == "$bootstrap_commit" ]] || {
  printf 'new Flutter checkout is not at flutter_commit\n' >&2
  exit 1
}

lock_directory="$flutter_directory/engine/src/out/host_debug"
lock_path="$lock_directory/.titan-build.lock"
lock_ready="$temporary_directory/build-engine-lock-ready"
mkdir -p "$lock_directory"
start_lock_holder "$lock_path" "$lock_ready"
: > "$gn_log"
: > "$ninja_log"
if timeout 10 env \
  TITAN_GN="$fake_gn" \
  TITAN_GN_LOG="$gn_log" \
  TITAN_PYTHON_LOG="$python_log" \
  TITAN_REAL_PYTHON="$real_python" \
  TITAN_HOST_SYSROOT="$host_sysroot" \
  TITAN_NINJA_LOG="$ninja_log" \
  TITAN_WORK_DIR="$temporary_directory/work" \
  TITAN_BUNDLE_DIR="$temporary_directory/bundle" \
  FVM_ROOT="$temporary_directory/fvm" \
  PATH="$fake_bin:$PATH" \
  "$standalone_repository/scripts/build-engine.sh" --ninja-target first/target \
  >"$temporary_directory/build-engine-lock.out" 2>&1; then
  stop_lock_holder
  printf 'build-engine should refuse a concurrent build\n' >&2
  exit 1
else
  status=$?
fi
stop_lock_holder
[[ "$status" -ne 0 ]] || {
  printf 'concurrent build-engine returned success\n' >&2
  exit 1
}
assert_log_contains "$temporary_directory/build-engine-lock.out" \
  "another build is running in $lock_directory"
[[ ! -s "$gn_log" ]] || {
  printf 'GN ran while the build lock was held\n' >&2
  exit 1
}
[[ ! -s "$ninja_log" ]] || {
  printf 'ninja ran while the build lock was held\n' >&2
  exit 1
}

: > "$gn_log"
: > "$python_log"
run_engine --gn-only
assert_log_contains "$gn_log" '--target-dir host_debug'
assert_log_contains "$gn_log" 'build_linux_gtk_shell=false titan_target_libc="glibc"'
assert_log_not_contains "$gn_log" '--enable-fontconfig'
assert_log_not_contains "$python_log" 'install-sysroot.py --arch=i386'

: > "$gn_log"
run_engine --gn-only --unittests
assert_log_not_contains "$gn_log" '--no-enable-unittests'

: > "$gn_log"
run_engine --gn-only
assert_log_contains "$gn_log" '--no-enable-unittests'
[[ "$(<"$flutter_directory/README")" == 'patched Flutter checkout' ]] || {
  printf 'Flutter repository patch was not applied\n' >&2
  exit 1
}
[[ "$(<"$dependency_repository/dependency.txt")" == 'patched dependency' ]] || {
  printf 'dependency repository patch was not applied\n' >&2
  exit 1
}
[[ "$(<"$dependency_repository/created.txt")" == 'created by patch' ]] || {
  printf 'dependency repository created file was not applied\n' >&2
  exit 1
}

printf '%s\n' 'dirty Flutter checkout' > "$flutter_directory/README"
printf '%s\n' 'dirty dependency' > "$dependency_repository/dependency.txt"
printf '%s\n' 'dirty created file' > "$dependency_repository/created.txt"
rm "$flutter_directory/.titan-patches.sha256"
run_engine --gn-only
[[ "$(<"$flutter_directory/README")" == 'patched Flutter checkout' ]] || {
  printf 'Flutter repository patch was not restored before applying\n' >&2
  exit 1
}
[[ "$(<"$dependency_repository/dependency.txt")" == 'patched dependency' ]] || {
  printf 'dependency repository patch was not restored before applying\n' >&2
  exit 1
}
[[ "$(<"$dependency_repository/created.txt")" == 'created by patch' ]] || {
  printf 'dependency repository created file was not restored before applying\n' >&2
  exit 1
}

: > "$gn_log"
run_engine --mode profile --gtk-shell --enable-fontconfig --gn-only
assert_log_contains "$gn_log" '--target-dir host_profile'
assert_log_contains "$gn_log" 'build_linux_gtk_shell=true titan_target_libc="glibc"'
assert_log_contains "$gn_log" '--enable-fontconfig'

riscv32_sysroot="$temporary_directory/riscv32-sysroot"
mkdir -p "$riscv32_sysroot/usr/lib/gcc/riscv32-linux-gnu/14"
: > "$riscv32_sysroot/usr/lib/gcc/riscv32-linux-gnu/14/libgcc_eh.a"
if run_engine --mode debug --cpu riscv32 --target-sysroot "$riscv32_sysroot" --gn-only \
  > "$temporary_directory/missing-stamp.log" 2>&1; then
  printf 'build-engine accepted a sysroot without a stamp\n' >&2
  exit 1
fi
assert_log_contains "$temporary_directory/missing-stamp.log" 'incomplete or outdated'
rm -rf "$host_sysroot"
printf '%s\n' fixture-key > "$riscv32_sysroot/.titan-sysroot-key"
: > "$gn_log"
: > "$python_log"
run_engine --mode debug --cpu riscv32 --target-sysroot "$riscv32_sysroot" --gn-only
assert_log_contains "$gn_log" '--linux --linux-cpu riscv32'
assert_log_contains "$gn_log" "--target-sysroot $riscv32_sysroot"
assert_log_contains "$python_log" 'install-sysroot.py --arch=i386'
[[ -d "$host_sysroot" ]] || {
  printf 'riscv32 host sysroot was not installed\n' >&2
  exit 1
}

run_engine --mode debug --out "$temporary_directory/verified-bundle"
[[ -f "$temporary_directory/verified-bundle/$flutter_commit/libflutter_engine.so" ]] || {
  printf 'verified bundle was not published\n' >&2
  exit 1
}

: > "$ninja_log"
run_engine --mode release --out-name sdk_custom \
  --ninja-target first/target --ninja-target second/target --jobs 2 --load 2
assert_log_contains "$ninja_log" '-C '
assert_log_contains "$ninja_log" 'first/target second/target'
assert_log_not_contains "$ninja_log" 'flutter/shell/platform/embedder:flutter_engine_library'

[[ "$(run_engine --mode debug --cpu x64 --print-out-name)" == host_debug ]] || {
  printf 'unexpected default output name\n' >&2
  exit 1
}
[[ "$(run_engine --mode release --out-name sdk_custom --print-out-name)" == sdk_custom ]] || {
  printf 'unexpected overridden output name\n' >&2
  exit 1
}

matrix_repository="$temporary_directory/matrix-repository"
matrix_log="$temporary_directory/matrix.log"
mkdir -p "$matrix_repository/scripts/lib"
cp "$repository_root/scripts/build-matrix.sh" "$matrix_repository/scripts/build-matrix.sh"
cp "$repository_root/scripts/lib/paths.sh" "$matrix_repository/scripts/lib/paths.sh"
cp "$repository_root/scripts/lib/cpu-budget.sh" "$matrix_repository/scripts/lib/cpu-budget.sh"
matrix_build_engine="$matrix_repository/scripts/build-engine.sh"
cat > "$matrix_build_engine" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/cpu-budget.sh"

out_name=
print_out_name=0
cpu=x64
libc=glibc
arm_abi=none
mode=debug
previous=
for argument in "$@"; do
  case "$previous" in
    --out-name) out_name=$argument ;;
    --cpu) cpu=$argument ;;
    --libc) libc=$argument ;;
    --arm-float-abi) arm_abi=$argument ;;
    --mode) mode=$argument ;;
  esac
  case "$argument" in
    --out-name|--cpu|--libc|--arm-float-abi|--mode) previous=$argument ;;
    --print-out-name) print_out_name=1; previous= ;;
    *) previous= ;;
  esac
done
if ((print_out_name)); then
  if [[ -n "$out_name" ]]; then
    printf '%s\n' "$out_name"
  else
    printf '%s-%s-%s-%s\n' "$mode" "$cpu" "$arm_abi" "$libc"
  fi
  exit 0
fi
run_within_cpu_budget printf '%s\n' "$*" >> "$TITAN_MATRIX_ARGS_LOG"
EOF
chmod +x "$matrix_build_engine"

TITAN_WORK_DIR="$temporary_directory/matrix-work" \
TITAN_MATRIX_ARGS_LOG="$matrix_log" \
TITAN_CPU_SCOPE=0 \
  bash "$matrix_repository/scripts/build-matrix.sh" --parallel 3 \
    sdk-host-debug sdk-host-release sdk-desktop-debug sdk-desktop-profile sdk-desktop-release
assert_log_contains "$matrix_log" '--mode debug --out-name sdk_host_debug --ninja-target flutter/build/archives:artifacts'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:flutter_patched_sdk'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:dart_sdk_archive'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:embedder'
assert_log_contains "$matrix_log" '--ninja-target flutter/tools/font_subset'
assert_log_contains "$matrix_log" '--ninja-target flutter/impeller/toolkit/interop:sdk'
assert_log_contains "$matrix_log" '--mode release --out-name sdk_host_release --ninja-target flutter/build/archives:flutter_patched_sdk'
assert_log_contains "$matrix_log" '--mode debug --gtk-shell --enable-fontconfig --out-name sdk_desktop_debug'
assert_log_contains "$matrix_log" '--mode profile --gtk-shell --enable-fontconfig --out-name sdk_desktop_profile'
assert_log_contains "$matrix_log" '--mode release --gtk-shell --enable-fontconfig --out-name sdk_desktop_release'

matrix_log="$temporary_directory/all-linux-modes.log"
matrix_variants=(
  x64-debug x64-musl-debug arm64-debug arm64-musl-debug arm-hard-debug
  arm-hard-musl-debug arm-softfp-debug arm-softfp-musl-debug
  riscv64-glibc-debug riscv64-musl-debug
  x64-profile x64-musl-profile arm64-profile arm64-musl-profile arm-hard-profile
  arm-hard-musl-profile arm-softfp-profile arm-softfp-musl-profile
  riscv64-glibc-profile riscv64-musl-profile
  x64-release x64-musl-release arm64-release arm64-musl-release arm-hard-release
  arm-hard-musl-release arm-softfp-release arm-softfp-musl-release
  riscv64-glibc-release riscv64-musl-release
)
TITAN_WORK_DIR="$temporary_directory/all-linux-modes-work" \
TITAN_MATRIX_ARGS_LOG="$matrix_log" \
TITAN_CPU_SCOPE=0 \
  bash "$matrix_repository/scripts/build-matrix.sh" --parallel 3 "${matrix_variants[@]}"
[[ "$(wc -l < "$matrix_log")" -eq 30 ]] || {
  printf 'expected 30 Linux target variants\n' >&2
  exit 1
}
[[ "$(grep -c -- '--mode debug ' "$matrix_log")" -eq 10 ]] || {
  printf 'expected 10 Linux debug variants\n' >&2
  exit 1
}
[[ "$(grep -c -- '--mode profile ' "$matrix_log")" -eq 10 ]] || {
  printf 'expected 10 Linux profile variants\n' >&2
  exit 1
}
[[ "$(grep -c -- '--mode release ' "$matrix_log")" -eq 10 ]] || {
  printf 'expected 10 Linux release variants\n' >&2
  exit 1
}
assert_log_contains "$matrix_log" '--mode profile --cpu arm --arm-float-abi softfp --libc musl --target-sysroot '
assert_log_contains "$matrix_log" '--mode release --cpu riscv64 --libc musl --target-sysroot '

matrix_log="$temporary_directory/desktop-matrix.log"
desktop_variants=(
  sdk-desktop-debug sdk-desktop-profile sdk-desktop-release
  sdk-desktop-x64-musl-debug sdk-desktop-x64-musl-profile sdk-desktop-x64-musl-release
  sdk-desktop-arm64-debug sdk-desktop-arm64-profile sdk-desktop-arm64-release
  sdk-desktop-arm64-musl-debug sdk-desktop-arm64-musl-profile sdk-desktop-arm64-musl-release
  sdk-desktop-arm-hard-debug sdk-desktop-arm-hard-profile sdk-desktop-arm-hard-release
  sdk-desktop-arm-hard-musl-debug sdk-desktop-arm-hard-musl-profile sdk-desktop-arm-hard-musl-release
  sdk-desktop-arm-softfp-debug sdk-desktop-arm-softfp-profile sdk-desktop-arm-softfp-release
  sdk-desktop-arm-softfp-musl-debug sdk-desktop-arm-softfp-musl-profile sdk-desktop-arm-softfp-musl-release
  sdk-desktop-riscv64-glibc-debug sdk-desktop-riscv64-glibc-profile sdk-desktop-riscv64-glibc-release
  sdk-desktop-riscv64-musl-debug sdk-desktop-riscv64-musl-profile sdk-desktop-riscv64-musl-release
)
TITAN_WORK_DIR="$temporary_directory/desktop-matrix-work" \
TITAN_MATRIX_ARGS_LOG="$matrix_log" \
TITAN_CPU_SCOPE=0 \
  bash "$matrix_repository/scripts/build-matrix.sh" --parallel 3 "${desktop_variants[@]}"
[[ "$(wc -l < "$matrix_log")" -eq 30 ]] || {
  printf 'expected 30 GTK desktop variants\n' >&2
  exit 1
}
assert_log_contains "$matrix_log" '--mode profile --gtk-shell --enable-fontconfig --cpu arm64 --target-sysroot '
assert_log_contains "$matrix_log" '--mode release --gtk-shell --enable-fontconfig --cpu riscv64 --libc musl --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --gtk-shell --enable-fontconfig --cpu arm64 --target-sysroot '
assert_log_contains "$matrix_log" '--out-name sdk_desktop_arm64_debug'

matrix_log="$temporary_directory/arm64-host-matrix.log"
TITAN_WORK_DIR="$temporary_directory/arm64-host-matrix-work" \
TITAN_MATRIX_ARGS_LOG="$matrix_log" \
TITAN_CPU_SCOPE=0 \
  bash "$matrix_repository/scripts/build-matrix.sh" --parallel 1 sdk-host-arm64-debug
assert_log_contains "$matrix_log" '--mode debug --cpu arm64 --out-name sdk_host_arm64_debug --ninja-target flutter/build/archives:artifacts'
assert_log_contains "$matrix_log" '--ninja-target flutter/tools/font_subset'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:embedder'
assert_log_contains "$matrix_log" '--ninja-target flutter/impeller/toolkit/interop:sdk'
assert_log_contains "$matrix_log" '--ninja-target flutter/build/archives:dart_sdk_archive'

matrix_log="$temporary_directory/platform-matrix.log"
matrix_variants=(
  x64-debug
  x64-musl-debug
  arm64-debug
  arm64-musl-debug
  arm-hard-debug
  arm-hard-musl-debug
  arm-softfp-debug
  arm-softfp-musl-debug
  riscv32-glibc-debug
  riscv32-musl-debug
  riscv64-glibc-debug
  riscv64-musl-debug
)
TITAN_WORK_DIR="$temporary_directory/platform-matrix-work" \
TITAN_MATRIX_ARGS_LOG="$matrix_log" \
TITAN_CPU_SCOPE=0 \
  bash "$matrix_repository/scripts/build-matrix.sh" --parallel 3 "${matrix_variants[@]}"
assert_log_contains "$matrix_log" '--mode debug --cpu x64 --libc musl --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --cpu arm64 --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --cpu arm64 --libc musl --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --cpu arm --arm-float-abi hard --libc musl --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --cpu riscv32 --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --cpu riscv32 --libc musl --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --cpu riscv64 --target-sysroot '
assert_log_contains "$matrix_log" '--mode debug --cpu riscv64 --libc musl --target-sysroot '

matrix_scope_log="$temporary_directory/matrix-scope.log"
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
TITAN_WORK_DIR="$temporary_directory/scoped-matrix-work" \
TITAN_MATRIX_ARGS_LOG="$temporary_directory/scoped-matrix.log" \
TITAN_SYSTEMD_RUN_LOG="$matrix_scope_log" \
PATH="$fake_bin:$PATH" \
  bash "$matrix_repository/scripts/build-matrix.sh" --parallel 2 x64-debug sdk-host-debug
[[ "$(grep -c 'CPUQuota=' "$matrix_scope_log")" -eq 1 ]] || {
  printf 'expected one matrix CPU scope\n' >&2
  cat "$matrix_scope_log" >&2
  exit 1
}

assemble_script="$repository_root/scripts/assemble-sdk-artifacts.sh"
artifact_fixture="$temporary_directory/artifact-fixture"
artifact_output="$temporary_directory/artifact-output"
mkdir -p "$artifact_fixture/flutter/engine/src"
ln -s "$artifact_fixture/out" "$artifact_fixture/flutter/engine/src/out"
mkdir -p "$artifact_fixture/out/sdk_host_debug/zip_archives/linux-x64" \
  "$artifact_fixture/out/sdk_host_release/zip_archives" \
  "$artifact_fixture/out/sdk_desktop_debug/zip_archives/linux-x64-debug" \
  "$artifact_fixture/out/sdk_desktop_profile/zip_archives/linux-x64-profile" \
  "$artifact_fixture/out/sdk_desktop_release/zip_archives/linux-x64-release"

artifact_paths=(
  linux-x64/artifacts.zip
  flutter_patched_sdk.zip
  dart-sdk-linux-x64.zip
  linux-x64/font-subset.zip
  linux-x64/linux-x64-embedder.zip
  linux-x64/impeller_sdk.zip
  flutter_patched_sdk_product.zip
  linux-x64-debug/linux-x64-flutter-gtk.zip
  linux-x64-profile/linux-x64-flutter-gtk.zip
  linux-x64-release/linux-x64-flutter-gtk.zip
  sky_engine.zip
  flutter_gpu.zip
)
for artifact_path in "${artifact_paths[@]}"; do
  case "$artifact_path" in
    linux-x64-debug/*) source_root="$artifact_fixture/out/sdk_desktop_debug/zip_archives" ;;
    linux-x64-profile/*) source_root="$artifact_fixture/out/sdk_desktop_profile/zip_archives" ;;
    linux-x64-release/*) source_root="$artifact_fixture/out/sdk_desktop_release/zip_archives" ;;
    flutter_patched_sdk_product.zip) source_root="$artifact_fixture/out/sdk_host_release/zip_archives" ;;
    *) source_root="$artifact_fixture/out/sdk_host_debug/zip_archives" ;;
  esac
  mkdir -p "$source_root/$(dirname "$artifact_path")"
  printf 'fixture:%s\n' "$artifact_path" > "$source_root/$artifact_path"
done
# The engine stamp reads the Flutter checkout's revision.
git -C "$artifact_fixture/flutter" init -q
git -C "$artifact_fixture/flutter" -c user.name=test -c user.email=test@example.invalid \
  commit -q --allow-empty -m fixture

TITAN_WORK_DIR="$artifact_fixture" \
TITAN_BUNDLE_DIR="$temporary_directory/default-bundle" \
  bash "$assemble_script" --hash test-hash --out "$artifact_output" \
  || {
    printf 'assemble-sdk-artifacts.sh failed unexpectedly\n' >&2
    exit 1
  }
grep -q '"content_hash":"test-hash"' \
  "$artifact_output/flutter_infra_release/flutter/test-hash/engine_stamp.json" || {
    printf 'engine_stamp.json does not carry the content hash\n' >&2
    exit 1
  }
for artifact_path in "${artifact_paths[@]}"; do
  [[ -f "$artifact_output/flutter_infra_release/flutter/test-hash/$artifact_path" ]] || {
    printf 'missing assembled artifact: %s\n' "$artifact_path" >&2
    exit 1
  }
done
manifest="$artifact_output/MANIFEST"
# The zips plus engine_stamp.json.
[[ "$(awk 'END { print NR }' "$manifest")" -eq $(( ${#artifact_paths[@]} + 1 )) ]] || {
  printf 'unexpected MANIFEST entry count\n' >&2
  exit 1
}
while IFS=$'\t' read -r path size checksum; do
  [[ -n "$path" && "$size" =~ ^[0-9]+$ && "$checksum" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'invalid MANIFEST row: %s\n' "$path" >&2
    exit 1
  }
done < "$manifest"

rm "$artifact_fixture/out/sdk_host_debug/zip_archives/linux-x64/artifacts.zip"
if TITAN_WORK_DIR="$artifact_fixture" \
  TITAN_BUNDLE_DIR="$temporary_directory/default-bundle" \
  bash "$assemble_script" --hash missing-artifact --out "$temporary_directory/missing-output"; then
  printf 'assemble-sdk-artifacts.sh accepted a missing required artifact\n' >&2
  exit 1
fi

printf 'test_build_engine_args.sh: ok\n'
