# Runtime SPI S4g-2 — Medição do portão de imagens

**Data:** 2026-10-18

**Benchmarks:** `BM_DartImageFrame`, `BM_DartCompositeFrame`,
`BM_DartParagraphFrame`, `BM_DartEffectsFrame`, `BM_DartSceneBuildFrame`,
`BM_DartPathBuildFrame` e `BM_DartCanvasRecordFrame`. O A/B do benchmark de
imagens foi intercalado em dez rodadas; os indicadores foram comparados com o
branch `develop` em cinco rodadas. Os brutos estão em
`.build_flutter/bench/s4g2-img-ab.txt` e `.build_flutter/bench/s4g2-ab.txt`.

O critério do portão é uma regressão de no máximo 5% no benchmark de imagens.

| Benchmark | antes | S4g-2 | Δ |
|---|---:|---:|---:|
| `BM_DartImageFrame` (portão, base da Task 1) | 100,4 µs | 100,5 µs | **+0,1% ✅** |
| `BM_DartCompositeFrame` (contra o `develop`) | 555 | 567 | +2,2% |
| `BM_DartParagraphFrame` (contra o `develop`) | 3812 | 3872 | +1,6% |
| `BM_DartEffectsFrame` (contra o `develop`) | 405 | 404 | −0,2% |
| `BM_DartSceneBuildFrame` (contra o `develop`) | 1186 | 1221 | +2,9% |
| `BM_DartPathBuildFrame` (contra o `develop`) | 1063 | 1072 | +0,8% |
| `BM_DartCanvasRecordFrame` (contra o `develop`) | 503 | 507 | +0,8% |

O portão foi aprovado: o benchmark de imagens ficou 0,1% acima da base,
dentro do limite de 5%. A fixture usa `Picture.toImageSync` para funcionar no
Shell Skia e manter o caminho síncrono da fase.
