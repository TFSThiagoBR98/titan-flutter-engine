# Runtime SPI S5.5c — Medidas de texto e codecs

**Data:** 2026-10-29

**Benchmarks:** `BM_DartParagraphFrame`, `BM_DartCompositeFrame` e
`BM_DartCodecFrame`. Os A/B foram intercalados em 10 rodadas. As medidas
absolutas variam entre sessões; compare só dentro do mesmo A/B.

## Texto

| Benchmark | `s4f-cbase` | S5.5c | Δ |
|---|---:|---:|---:|
| `BM_DartParagraphFrame` | 3674 µs | 3861 µs | +5,1% |
| `BM_DartCompositeFrame` | 533 µs | 576 µs | +8,1% |

## Codecs

| Benchmark | `s4g3-base` | S5.5c | Δ |
|---|---:|---:|---:|
| `BM_DartCodecFrame` | 450 µs | 476 µs | +5,8% |

## Perfil do texto

| Função | % no `lib/ui` | % dentro do SPI |
|---|---:|---:|
| `layout` | 24,18% | 24,17% |
| `paint` | 19,59% | 19,56% |
| `computeLineMetrics` | 15,03% | 14,31% |
| `addText` | 5,16% | 4,60% |
| `pushStyle` | 5,03% | 4,75% |
| `getPositionForOffset` | 4,51% | 0,67% |

O restante é `ToDart` de um `std::vector`, como no upstream. No texto, a
camada SPI custa ≤ 1% do quadro; nos codecs, não sobrou salto de tarefa extra.
Decisão: sem mudança de código.
