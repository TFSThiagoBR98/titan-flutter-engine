# Runtime SPI S3b-3 — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` até a saída de imagens, leitura de pixels e
codecs quadro a quadro.

**Escopo:** costuras Dart-free de snapshot, leitura de imagem e quadros
animados; ABI 0.5 para imagens de saída; snapshots de pictures e cenas;
leitura de pixels e PNG; codecs estáticos e animados; e conformidade ponta a
ponta.

## Aplicação da série

Uma série de **56 patches** do repositório do Flutter, incluindo **41 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1142 PASS** e **0 FAIL**. O resultado inclui **122 testes** do
`runtime_spi_unittests`, que também passaram com
`--gtest_shuffle --gtest_repeat=3`; houve **1 teste pulado**,
`SnapshotFailureIsInternalError`, porque o fixture não injeta um
`SnapshotDelegate` sem superfície.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard, confirmando o
layout de 32 bits das structs novas da ABI 0.5.

`tools/ci.sh engine` passou.

O `engine.lock` registra:

```text
patches_sha256=c90b05dcb9042ab4a4e2e9405036e59b73b8a88bc5111448f03d37dbdf34546e
```

## Observações da fase

Os alvos `image_snapshot`, `image_readback` e `animated_image_frames` ficaram
no alvo Dart-free `ui_image_output`; o wrapper `dart:ui` continua usando as
mesmas regras de validação e callbacks. A imagem síncrona é diferida, o
snapshot assíncrono retorna pelo UI runner e o buffer de bytes só existe
durante o callback. A cena não é consumida por `scene_to_image`.

O codec animado preserva a duração de cada quadro e a repetição infinita é
exposta como `-1`, como no `dart:ui`. A liberação com um quadro pendente
descarta o resultado sem chamar o callback depois do encerramento do backend.

Não houve benchmark novo nesta fase. As correções das Tasks 6 e 7 ficaram
registradas nos patches `0035`–`0041` e serão reagrupadas na S5.5.
