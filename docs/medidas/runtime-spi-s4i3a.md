# Runtime SPI S4i-3a — Medição do portão dos tipos e alvos do `dart:ui`

**Data:** 2026-10-28

**Benchmarks:** `BM_DartCompositeFrame` e `BM_DartParagraphFrame`. A base foi
`shell_benchmarks.s4i2-new`. A implementação e a base foram comparadas em
A/B intercalado em dez rodadas. Os valores abaixo são as medianas das rodadas.
Os brutos estão em `.build_flutter/bench/s4i3a-ab.txt`.

O critério do portão é uma regressão de no máximo 2%.

| Benchmark | antes | S4i-3a | Δ |
|---|---:|---:|---:|
| `BM_DartCompositeFrame` | 596 µs | 585 µs | **−1,8% ✅** |
| `BM_DartParagraphFrame` | 3942 µs | 3915 µs | **−0,7%** |

O portão foi aprovado: o quadro composto ficou 1,8% abaixo da base e o
benchmark de parágrafos ficou 0,7% abaixo. Ambos permanecem dentro do limite
de regressão de 2%.
