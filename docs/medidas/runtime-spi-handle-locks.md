# Runtime SPI — Medição das tabelas de handles com trava

**Data:** 2026-10-18

**Benchmarks:** `BM_DartCompositeFrame`, `BM_DartSceneBuildFrame`,
`BM_DartPathBuildFrame`, `BM_DartCanvasRecordFrame` e
`BM_DartParagraphFrame`. `locks-base` é a S4f integrada sem a trava; `locks-new`
é a mesma série com os testes de concorrência e o `std::mutex` por tabela. Os
binários e os assets usados no A/B estão em `.build_flutter/bench/`.

O portão do mutex compara o quadro composto com a S4f integrada e aceita no
máximo 1,5% de regressão. Os isolados e o custo acumulado contra a base
original da S4f são registrados para localizar o custo.

| Benchmark | sem trava (`locks-base`) | com trava (`locks-new`) | Δ |
|---|---:|---:|---:|
| `BM_DartCompositeFrame` | 531 µs | 550 µs | **+3,6%** (portão +1,5%) |
| `BM_DartSceneBuildFrame` | 1021 µs | 1133 µs | +11,0% |
| `BM_DartPathBuildFrame` | 968 µs | 1053 µs | +8,8% |
| `BM_DartCanvasRecordFrame` | 471 µs | 510 µs | +8,3% |
| `BM_DartParagraphFrame` | 3724 µs | 3815 µs | +2,4% |

O quadro composto da S4f já estava em +5,5% contra a base original. Com a
trava, a medição do composto ficou em 550 µs contra 508 µs da base original,
ou **+8,3% acumulado**. O resultado do portão do próprio mutex, portanto, foi
uma regressão de +3,6% contra a S4f integrada.

## Causa

O custo aparece mesmo sem disputa: cada operação de desenho faz várias buscas
de handles, incluindo recorder, paint e path, e cada `FindRaw` agora adquire e
libera o mutex da tabela. O custo adicional cresce nos benchmarks que fazem
mais chamadas do SPI; por isso a cena, o path e o canvas isolados sobem mais
que o parágrafo.

Dividir as tabelas em fatias (*shards*) não resolve esta causa. A divisão
reduziria a disputa entre threads, mas não o custo da trava sem disputa em
cada lookup.

## Decisão

O usuário decidiu integrar a trava como está, porque ela corrige uma corrida
real entre engines e finalizadores do GC, e otimizar na S5.5. A S5.5 deve
reduzir o número de chamadas do SPI depois que o gargalo for identificado de
forma definitiva. O portão de +1,5% não foi atingido, mas não haverá uma
segunda implementação de sincronização nesta fase.

## Candidata para a S5.5

A candidata registrada é fazer a leitura sem trava: `FindRaw` usaria uma
geração atômica e entradas em blocos fixos que não se movem, enquanto o mutex
permaneceria apenas em `Insert` e `Release`. A proposta mantém a ABI e precisa
ser validada contra a propriedade do objeto, a reutilização de gerações e a
destruição reentrante antes de substituir a implementação atual.

Atualização (2026-10-29): a S5.5a tirou a trava da busca; ver
[runtime-spi-s55a.md](runtime-spi-s55a.md).
