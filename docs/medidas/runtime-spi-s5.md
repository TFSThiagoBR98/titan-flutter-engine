# Runtime SPI S5 — Medição dos artefatos do core

**Data:** 2026-10-29

**Build:** x64 glibc debug em `out/host_debug`.

## Tamanho dos artefatos

| Artefato | text (bytes) | data (bytes) | bss (bytes) | Tamanho (bytes) |
|---|---:|---:|---:|---:|
| `libflutter_engine.so` | 42 744 678 | 601 776 | 99 520 | 43 349 456 |
| `libflutter_engine_core.so` | 13 037 668 | 293 464 | 64 088 | 13 334 152 |

O `libflutter_engine_core.so` tem **−69%** do tamanho do
`libflutter_engine.so` nessa configuração.

O build `build-engine.sh --runtime none` gera o mesmo
`libflutter_engine_core.so`, com **13 334 152 bytes**, e não gera
`libflutter_engine.so`. O build padrão usa `--runtime dart`; a configuração
sem Dart é ativada pelo argumento GN `titan_flutter_runtime_dart=false`.

## Dependências e provas

Os dois artefatos dependem somente de `libdl`, `libm`, `libpthread`, `libc` e
`ld-linux`. O `check-core-artifact.sh` confirma o conjunto de dependências, a
lista de símbolos exportados e a ausência de símbolos Dart no artefato não
despojado; termina com `core artifact: ok` para o core. O
`test_check_core_artifact.sh` também o executa contra o
`libflutter_engine.so` e exige que esse teste negativo falhe.

O `flutter_engine_core_smoke` é um programa C linkado somente ao
`libflutter_engine_core.so` e ao runtime C de teste. Ele apresenta um quadro
em software através da host API e termina com `core smoke: ok`, provando que o
core executa o Runtime SPI sem Dart.

As medidas de profile/release e dos outros alvos ficam para a S6.
