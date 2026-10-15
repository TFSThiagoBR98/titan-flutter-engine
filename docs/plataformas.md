# Plataformas

Matriz oficial dos alvos Linux do `titan-flutter-engine`. Cada alvo é CPU × ABI de ponto flutuante (só ARM) × libc;
como cada um é escolhido e compilado está em [cross-compilacao.md](cross-compilacao.md).

| Alvo | Tripla do Clang | Sysroot (`--target-sysroot` / padrão) | Defconfig Buildroot | Runtime do compilador | Dart SDK do build | Estado |
|---|---|---|---|---|---|---|
| x86_64 glibc | padrão do Flutter | Debian do Chromium | — | compiler-rt embutido | prebuilt | compilado; bundle do TitanDM |
| x86_64 musl | `x86_64-linux-musl` | `titan_x64_musl` | `titan_x64_musl_defconfig` | GCC do sysroot | do fonte | pendente: `usr/lib/gcc/` do sysroot |
| arm64 glibc | `aarch64-linux-gnu` | `titan_arm64_glibc` | `titan_arm64_glibc_defconfig` | compiler-rt embutido | prebuilt | pendente: `usr/lib/gcc/` do sysroot |
| arm64 musl | `aarch64-linux-musl` | `titan_arm64_musl` | `titan_arm64_musl_defconfig` | GCC do sysroot | do fonte | pendente: `usr/lib/gcc/` do sysroot |
| armv7-a hard glibc | `arm-linux-gnueabihf` (link `armv7-unknown-linux-gnueabihf`) | `titan_armv7a_hf` | `titan_armv7a_hf_glibc_defconfig` | compiler-rt embutido | prebuilt | compilado + QEMU |
| armv7-a hard musl | `arm-linux-musleabihf` | `titan_armv7a_hf_musl` | `titan_armv7a_hf_musl_defconfig` | GCC do sysroot | do fonte | pendente: `usr/lib/gcc/` do sysroot |
| armv7-a softfp glibc | `arm-linux-gnueabi` | `titan_armv7a_softfp` | `titan_armv7a_softfp_glibc_defconfig` | GCC do sysroot | prebuilt | compilado + QEMU |
| armv7-a softfp musl | `arm-linux-musleabi` | `titan_armv7a_softfp_musl` | `titan_armv7a_softfp_musl_defconfig` | GCC do sysroot | do fonte | compilado + QEMU |
| riscv32 glibc | `riscv32-linux-gnu` | `titan_riscv32_glibc` | `titan_riscv32_glibc_defconfig` | GCC do sysroot | do fonte | pendente: `usr/lib/gcc/` do sysroot; GN implementado |
| riscv32 musl | `riscv32-linux-musl` | `titan_riscv32_musl` | `titan_riscv32_musl_defconfig` | GCC do sysroot | do fonte | pendente: `usr/lib/gcc/` do sysroot; GN implementado |
| riscv64 glibc | `riscv64-linux-gnu` | `titan_riscv64_glibc` | `titan_riscv64_glibc_defconfig` | compiler-rt embutido | prebuilt | pendente: `usr/lib/gcc/` do sysroot |
| riscv64 musl | `riscv64-linux-musl` | `titan_riscv64_musl` | `titan_riscv64_musl_defconfig` | GCC do sysroot | do fonte | pendente: `usr/lib/gcc/` do sysroot |

- **Dart SDK do build:** "prebuilt" usa o Dart SDK que o Flutter publica para o host; "do fonte" marca os alvos sem
  prebuilt equivalente, que compilarão o Dart SDK (`--no-prebuilt-dart-sdk`) quando chegarem à matriz. Os alvos musl
  já compilados ainda usam o prebuilt de host, que basta para o bundle do engine.
- **armv6j** (base do Debian armel) está fora: o Dart VM só suporta ARMv7+ (`SIGILL` no QEMU com `arm1176`).
- **glibc:** os sysroots usam a glibc 2.42 do Buildroot, e os bundles pedem `GLIBC_2.38` no aparelho; alvos com glibc
  ou kernel antigos usam musl.

## Verificação da fase F2.5-M1

O `--gn-only` passou em `x64-debug`, `arm-hard-debug`, `arm-softfp-debug` e `arm-softfp-musl-debug`. As outras oito
variantes ficam pendentes até que o Buildroot termine os respectivos sysroots: o diretório existir não basta; é preciso
que apareça `usr/lib/gcc/<tripla>/`. Isso é uma pendência de ambiente, não uma falha do GN. A compilação completa da
matriz e os probes no QEMU são verificação posterior no host.

## Medição do build paralelo (2026-10-15)

`scripts/build-matrix.sh --parallel 4` com as quatro variantes debug compiladas (x64, armv7-a hard, softfp e softfp
musl), em 16 núcleos e 46 GB, sem LTO e com o ccache frio para as flags novas: **56 min 46 s** no total
(≈ 850% de CPU em média). O probe do QEMU deu o mesmo quadro (`b49a7f31cecb7983`) nos três alvos ARM.
