# Runtime do compilador Linux

Seleciona o runtime GCC do sysroot quando o compiler-rt/libunwind do Clang
embutido não cobre a combinação do alvo.

| Patch | Por quê | Plataformas afetadas |
|---|---|---|
| `0001-gcc-runtime.patch` | Usa `libgcc`, `libgcc_eh` e `-static-libgcc` no alvo para manter o runtime compatível com o sysroot. | Todos os alvos musl, ARM soft/softfp e riscv32; demais alvos continuam com libunwind |
