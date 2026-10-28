# Runtime SPI S4i-1 — Medição do portão do acessor da ABI

**Data:** 2026-10-28

**Benchmarks:** `BM_DartCompositeFrame`, `BM_DartParagraphFrame` e
`BM_DartSemanticsFrame`. A base da Task 1 foi o `develop` da S4h-2. A
implementação e a base foram comparadas em A/B intercalado em dez rodadas. Os
valores abaixo são as medianas das rodadas. Os brutos estão em
`.build_flutter/bench/s4i1-ab.txt`.

O critério do portão é uma regressão de no máximo 2%.

| Benchmark | antes | S4i-1 | Δ |
|---|---:|---:|---:|
| `BM_DartCompositeFrame` | 563 µs | 564 µs | **+0,2% ✅** |
| `BM_DartParagraphFrame` | 3805 µs | 3825 µs | +0,5% |
| `BM_DartSemanticsFrame` | 587 µs | 580 µs | −1,2% |

O portão foi aprovado: o quadro composto ficou 0,2% acima da base, abaixo do
limite de 2%; o benchmark de parágrafos ficou 0,5% acima e o de semântica,
1,2% abaixo.
