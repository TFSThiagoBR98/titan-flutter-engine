# Runtime SPI S4d-1 — Medição do portão

**Data:** 2026-10-17

**Benchmark:** `BM_DartCanvasRecordFrame`, executado em `out/host_profile`,
com dez repetições e unidade em microssegundos. O critério da fase é uma
regressão de no máximo 5% contra a gravação direta pelo
`DisplayListBuilder`.

## Resultados

Os valores abaixo são os resultados consolidados das medições registradas na
série. A base foi observada em duas sessões sem carga, na faixa de 524–527 µs.
As faixas e medianas são mantidas como medidas reportadas; não são reconstruídas
rodadas que não ficaram registradas.

| Medição | Resultado (µs) | Comparação registrada |
|---|---:|---|
| Base, caminho direto | 524–527 | Referência |
| Task 4, troca para o SPI | 642 | Acima do limite de 5% |
| t8, handles por slot e geração | 631 | Acima do limite de 5% |
| t9, cache do último paint convertido | 622 | +18% |
| t11, argumentos escalares do paint | 476–497; mediana 487 | −7,6% |

O resultado final do t11 ficou dentro do portão de desempenho. A medição da
Task 10 não entra na tabela: seus natives leaf foram abandonados porque a VM
não executou as chamadas, sem resolução de símbolo nem exceção.

## Perfil callgrind do t9

| Região do caminho | Participação |
|---|---:|
| `ToSpiPaint` | 27,6% |
| `DartByteData` dentro de `ToSpiPaint` | 22,5% |
| Camada SPI | aproximadamente 11% |

O perfil motivou a troca da Task 11: os nove argumentos escalares carregam os
bytes do paint sem a aquisição de `DartByteData` a cada draw, mas continuam no
caminho native não-leaf.

## Nota de método

O benchmark lê o kernel dos fixtures em `out/host_profile`. Portanto, um A/B
que muda o Dart precisa preservar o kernel produzido por cada binário. A base
e o t9 abortaram quando foram executados com o kernel novo. A comparação do
t11 usou a base medida sem carga em duas sessões anteriores; ela é registrada
como evidência do portão, mas não como uma rodada intercalada nova entre os
dois binários.

## Verificação

O check final da série confirmou **1320 PASS** e **0 FAIL**. A fase preserva o
comportamento do caminho Dart; a validação completa de probe, arquiteturas,
`engine.lock` e `tools/ci.sh engine` fica no checkpoint executado pelo Claude
em uma cópia limpa da série.

## Benchmarks do shell (pendência da S4c-2)

`shell_benchmarks` em `out/host_debug`, 10 repetições, host sem carga, comparado com a medição da S4b. O estado medido
já inclui a S4c-2 e a S4d-1. Uma primeira rodada logo depois do build deu valores altos (até +75%); as duas rodadas
seguintes, com CV abaixo de 2%, dão:

| Benchmark | S4b | S4d-1 (2 rodadas) | Diferença |
|---|---|---|---|
| `BM_ShellInitialization` | 227,2 µs | 233,5 / 230,2 µs | +1,3% a +2,8% |
| `DartNativeBenchmarks/MultipleDartToNativeMessages` | 33,37 ms | 35,01 / 34,86 ms | +4,5% |
| `DartNativeBenchmarks/TimeToFirstNativeMessageFromIsolateInNewVM` | 33,17 ms | 34,76 / 34,79 ms | +4,8% |

As diferenças ficam dentro da variação entre sessões registrada na S4b (cerca de 10%), e os dois benchmarks de isolate
não executam código do SPI (criam um isolate direto, sem `Shell` nem `Engine`). Sem regressão atribuível; o A/B
controlado continua na S5.5.
