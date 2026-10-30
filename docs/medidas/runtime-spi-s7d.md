# Runtime SPI S7d — Travessia textura ↔ imagem e lib/gpu sem Impeller

**Data:** 2026-10-30

## Testes no check

| Execução | Resultado |
|---|---|
| testes novos da tabela (travessia, descritor, imagem da surface, shader sujo) | 8 PASS |
| `gpu_test.dart`, Impeller em Vulkan com `--enable-flutter-gpu` | +104 ~1 |
| `gpu_test.dart`, Impeller em Vulkan sem Flutter GPU | +5 ~100 |

Total do check: 1530 PASS, 0 FAIL (1522 da S7c-1 + 8), série de 174 patches.

`git grep -n '#include "impeller\|impeller::\|runtime_spi/gpu/\|runtime_spi/internal/' -- lib/gpu ':!lib/gpu/lib'`
não encontra nada.

## Benchmark

`BM_DartGpuFrame`, A/B intercalado em 10 rodadas contra `flutter_tester.s70-base`:

| Build | Mediana das medianas |
|---|---:|
| base da S7 (`s70-base`) | 451 µs |
| S7d | 457 µs |

+1,3%, dentro do portão (base + 2×CV; CV da base nesta rodada 1,3%); diferenças por
rodada de −9 a +20 µs.

## Checkpoint em cópia limpa

Série de 174 patches aplicada do zero (`patches_sha256` `15fc1606…`):

| Passo | Resultado |
|---|---|
| build x64 + probe | `9afdbcd18abd9b35` |
| build arm64-musl + probe | `9afdbcd18abd9b35` |
| build completo ARM 32-bit (hard float) | ok |
| GN nas 10 variantes | ok |
| check do runtime SPI | 1530 PASS, 0 FAIL |
