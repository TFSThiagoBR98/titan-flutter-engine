# RISC-V Linux

Habilita os alvos RISC-V no wrapper GN do Flutter e fixa as combinações de
ISA/ABI usadas pelo TitanDM.

| Patch | Por quê | Plataformas afetadas |
|---|---|---|
| `0001-riscv-tools-gn.patch` | Aceita `riscv32`/`riscv64`, mantém `dart_target_arch` correspondente, usa host x64 para `riscv64` e host x86 para o `gen_snapshot` de `riscv32`. | riscv32 e riscv64 Linux |
| `0002-riscv-isa-flags.patch` | Explicita `rv32gc`/`ilp32d` e `rv64gc`/`lp64d` quando o Clang não os deriva da tripla. | riscv32 e riscv64 Linux |
| `0003-swiftshader-marl-riscv32-ucontext.patch` | Usa o caminho genérico `ucontext` do Marl, porque o SwiftShader não tem fibras em assembly para riscv32. | riscv32 Linux |
| `0004-swiftshader-llvm-riscv32.patch` | Seleciona as fontes LLVM de RISC-V do SwiftShader para riscv32 e riscv64. | riscv32 Linux |
| `0005-flutter-analyze-snapshot-riscv32.patch` | Mantém `analyze_snapshot` apenas nos alvos Linux de 64 bits, que são os suportados pelo Dart. | riscv32 Linux |
