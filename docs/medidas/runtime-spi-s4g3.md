# Runtime SPI S4g-3 — Medição do portão de codecs

**Data:** 2026-10-27

**Benchmarks:** `BM_DartCodecFrame` foi o portão, com A/B intercalado em dez
rodadas contra a base da Task 1. `BM_DartImageFrame`,
`BM_DartCompositeFrame` e `BM_DartParagraphFrame` foram comparados com o
branch `develop` em cinco rodadas. Os brutos estão em
`.build_flutter/bench/s4g3-codec-ab.txt` e `.build_flutter/bench/s4g3-ab.txt`.
Os valores abaixo são as medianas das rodadas.

O critério do portão é uma regressão de no máximo 5% no benchmark de codecs.

| Benchmark | antes | S4g-3 | Δ |
|---|---:|---:|---:|
| `BM_DartCodecFrame` (portão, base da Task 1) | 427 µs | 450 µs | **+5,4% ✅ aceito pelo usuário** |
| `BM_DartImageFrame` (contra o `develop`) | 101 µs | 103 µs | +2,0% |
| `BM_DartCompositeFrame` (contra o `develop`) | 575 | 589 | +2,4% |
| `BM_DartParagraphFrame` (contra o `develop`) | 3861 | 3947 | +2,2% |

Nas rodadas, a primeira medição deu 420 → 610 µs (+45%) por saltos extras
pela fila da UI para cada imagem: o descriptor assíncrono e dois `PostTask`
repetidos custavam aproximadamente 12 µs cada. A correção entrega a callback
diretamente quando já está na UI e fora de uma chamada da API, usando o
contador `api_call_depth_`, e mantém a regra de que a callback nunca roda
dentro da chamada que a pediu. A terceira rodada dos indicadores teve carga da
máquina nas duas variantes; por isso a mediana foi usada.

O portão foi aprovado com +5,4% no `BM_DartCodecFrame`, conforme decisão do
usuário. O custo restante, aproximadamente 3 µs por imagem, fica para a S5.5,
junto com as otimizações estruturais de tabelas de handles e número de
chamadas, como na S4f.

Atualização (2026-10-29): remedido na S5.5c; ver
[runtime-spi-s55c.md](runtime-spi-s55c.md).
