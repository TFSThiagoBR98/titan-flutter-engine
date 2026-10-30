# Runtime SPI S7b — Shaders, pipelines e binding sets do flutter_gpu

**Data:** 2026-10-30

## Testes no check

| Execução | Resultado |
|---|---|
| testes movidos do `gpu_unittests` para o `runtime_spi_unittests` (shader library 8, pipeline 1, binding set 7) | 16 PASS, mesmos nomes |
| testes novos da tabela (bibliotecas, pipelines, binding sets, ABI) | 25 PASS |
| `gpu_unittests` restantes (command buffer, render pass) | 7 PASS |
| `gpu_test.dart`, Impeller em Vulkan com `--enable-flutter-gpu` | +104 ~1 |
| `gpu_test.dart`, Impeller em Vulkan sem Flutter GPU | +5 ~100 |

Total do check: 1503 PASS, 0 FAIL (1478 da S7a + 25), série de 165 patches.

## Benchmark

`BM_DartGpuFrame`, A/B intercalado em 10 rodadas contra `flutter_tester.s70-base`:

| Build | Mediana das medianas |
|---|---:|
| base da S7 (`s70-base`) | 429 µs |
| S7b | 435 µs |

+1,4%, dentro do portão (base + 2×CV; o CV da base nesta rodada é ≈2%). As
diferenças por rodada trocam de sinal (de −17 a +19 µs). O quadro medido usa um
pipeline já criado; a criação de pipeline e o registro de shaders, que mudaram
de lugar, ficam fora do laço medido.

## Checkpoint em cópia limpa

Série de 165 patches aplicada do zero (`patches_sha256` `407256e0…`):

| Passo | Resultado |
|---|---|
| build x64 + probe | `9afdbcd18abd9b35` |
| build arm64-musl + probe | `9afdbcd18abd9b35` |
| `abi_layout_check.c` em ARM 32-bit (hard float) | ok |
| GN nas 10 variantes | ok |
| check do runtime SPI | 1503 PASS, 0 FAIL |
