# Runtime SPI S7-0 — Linha de base do flutter_gpu

**Data:** 2026-10-29

## Testes no check

| Execução | Resultado |
|---|---|
| `gpu_unittests` (mocks do Impeller) | 23 PASS |
| `gpu_test.dart`, Impeller em Vulkan com `--enable-flutter-gpu` | +104 ~1 |
| `gpu_test.dart`, Impeller em Vulkan sem Flutter GPU | +5 ~100 |

O Vulkan é o SwiftShader estático do `flutter_tester` (CPU). Total do check:
1456 PASS, 0 FAIL.

## Benchmark

`testing/dart/gpu_frame_benchmark.dart` (`BM_DartGpuFrame`): por quadro, uma
textura de render 256×256, um `HostBuffer` com vértices e UBO, um command
buffer, um render pass de uma cor e `draw(3)`, esperando a conclusão do
`submit`; 50 quadros de aquecimento e 500 medidos.

| Build | Mediana | p90 |
|---|---:|---:|
| base da S7 (`flutter_tester.s70-base`) | 440 µs | ≈ 830 µs |

Três execuções seguidas: 439, 440 e 441 µs de mediana. As medidas absolutas
variam entre sessões; o portão da S7 é um A/B intercalado contra este binário.
