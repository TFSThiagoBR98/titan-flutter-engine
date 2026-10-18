# Runtime SPI S4f — Medição do portão de texto

**Data:** 2026-10-18

**Benchmarks:** `BM_DartParagraphFrame`, no `shell_benchmarks`, e
`BM_DartCompositeFrame`, no mesmo alvo. Os binários foram executados de
dentro de `out/host_profile`. As comparações foram A/B intercaladas, usando o
kernel e os assets do próprio binário. O critério do portão é uma regressão de
no máximo 5% no quadro realista; o usuário aceitou o resultado composto de
uma rodada final em 2026-10-18.

| Medição | `BM_DartParagraphFrame` base × S4f | Cena | Path | Canvas | Causa da rodada |
|---|---:|---:|---:|---:|---|
| Task 5 (`new`) | 3529 × 3905 µs (+10,7%) | +1,7% | +1,3% | 0% | Primeira migração do texto para o SPI, antes das otimizações específicas do portão. |
| Task 5b (`new2`) | 3529 × 3833 µs (+8,7%) | +1,0% | +0,2% | −1,7% | As consultas de listas faziam duas chamadas: uma para contar e outra para preencher, recalculando o parágrafo. |
| Task 5c (`new3`) | 3559 × 3864 µs (+8,6%) | +1,6% | −0,9% | −0,4% | O SPI fixava `impeller_enabled` em `false`. Era um bug de correção; o ajuste não mudou o tempo porque o benchmark roda com Skia. |
| Task 5d (`new4`) | 3518 × 3756 µs (+6,8%) | +1,7% | +1,7% | −2,3% | `addText` convertia UTF-16 para UTF-8 e o core convertia de volta; além disso, a tabela de texto era resolvida a cada chamada. |
| Task 5e (`new5`) | 3530 × 3696 µs (+4,7%) ✅ | +1,6% | +1,3% | −1,3% | A reticência passava por `wstring_convert` de UTF-16 para UTF-8 e de volta; `ellipsis_utf16` elimina esse ciclo. |

O A/B final do texto isolado, em dez rodadas, registrou os seguintes
resultados no bruto `.build_flutter/bench/s4f-text-ab.txt`:

| Medição | Base | S4f | Variação |
|---|---:|---:|---:|
| Texto isolado (`new5`) | 3536 µs | 3709 µs | +4,9% |
| Texto isolado (`new6`) | 3536 µs | 3746 µs | +5,9% |

O benchmark composto da Task 1c mistura, em cada quadro, grupos de cena
retida, clips, opacidade, pictures com fundo, ícone e formas, além de
parágrafos curtos e de um parágrafo maior com métricas de linha. No bruto
`.build_flutter/bench/s4f-comp-ab.txt`, o A/B de dez rodadas foi:

| Medição | Base (µs) | S4f (µs) | Variação |
|---|---:|---:|---:|
| `BM_DartCompositeFrame` | 508 (507, 507, 505, 509, 499, 509, 518, 509, 508, 509) | 536 (532, 537, 528, 542, 524, 532, 537, 545, 528, 551) | +5,5% |
| `BM_DartParagraphFrame` | 3556 | 3742 | +5,2% |

O portão composto foi aceito e integrado pelo usuário em 2026-10-18. O
custo restante é o fixo por chamada do SPI, aproximadamente 130 ns e cerca
de nove chamadas para um parágrafo curto; reduzir a quantidade de chamadas,
por exemplo enviando um span inteiro em uma chamada, fica para a S5.5.

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
- O benchmark de texto precisa ser lido junto com o benchmark composto: o
  A/B isolado oscila entre +4,9% e +5,9%, enquanto o quadro composto aceito
  ficou em +5,5%.
- O branch temporário da base deve conter somente os commits do benchmark; a
  base do texto isolado e a do quadro composto não devem ser inferidas de um
  binário já exportado com uma série diferente de patches.

O `tools/ci.sh` já fixa o EGL da Mesa (`with_software_gl`); o `BadAlloc` do
NVIDIA só aparece ao rodar o binário de teste à mão, sem esse ambiente.

Os brutos das medições estão em `.build_flutter/bench/s4f-ab6.txt`,
`.build_flutter/bench/s4f-text-ab.txt` e
`.build_flutter/bench/s4f-comp-ab.txt`.
