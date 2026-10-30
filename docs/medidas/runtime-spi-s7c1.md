# Runtime SPI S7c-1 — Command buffers, render passes e surfaces do flutter_gpu

**Data:** 2026-10-30

## Testes no check

| Execução | Resultado |
|---|---|
| testes movidos do `gpu_unittests` (command buffer 3, render pass 4) | 7 PASS, mesmos nomes; o `gpu_unittests` saiu |
| testes novos da tabela (command buffers, render passes, surfaces, ABI) | 19 PASS |
| `gpu_test.dart`, Impeller em Vulkan com `--enable-flutter-gpu` | +104 ~1 |
| `gpu_test.dart`, Impeller em Vulkan sem Flutter GPU | +5 ~100 |

Total do check: 1522 PASS, 0 FAIL (1503 da S7b + 19), série de 171 patches.

## Benchmark

`BM_DartGpuFrame`, A/B intercalado em 10 rodadas contra `flutter_tester.s70-base`.
É a primeira medida em que o quadro inteiro (command buffer, render pass, binds
e draw) passa pela tabela:

| Build | Mediana das medianas |
|---|---:|
| base da S7 (`s70-base`) | 487 µs |
| S7c-1 | 488 µs |

A máquina estava mais ruidosa que nas medidas anteriores (CV da base ≈ 5%), mas o
A/B intercalado compara as duas no mesmo intervalo: sem diferença.

## Checkpoint em cópia limpa

Série de 171 patches aplicada do zero (`patches_sha256` `d6f31c15…`). Primeiro
checkpoint com o build **completo** em ARM 32-bit, no lugar do alvo de ABI só:

| Passo | Resultado |
|---|---|
| build x64 + probe | `9afdbcd18abd9b35` |
| build arm64-musl + probe | `9afdbcd18abd9b35` |
| build completo ARM 32-bit (hard float) | ok |
| GN nas 10 variantes | ok |
| check do runtime SPI | 1522 PASS, 0 FAIL |
