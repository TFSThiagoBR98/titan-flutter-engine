# Runtime SPI S3b-2 — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` até imagens, decodificação e workers do core.

**Escopo:** dados de `ImageDescriptor` sem Dart, ABI 0.4 de imagens, handles,
desenho, decodificação assíncrona, resolução de tamanho-alvo e conformidade
ponta a ponta.

Este relatório registra o checkpoint da S3b-2. O caminho Dart não mudou nesta
fase; o probe continua sendo o oráculo de comportamento do engine.

## Aplicação da série

Uma série de **44 patches** do repositório do Flutter, incluindo **29 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1123 PASS** e **0 FAIL**. O resultado inclui **104 testes** do
`runtime_spi_unittests`, que também passaram com
`--gtest_shuffle --gtest_repeat=3`.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard, confirmando o
layout de 32 bits das novas structs de imagem.

`tools/ci.sh engine` passou.

## Observações da fase

A separação de `ImageDescriptorData` revelou includes transitivos de
`dart_wrapper.h` e tonic em arquivos que consumiam os tipos sem declará-los;
esses includes foram tornados explícitos, sem alterar o caminho Dart. O alvo
`ui_image_decoding` mantém o decodificador e os geradores no grafo sem Dart.

O backend SPI fornece workers concorrentes próprios ao `ImageDecoder`, porque
o caminho sem Dart não pode obter o runner da VM. A resolução de dimensões
reproduz a regra do `dart:ui`, inclusive a preservação da proporção quando
somente largura ou altura é informada. Os testes assíncronos esperam o
callback atravessar worker, thread de IO e UI runner antes de validar o quadro.

Não houve benchmark novo nesta fase.
