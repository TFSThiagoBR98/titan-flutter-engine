# Runtime SPI S5.5a — Medição das buscas de handles sem trava

**Data:** 2026-10-29

**Benchmarks:** `BM_DartCompositeFrame` e `BM_DartParagraphFrame`. O A/B foi
intercalado em 10 rodadas, com mediana das medianas. `s55-base` é o `develop`
no fim da S5c; `s55a-new` contém a busca de handles sem trava e a conversão de
paints no próprio cache. Os binários e os assets usados estão em
`.build_flutter/bench/` (`shell_benchmarks.s55-base`,
`shell_benchmarks.s55a-new`).

| Benchmark | `s55-base` | `s55a-new` | Δ |
|---|---:|---:|---:|
| `BM_DartCompositeFrame` | 604 µs | 594 µs | **−1,7%** |
| `BM_DartParagraphFrame` | 4042 µs | 4013 µs | −0,7% |

Os benchmarks isolados de cena, path e canvas ficam no `ui_benchmarks` e não
foram remedidos; o quadro composto inclui as três coisas.
