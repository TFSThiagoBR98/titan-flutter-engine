# Runtime SPI S2 — Resultado do Checkpoint

**Data:** 2026-10-16
**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a série de patches do `runtime-spi` e as correções da revisão da S2.
**Build:** x64 glibc e arm64-musl sob QEMU; alvos GN cruzados e layout de 32 bits verificados.

Este relatório registra o resultado do checkpoint da S2. O caminho Dart não
muda nesta fase; o probe continua sendo o oráculo de comportamento do engine.

## Aplicação da série

A série de 27 patches do repositório do Flutter aplicou em um worktree limpo
do commit fixado de `flutter.lock`: 11 patches de `runtime-spi` e as correções
registradas no plano `2026-10-16-runtime-spi-s2-review-fixes.md`.

## Checker e gtests

`check-runtime-spi.sh` passou nas duas configurações, com e sem testes, com
**1051 PASS** e **0 FAIL**. O resultado reúne os 1019 testes da S1 e os 32
testes do Runtime SPI da S2:

| Grupo | Testes |
|---|---:|
| `SpiAbi` | 12 |
| `SpiRuntimeBackendTest` | 8 |
| `SpiConformance` | 12 |
| **Total novo da S2** | **32** |

Os alvos sem Dart continuam passando pelo `check_no_dart_deps.py` nos dois
modos de configuração.

## Probe e matriz de alvos

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. O `--gn-only` passou nos 10 alvos previstos; riscv32
foi excluído da matriz por decisão registrada em 2026-10-16.

O build cruzado arm-hard (32 bits) compilou `runtime_spi_c_api`. O
`abi_layout_check.c` confirmou os offsets da ABI com ponteiros de 4 bytes e o
alinhamento em 8 bytes dos campos de 64 bits.

## CI

`tools/ci.sh engine` passou.

Os achados do checkpoint foram corrigidos no plano
`2026-10-16-runtime-spi-s2-review-fixes.md`: os alvos de teste passaram a ser
habilitados apenas com `enable_unittests`, e as expectativas do layout de 32
bits passaram a considerar o alinhamento real dos campos de 64 bits.
