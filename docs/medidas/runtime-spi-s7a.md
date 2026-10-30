# Runtime SPI S7a — Contexto, buffers e texturas do flutter_gpu

**Data:** 2026-10-30

## Testes no check

| Execução | Resultado |
|---|---|
| testes novos em `runtime_spi_unittests` (contexto, buffers, texturas, ABI) | 22 PASS |
| `gpu_unittests` | 23 PASS |
| `gpu_test.dart`, Impeller em Vulkan com `--enable-flutter-gpu` | +104 ~1 |
| `gpu_test.dart`, Impeller em Vulkan sem Flutter GPU | +5 ~100 |

Total do check: 1478 PASS, 0 FAIL (1456 da S7-0 + 22), série de 161 patches.

## Benchmark

`BM_DartGpuFrame` (o mesmo quadro da [S7-0](runtime-spi-s70.md)), A/B
intercalado em 10 rodadas contra `flutter_tester.s70-base`, cada rodada com 500
quadros medidos:

| Build | Mediana das medianas |
|---|---:|
| base da S7 (`s70-base`) | 474 µs |
| S7a | 456 µs |

As diferenças por rodada trocam de sinal (de −35 a +24 µs): sem regressão além
do ruído. O caminho medido ainda passa pelo Impeller direto em pipeline, command
buffer e render pass; só a criação de recursos e as escritas passam pela tabela.

## Checkpoint em cópia limpa

Série de 161 patches aplicada do zero sobre o checkout do engine
(`patches_sha256` `6dc980cd…`):

| Passo | Resultado |
|---|---|
| build x64 + probe | `9afdbcd18abd9b35` |
| build arm64-musl + probe | `9afdbcd18abd9b35` |
| `abi_layout_check.c` em ARM 32-bit (hard float) | ok, depois do patch 0161 |
| GN nas 10 variantes (x64, arm64, arm hard/softfp, riscv64 × glibc/musl) | ok |
| check do runtime SPI | 1478 PASS, 0 FAIL |

A primeira rodada falhou no ARM 32-bit: o `FlutterSpiEngineApi` tem 176 bytes
lá (o ponteiro `gpu` ocupou o preenchimento de cauda) e o
`FlutterSpiGpuBufferDescriptor` tem 12, não 180 e 16 como os testes congelavam.
