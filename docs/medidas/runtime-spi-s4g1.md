# Runtime SPI S4g-1 — Medição do portão de efeitos

**Data:** 2026-10-18

**Benchmarks:** `BM_DartEffectsFrame`, `BM_DartCompositeFrame`,
`BM_DartParagraphFrame`, `BM_DartSceneBuildFrame`, `BM_DartPathBuildFrame` e
`BM_DartCanvasRecordFrame`. O A/B foi intercalado em cinco rodadas, com a
mediana de três repetições por rodada. O bruto está em
`.build_flutter/bench/s4g1-ab.txt`.

O critério do portão é uma regressão de no máximo 5% no benchmark de efeitos.

| Benchmark | antes | S4g-1 | Δ |
|---|---:|---:|---:|
| `BM_DartEffectsFrame` (portão, base da Task 1) | 391 µs | 398 µs | **+1,8% ✅** |
| `BM_DartCompositeFrame` (contra o `develop`, `locks-new`) | 564 | 563 | −0,2% |
| `BM_DartParagraphFrame` (contra o `develop`) | 3888 | 3818 | −1,8% |
| `BM_DartSceneBuildFrame` | 1187 | 1183 | −0,3% |
| `BM_DartPathBuildFrame` | 1071 | 1054 | −1,6% |
| `BM_DartCanvasRecordFrame` | 512 | 503 | −1,8% |

O portão foi aprovado: o benchmark de efeitos ficou 1,8% acima da base, dentro
do limite de 5%.
