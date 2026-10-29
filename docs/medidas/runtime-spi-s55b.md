# Runtime SPI S5.5b — Medição da semântica sem nó temporário

**Data:** 2026-10-29

**Benchmarks:** `BM_DartSemanticsFrame` e `BM_DartCompositeFrame`. O A/B foi
intercalado em 10 rodadas, com `s55a-new` (develop no fim da S5.5a)
contra `s55b-new`.

| Benchmark | `s55a-new` | `s55b-new` | Δ |
|---|---:|---:|---:|
| `BM_DartSemanticsFrame` | 601 µs | 582 µs | **−3,2%** |
| `BM_DartCompositeFrame` | 580 µs | 581 µs | +0,2% (ruído) |

Nota: as medidas absolutas variam entre sessões; compare só dentro do mesmo
A/B.
