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
| `0005-glib-api-level.patch` | Fixa o nível de API do GLib em 2.56 no shell GTK: o GLib 2.86 dos sysroots do Buildroot inclui `<type_traits>` nos headers C quando a API é 2.68+, e o shell inclui o GLib dentro de `extern "C"`. | Shell GTK com GLib ≥ 2.68 (sysroots do Buildroot) |
