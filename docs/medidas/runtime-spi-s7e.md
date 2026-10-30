# Runtime SPI S7e — Triângulo em C pela tabela de GPU

**Data:** 2026-10-30

## Teste

`flutter_engine_core_gpu_triangle` (C11, só `libflutter_engine_core.so`), Impeller em
Vulkan sobre o lavapipe (`VK_DRIVER_FILES=/usr/share/vulkan/icd.d/lvp_icd.json`):

| Passo | Resultado |
|---|---|
| contexto, biblioteca de shaders, pipeline, textura, buffer, command buffer, render pass | pela `FlutterSpiGpuApi` |
| `texture_as_image` + `image_to_bytes` (RGBA) | pixel (32,32) = (255,0,0,255); pixel (1,1) = (0,0,0,0) |
| bibliotecas do engine linkadas (`readelf`) | só `libflutter_engine_core.so` |
| linha do check | `core gpu triangle: ok` |

Total do check: 1530 PASS, 0 FAIL, série de 175 patches. A fase só acrescenta um
teste, sem código de runtime: o A/B do `BM_DartGpuFrame` não se aplica.

## Checkpoint em cópia limpa

Série de 175 patches aplicada do zero (`patches_sha256` `5eadad74…`):

| Passo | Resultado |
|---|---|
| build x64 + probe | `9afdbcd18abd9b35` |
| build arm64-musl + probe | `9afdbcd18abd9b35` |
| build completo ARM 32-bit (hard float) | ok |
| GN nas 10 variantes | ok |
| check do runtime SPI | 1530 PASS, 0 FAIL, `core gpu triangle: ok` |

## A S7 inteira

| Subfase | O que passou pela tabela | ABI | `BM_DartGpuFrame` (S7 / base) |
|---|---|---|---|
| S7-0 | linha de base (testes e benchmark) | 0.24 | 440 µs (base) |
| S7a | contexto, buffers, texturas | 0.25 | 456 / 474 µs |
| S7b | shaders, pipelines, binding sets | 0.26 | 435 / 429 µs |
| S7c-1 | command buffers, render passes, surfaces | 0.27 | 488 / 487 µs |
| S7d | travessia textura ↔ imagem; `lib/gpu` sem Impeller | 0.28 | 457 / 451 µs |
| S7e | triângulo em C | 0.28 | — |
