# Plataformas

Matriz oficial dos alvos Linux do `titan-flutter-engine`. Cada alvo é CPU × ABI de ponto flutuante (só ARM) × libc;
como cada um é escolhido e compilado está em [cross-compilacao.md](cross-compilacao.md).

| Alvo | Tripla do Clang | Sysroot (`--target-sysroot` / padrão) | Defconfig Buildroot | Runtime do compilador | Dart SDK do build | Estado |
|---|---|---|---|---|---|---|
| x86_64 glibc | padrão do Flutter | Debian do Chromium | — | compiler-rt embutido | prebuilt | compilado; bundle do TitanDM |
| x86_64 musl | `x86_64-linux-musl` | `titan_x64_musl` | `titan_x64_musl_defconfig` | GCC do sysroot | do fonte | pendente: ferramentas de host linkadas no musl (E2e) |
| arm64 glibc | `aarch64-linux-gnu` | `titan_arm64_glibc` | `titan_arm64_glibc_defconfig` | compiler-rt embutido | prebuilt | compilado + QEMU |
| arm64 musl | `aarch64-linux-musl` | `titan_arm64_musl` | `titan_arm64_musl_defconfig` | GCC do sysroot | do fonte | compilado + QEMU |
| armv7-a hard glibc | `arm-linux-gnueabihf` (link `armv7-unknown-linux-gnueabihf`) | `titan_armv7a_hf` | `titan_armv7a_hf_glibc_defconfig` | compiler-rt embutido | prebuilt | compilado + QEMU |
| armv7-a hard musl | `arm-linux-musleabihf` | `titan_armv7a_hf_musl` | `titan_armv7a_hf_musl_defconfig` | GCC do sysroot | do fonte | compilado + QEMU |
| armv7-a softfp glibc | `arm-linux-gnueabi` | `titan_armv7a_softfp` | `titan_armv7a_softfp_glibc_defconfig` | GCC do sysroot | prebuilt | compilado + QEMU |
| armv7-a softfp musl | `arm-linux-musleabi` | `titan_armv7a_softfp_musl` | `titan_armv7a_softfp_musl_defconfig` | GCC do sysroot | do fonte | compilado + QEMU |
| riscv32 glibc | `riscv32-linux-gnu` | `titan_riscv32_glibc` | `titan_riscv32_glibc_defconfig` | GCC do sysroot | do fonte | pendente: `assert` do marl no GN (E2e) |
| riscv32 musl | `riscv32-linux-musl` | `titan_riscv32_musl` | `titan_riscv32_musl_defconfig` | GCC do sysroot | do fonte | pendente: `assert` do marl no GN (E2e) |
| riscv64 glibc | `riscv64-linux-gnu` | `titan_riscv64_glibc` | `titan_riscv64_glibc_defconfig` | compiler-rt embutido | prebuilt | compilado + QEMU |
| riscv64 musl | `riscv64-linux-musl` | `titan_riscv64_musl` | `titan_riscv64_musl_defconfig` | GCC do sysroot | do fonte | compilado + QEMU |

- **Dart SDK do build:** "prebuilt" usa o Dart SDK que o Flutter publica para o host; "do fonte" marca os alvos sem
  prebuilt equivalente, que compilarão o Dart SDK (`--no-prebuilt-dart-sdk`) quando chegarem à matriz. Os alvos musl
  já compilados ainda usam o prebuilt de host, que basta para o bundle do engine.
- **armv6j** (base do Debian armel) está fora: o Dart VM só suporta ARMv7+ (`SIGILL` no QEMU com `arm1176`).
- **glibc:** os sysroots usam a glibc 2.42 do Buildroot, e os bundles pedem `GLIBC_2.38` no aparelho; alvos com glibc
  ou kernel antigos usam musl.

## Verificação da fase F2.5-M1

Build completo da matriz debug (2026-10-15, `build-matrix.sh`, orçamento de 8 núcleos): nove alvos compilam e dão o
mesmo quadro no probe do QEMU (`b49a7f31cecb7983`, app spike do TitanDM) — x64 glibc, arm64 glibc e musl, armv7-a
hard glibc e musl, softfp glibc e musl, riscv64 glibc e musl. Tempos de build a frio, dois alvos por vez: arm64 ≈ 36
min, armv7-a hard musl ≈ 34 min, riscv64 ≈ 52–56 min. Pendentes: `x64-musl-debug` (o `host_toolchain` é o do alvo, e
o `flatc` sai linkado no musl) e os dois riscv32 (`assert` do marl, do SwiftShader, no GN).

## Medição do build paralelo (2026-10-15)

`scripts/build-matrix.sh --parallel 4` com as quatro variantes debug compiladas (x64, armv7-a hard, softfp e softfp
musl), em 16 núcleos e 46 GB, sem LTO e com o ccache frio para as flags novas: **56 min 46 s** no total
(≈ 850% de CPU em média). O probe do QEMU deu o mesmo quadro (`b49a7f31cecb7983`) nos três alvos ARM.
