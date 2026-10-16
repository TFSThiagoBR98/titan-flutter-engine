# Runtime SPI S3a — Resultado do Checkpoint

**Data:** 2026-10-16

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` até a API de cena.

**Escopo:** paths, paints, picture recorder, canvas, scene builder, scene
trace e o teste de conformidade ponta a ponta.

Este relatório registra o checkpoint da S3a. O caminho Dart não mudou nesta
fase; o probe continua sendo o oráculo de comportamento do engine.

## Aplicação da série

Uma série de **35 patches** do repositório do Flutter, incluindo **20 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados. O
checker também passou nos testes de ausência de dependências de Dart nos dois
modos de configuração.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard, confirmando o
layout de 32 bits das novas structs.

`tools/ci.sh engine` passou.

## Benchmark ABI × builder direto

O benchmark foi executado em `out/host_debug`, com dez repetições e 10.000
chamadas `canvas_draw_rect` por amostra:

| Caminho | Mediana | Coeficiente de variação |
|---|---:|---:|
| `BM_SpiCanvasDrawRect` | 1.357.076 ns | 0,36% |
| `BM_DlBuilderDrawRect` | 806.030 ns | 0,20% |

O caminho pela ABI mede **1,68×** o caminho direto, uma diferença de cerca de
**55 ns por chamada**. O custo observado inclui a busca do handle, a checagem
de thread e as conversões dos valores C para os tipos do engine. Em um quadro
com 1.000 operações, a estimativa é de aproximadamente **55 µs**, ou **0,3%
de um orçamento de 16,7 ms**.

O resultado é aceitável para a S3a. A busca do handle por chamada é o primeiro
alvo de otimização para a S4; o `dart:ui` poderá manter o objeto já resolvido.
