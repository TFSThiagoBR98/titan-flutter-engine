# Runtime SPI S5.5e — Diagnóstico com símbolos e codec sem handle intermediário

**Data:** 2026-10-29

**Binários:** `s4f-cbase`, `s4g3-base` e `develop` (fim da S5.5d) refeitos em
profile com símbolos (`exe.unstripped/shell_benchmarks`), a partir dos mesmos
commits das bases da S4f e da S4g-3. Os A/B foram intercalados em 10 rodadas.
As medidas absolutas variam entre sessões; compare só dentro do mesmo A/B.

## Relógio e instruções contra as bases

| Benchmark | Base | `develop` | Δ relógio | Δ instruções (callgrind) |
|---|---:|---:|---:|---:|
| `BM_DartParagraphFrame` (`s4f-cbase`) | 3593 µs | 3801 µs | +5,8% | +1,3% |
| `BM_DartCompositeFrame` (`s4f-cbase`) | 519 µs | 546 µs | +5,2% | +1,9% |
| `BM_DartCodecFrame` (`s4g3-base`) | 429 µs | 446 µs | +4,0% | +3,4% |

## Onde fica a diferença

| Medida (cachegrind, `BM_DartParagraphFrame`) | `s4f-cbase` | `develop` | Δ |
|---|---:|---:|---:|
| Instruções | 3,171 G | 3,202 G | +1,0% |
| Misses de I1 | 54,2 M | 61,4 M | **+13,3%** |
| Misses de D1 | 31,1 M | 32,8 M | +5,5% |
| Taxa de erro de desvio | 4,6% | 4,6% | = |

- Trocas de contexto iguais nos três benchmarks (sem salto de thread extra);
  o tempo de CPU de usuário sobe junto com o relógio.
- Texto: `layout` e `paint` executam as mesmas instruções dos dois lados, o
  que descarta a hipótese do `impeller_enabled` da S5.5c. A diferença é pressão
  de cache de instruções espalhada (VM do Dart, Skia, código AOT); o maior bloco
  próprio do SPI, `pushStyle` + `ToTxtTextStyle`, soma ≈ 1 M dos 7,2 M de misses
  extras.
- Composto: buscas de handle ≈ 0,8% e mutex de `Insert`/`Release` das tabelas
  ≈ 0,24% das instruções.
- Codecs: ≈ 2,5 pontos dos 3,4 estão na VM do Dart. As chamadas de
  `Type::Canonicalize` são as mesmas (17.788), mas cada busca na tabela de tipos
  canônicos custa ≈ 3,5× mais com o snapshot de `dart:ui` maior. O handle
  intermediário entre `SpiImageDecoding` e `SpiImageCodec` era < 1 ponto.

## Codec sem handle intermediário

| Benchmark | `develop` | S5.5e | Δ |
|---|---:|---:|---:|
| `BM_DartCodecFrame` | 448 µs | 448 µs | neutro |
| `BM_DartCompositeFrame` | 539 µs | 536 µs | ruído |

A mudança fica pelo código mais simples (sem `new` por decode nem ida e volta
pelo handle C); o ganho (≈ 1 µs por decode) fica abaixo do ruído.
