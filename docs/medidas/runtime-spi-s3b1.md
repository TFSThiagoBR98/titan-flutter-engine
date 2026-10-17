# Runtime SPI S3b-1 — Resultado do Checkpoint

**Data:** 2026-10-16

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` até texto, parágrafos e desenho de texto.

**Escopo:** ABI de texto, estilos, carregamento de fontes, parágrafos,
layout, métricas, consultas UTF-16, desenho e conformidade ponta a ponta.

Este relatório registra o checkpoint da S3b-1. O caminho Dart não mudou nesta
fase; o probe continua sendo o oráculo de comportamento do engine.

## Aplicação da série

Uma série de **39 patches** do repositório do Flutter, incluindo **24 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1097 PASS** e **0 FAIL**. O resultado inclui **78 testes** do
`runtime_spi_unittests`, que também passaram isolados por suíte e com
`--gtest_shuffle --gtest_repeat=3`.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard, confirmando o
layout de 32 bits das structs de texto.

`tools/ci.sh engine` passou.

## Observações da fase

O fixture de texto carrega a `Roboto-Regular.ttf` do checkout e inicializa o
ICU explicitamente antes de montar parágrafos, para que a paridade não dependa
da ordem dos testes. A cor de texto precisa ser opaca para que o
`DisplayListBuilder` registre a operação de desenho. A paridade de desenho
compara cor, bounds e glyphs, porque `DlText::operator==` compara ponteiros de
blobs que não são compartilhados entre parágrafos montados separadamente.

Não houve benchmark novo nesta fase.
