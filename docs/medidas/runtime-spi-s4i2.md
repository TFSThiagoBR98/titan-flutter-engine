# Runtime SPI S4i-2 — Medição do portão das pontes C++ do `dart:ui`

**Data:** 2026-10-28

**Benchmarks:** `BM_DartCompositeFrame`, `BM_DartImageFrame` e
`BM_DartParagraphFrame`. A base foi `shell_benchmarks.s4i1-new`. A
implementação e a base foram comparadas em A/B intercalado em dez rodadas. Os
valores abaixo são as medianas das rodadas. Os brutos estão em
`.build_flutter/bench/s4i2-ab.txt`.

O critério do portão é uma regressão de no máximo 2%.

| Benchmark | antes | S4i-2 | Δ |
|---|---:|---:|---:|
| `BM_DartCompositeFrame` | 556 µs | 567 µs | **+2,0% ✅** |
| `BM_DartImageFrame` | 98,7 µs | 98,8 µs | +0,1% |
| `BM_DartParagraphFrame` | 3830 µs | 3843 µs | +0,3% |

O portão foi aprovado: o quadro composto ficou 2,0% acima da base, exatamente
no limite de 2%; o benchmark de imagens ficou 0,1% acima e o de parágrafos,
0,3% acima.

A rodada 7 da base do quadro composto mediu 841 µs por carga da máquina; por
isso, a mediana foi usada. O novo quadro composto ficou acima da base em oito
das dez rodadas, cerca de 10 µs. A hipótese registrada para a S5.5 é o custo de
`path_set_volatile` público, que busca o handle na construção de
`CanvasPath`.
