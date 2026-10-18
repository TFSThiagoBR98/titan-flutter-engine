# Runtime SPI S4d-2 — Medição do portão

**Data:** 2026-10-18

**Benchmarks:** `BM_DartPathBuildFrame` e `BM_DartCanvasRecordFrame`, executados
em `out/host_profile`. O critério da fase é uma regressão de no máximo 5%
contra a linha de base. As medições foram feitas em A/B com o kernel produzido
pelo build de cada binário.

## Antes da Task 5b

Esta foi a medição que motivou a otimização da Task 5b. O `SpiPath` guardava
um `SkPath` imutável e construía um `SkPathBuilder` a partir do path inteiro em
cada mutação; `SkPathBuilder::SkPathBuilder(const SkPath&)` respondia por 17%
do benchmark no callgrind. O resultado da construção de paths ficou 46% acima
da base.

| Benchmark | Base (µs) | S4d-2 antes da Task 5b (µs) | Delta |
|---|---:|---:|---:|
| `BM_DartPathBuildFrame` | 957–1042 | 1401–1454 | +46% ❌ |

## Depois da Task 5b

O `SpiPath` passou a manter um `SkPathBuilder` e a gerar snapshots somente
para leituras. A tabela registra cinco rodadas, cada uma com a mediana de três
repetições.

| Benchmark | Base (µs, rodadas) | S4d-2 (µs, rodadas) | Média base | Média S4d-2 | Delta |
|---|---|---|---:|---:|---:|
| `BM_DartPathBuildFrame` | 1000, 1009, 1021, 992, 1033 | 1009, 980, 1013, 1009, 1016 | 1011 | 1005 | −0,6% ✅ |
| `BM_DartCanvasRecordFrame` | 474, 480, 486, 485, 480 | 478, 472, 474, 487, 479 | 481 | 478 | −0,6% ✅ |

O portão de desempenho foi aprovado: as duas médias ficaram dentro do limite
de regressão de 5%. O bruto da segunda medição está em
`.build_flutter/bench/s4d2-ab2.txt`.

## Método

Cada binário foi executado com a cópia correspondente do diretório `assets`,
que contém o kernel do fixture usado pelo `ui_benchmarks`. O A/B final foi
intercalado em cinco rodadas, com o host sem carga e os sysroots suspensos.
