# Matriz de alvos Linux

Centraliza a seleção GN da libc, dos sysroots padrão e das triplas de
compilação. A série é aplicada a todos os builds; cada alteração é limitada ao
toolchain do alvo quando necessário.

| Patch | Por quê | Plataformas afetadas |
|---|---|---|
| `0001-target-libc-args.patch` | Declara `titan_target_libc` com padrão glibc e valida glibc/musl. | Todos os builds GN Linux |
| `0002-target-sysroots.patch` | Seleciona o sysroot padrão por CPU, libc e ABI, preservando `target_sysroot` explícito. | x64, arm64, armv7-a hard/softfp, riscv32 e riscv64; glibc/musl |
| `0003-clang-triples.patch` | Passa a tripla correta ao compilador e ao linker do alvo. | x64, arm64, armv7-a hard/softfp, riscv32 e riscv64; glibc/musl |
| `0004-x64-musl-host-toolchain.patch` | Mantém as ferramentas de host no toolchain glibc quando o alvo x64 usa musl. | x64 musl |
