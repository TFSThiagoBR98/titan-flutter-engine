#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

work_root="$temporary_directory/work"
bundle_root="$temporary_directory/bundles"
fake_bin="$temporary_directory/bin"
probe_log="$temporary_directory/probe.log"
clang_log="$temporary_directory/clang.log"
qemu_log="$temporary_directory/qemu.log"
assets="$temporary_directory/assets"

mkdir -p \
  "$work_root/flutter/engine/src/flutter/buildtools/linux-x64/clang/bin" \
  "$work_root/sysroots" "$bundle_root" "$fake_bin" "$assets"

cat > "$work_root/flutter/engine/src/flutter/buildtools/linux-x64/clang/bin/clang" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_CLANG_LOG"
output=
previous=
for argument in "$@"; do
  if [[ "$previous" == -o ]]; then
    output=$argument
  fi
  previous=$argument
done
[[ -n "$output" ]] || exit 1
cat > "$output" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
printf 'frame 320x240 hash=0123456789abcdef\nok\n'
PROBE
chmod +x "$output"
EOF
chmod +x "$work_root/flutter/engine/src/flutter/buildtools/linux-x64/clang/bin/clang"

cat > "$fake_bin/qemu-fake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$TITAN_QEMU_LOG"
while (($# > 0)); do
  case "$1" in
    -cpu|-L) shift 2 ;;
    *) break ;;
  esac
done
exec "$@"
EOF
chmod +x "$fake_bin/qemu-fake"
for qemu in qemu-x86_64-static qemu-aarch64-static qemu-arm-static qemu-riscv32-static qemu-riscv64-static; do
  ln -s qemu-fake "$fake_bin/$qemu"
done

flutter_commit=$(sed -n 's/^flutter_commit=//p' "$repository_root/flutter.lock")
target_fixtures=(
  "x64-debug||$flutter_commit"
  "x64-musl-debug|titan_x64_musl|$flutter_commit-debug-x64-musl"
  "arm64-debug|titan_arm64_glibc|$flutter_commit-debug-arm64"
  "arm64-musl-debug|titan_arm64_musl|$flutter_commit-debug-arm64-musl"
  "arm-hard-debug|titan_armv7a_hf|$flutter_commit-debug-arm-hard"
  "arm-hard-musl-debug|titan_armv7a_hf_musl|$flutter_commit-debug-arm-hard-musl"
  "arm-softfp-debug|titan_armv7a_softfp|$flutter_commit-debug-arm-softfp"
  "arm-softfp-musl-debug|titan_armv7a_softfp_musl|$flutter_commit-debug-arm-softfp-musl"
  "riscv32-glibc-debug|titan_riscv32_glibc|$flutter_commit-debug-riscv32"
  "riscv32-musl-debug|titan_riscv32_musl|$flutter_commit-debug-riscv32-musl"
  "riscv64-glibc-debug|titan_riscv64_glibc|$flutter_commit-debug-riscv64"
  "riscv64-musl-debug|titan_riscv64_musl|$flutter_commit-debug-riscv64-musl"
)
for fixture in "${target_fixtures[@]}"; do
  IFS='|' read -r variant sysroot bundle <<<"$fixture"
  if [[ -n "$sysroot" ]]; then
    mkdir -p "$work_root/sysroots/$sysroot"
  fi
  mkdir -p "$bundle_root/$bundle"
  : > "$bundle_root/$bundle/libflutter_engine.so"
  : > "$bundle_root/$bundle/icudtl.dat"
done

run_probe() {
  TITAN_WORK_DIR="$work_root" \
  TITAN_BUNDLE_DIR="$bundle_root" \
  TITAN_CLANG_LOG="$clang_log" \
  TITAN_QEMU_LOG="$qemu_log" \
  PATH="$fake_bin:$PATH" \
    "$repository_root/scripts/qemu-probe.sh" "$@"
}

if run_probe --target arm64-debug --assets "$assets" > "$temporary_directory/missing-stamp.log" 2>&1; then
  printf 'qemu-probe accepted a sysroot without a stamp\n' >&2
  exit 1
fi
grep -Fq 'incomplete or outdated' "$temporary_directory/missing-stamp.log"
find "$work_root/sysroots" -mindepth 1 -maxdepth 1 -type d -exec sh -c \
  'printf "%s\n" fixture-key > "$1/.titan-sysroot-key"' _ {} \;

run_probe --target x64-debug --assets "$assets" > "$probe_log"
grep -Fq 'frame 320x240 hash=0123456789abcdef' "$probe_log"
grep -Fq -- '--target=x86_64-unknown-linux-gnu' "$clang_log"

run_probe --abi x64 --assets "$assets" > "$probe_log"
grep -Fq 'frame 320x240 hash=0123456789abcdef' "$probe_log"

run_probe --target arm64-debug --assets "$assets" > "$probe_log"
grep -Fq -- '--target=aarch64-linux-gnu' "$clang_log"
grep -Fq -- '-cpu cortex-a53' "$qemu_log"
grep -Fq -- '-L ' "$qemu_log"

run_probe --target arm-hard-debug --assets "$assets" > "$probe_log"
grep -Fq -- '--target=armv7-unknown-linux-gnueabihf' "$clang_log"
grep -Fq -- '-mfloat-abi=hard' "$clang_log"
grep -Fq -- '-cpu cortex-a8' "$qemu_log"

run_probe --target arm-softfp-debug --assets "$assets" > "$probe_log"
grep -Fq -- '--target=arm-linux-gnueabi' "$clang_log"
grep -Fq -- '-mfloat-abi=softfp' "$clang_log"
grep -Fq -- '--rtlib=libgcc --unwindlib=libgcc -static-libgcc' "$clang_log"

run_probe --target riscv32-glibc-debug --assets "$assets" > "$probe_log"
grep -Fq -- '--target=riscv32-linux-gnu' "$clang_log"
grep -Fq -- '-march=rv32gc -mabi=ilp32d' "$clang_log"
grep -Fq -- '-cpu rv32' "$qemu_log"

run_probe --target riscv64-glibc-debug --assets "$assets" > "$probe_log"
grep -Fq -- '--target=riscv64-linux-gnu' "$clang_log"
grep -Fq -- '-march=rv64gc -mabi=lp64d' "$clang_log"
grep -Fq -- '-cpu rv64' "$qemu_log"

ci_repository="$temporary_directory/ci-repository"
mkdir -p "$ci_repository/scripts/lib" "$ci_repository/tests/qemu"
printf '0123456789abcdef\n' > "$ci_repository/tests/qemu/expected-frame-hash"
cp "$repository_root/scripts/ci.sh" "$ci_repository/scripts/ci.sh"
cp "$repository_root/scripts/lib/paths.sh" "$ci_repository/scripts/lib/paths.sh"
cat > "$ci_repository/scripts/build-probe-app.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$TITAN_WORK_DIR/probe-app/flutter_assets"
EOF
chmod +x "$ci_repository/scripts/build-probe-app.sh"
cat > "$ci_repository/scripts/qemu-probe.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

target=
while (($# > 0)); do
  case "$1" in
    --target) target=$2; shift 2 ;;
    --target=*) target=${1#*=}; shift ;;
    --assets) shift 2 ;;
    *) printf 'unexpected argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done
printf '%s\n' "$target" >> "$TITAN_PROBE_SELECTION_LOG"
printf 'frame 320x240 hash=0123456789abcdef\nok\n'
EOF
chmod +x "$ci_repository/scripts/qemu-probe.sh"

selection_log="$temporary_directory/selection.log"
TITAN_WORK_DIR="$temporary_directory/ci-work" \
TITAN_BUNDLE_DIR="$bundle_root" \
TITAN_VARIANTS='x64-debug arm64-debug' \
TITAN_PROBE_SELECTION_LOG="$selection_log" \
  bash "$ci_repository/scripts/ci.sh" probe > "$probe_log"
[[ "$(wc -l < "$selection_log")" -eq 2 ]]
grep -Fxq x64-debug "$selection_log"
grep -Fxq arm64-debug "$selection_log"

printf 'fedcba9876543210\n' > "$ci_repository/tests/qemu/expected-frame-hash"
if TITAN_WORK_DIR="$temporary_directory/ci-work" \
  TITAN_BUNDLE_DIR="$bundle_root" \
  TITAN_VARIANTS='x64-debug' \
  TITAN_PROBE_SELECTION_LOG="$selection_log" \
  bash "$ci_repository/scripts/ci.sh" probe > "$probe_log" 2>&1; then
  printf 'ci.sh probe accepted a frame hash that differs from tests/qemu/expected-frame-hash\n' >&2
  exit 1
fi

printf 'test_qemu_probe_args.sh: ok\n'
