# RISC-V Linux

Habilita os alvos RISC-V no wrapper GN do Flutter e fixa as combinações de
ISA/ABI usadas pelo TitanDM.

| Patch | Por quê | Plataformas afetadas |
|---|---|---|
| `0001-riscv-tools-gn.patch` | Aceita `riscv32`/`riscv64`, mantém `dart_target_arch` correspondente, usa host x64 para `riscv64` e host x86 para o `gen_snapshot` de `riscv32`. | riscv32 e riscv64 Linux |
| `0002-riscv-isa-flags.patch` | Explicita `rv32gc`/`ilp32d` e `rv64gc`/`lp64d` quando o Clang não os deriva da tripla. | riscv32 e riscv64 Linux |
