# Runtime SPI S4f — Medição do portão de texto

**Data:** 2026-10-18

**Benchmark:** `BM_DartParagraphFrame`, no `shell_benchmarks`, executado de
dentro de `out/host_profile`. A comparação foi A/B intercalada, com cinco
rodadas, cada uma usando o kernel e os assets do próprio binário. O critério
do portão é uma regressão de no máximo 5% no quadro realista.

| Medição | `BM_DartParagraphFrame` base × S4f | Cena | Path | Canvas | Causa da rodada |
|---|---:|---:|---:|---:|---|
| Task 5 (`new`) | 3529 × 3905 µs (+10,7%) | +1,7% | +1,3% | 0% | Primeira migração do texto para o SPI, antes das otimizações específicas do portão. |
| Task 5b (`new2`) | 3529 × 3833 µs (+8,7%) | +1,0% | +0,2% | −1,7% | As consultas de listas faziam duas chamadas: uma para contar e outra para preencher, recalculando o parágrafo. |
| Task 5c (`new3`) | 3559 × 3864 µs (+8,6%) | +1,6% | −0,9% | −0,4% | O SPI fixava `impeller_enabled` em `false`. Era um bug de correção; o ajuste não mudou o tempo porque o benchmark roda com Skia. |
| Task 5d (`new4`) | 3518 × 3756 µs (+6,8%) | +1,7% | +1,7% | −2,3% | `addText` convertia UTF-16 para UTF-8 e o core convertia de volta; além disso, a tabela de texto era resolvida a cada chamada. |
| Task 5e (`new5`) | 3530 × 3696 µs (+4,7%) ✅ | +1,6% | +1,3% | −1,3% | A reticência passava por `wstring_convert` de UTF-16 para UTF-8 e de volta; `ellipsis_utf16` elimina esse ciclo. |

As cinco medições mostram a redução de 10,7% para 4,7% no benchmark de
parágrafos. O portão foi aprovado, com margem pequena; os demais benchmarks
permaneceram dentro do limite em todas as rodadas.

## Lições de medição

- O benchmark de texto precisa de um Shell real e, portanto, vive no alvo
  `shell_benchmarks`; o fixture isolado de `ui_benchmarks` não fornece o
  `PlatformConfiguration` necessário ao `ParagraphBuilder`.
- Os binários devem rodar de dentro de `out/host_profile`, para resolver o
  SwiftShader pelo `$ORIGIN` e manter o ambiente do benchmark igual entre os
  lados do A/B.
- A base é montada em um branch temporário do worktree do engine, a partir do
  commit anterior à S4f, recebendo somente os commits do benchmark. O A/B deve
  restaurar os assets correspondentes a cada binário.
- `build-engine.sh` não desfaz uma série de patches maior. Para comparar a
  base, é preciso trocar explicitamente para o branch temporário, exportar e
  construir a série correspondente antes de voltar ao branch da feature.

O bruto da medição final está em `.build_flutter/bench/s4f-ab6.txt`.
