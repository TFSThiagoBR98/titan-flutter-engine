# Runtime SPI S3b-4a — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` até os efeitos de pintura e vertices.

**Escopo:** ABI 0.6 de efeitos de pintura; shaders de gradiente e de imagem;
filtros de cor e de imagem; máscara de blur; vertices; pintura com efeitos e
conformidade ponta a ponta.

## Aplicação da série

Uma série de **62 patches** do repositório do Flutter, incluindo **47 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1180 PASS** e **0 FAIL**. O resultado inclui **160 testes** do
`runtime_spi_unittests`, além de **1 teste pulado**. A suíte de efeitos também
passou com `--gtest_shuffle --gtest_repeat=3` e com o filtro de shaders,
filtros, paint effects e vertices.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard, confirmando o
layout de 32 bits da ABI 0.6.

`tools/ci.sh engine` passou.

O `engine.lock` registra:

```text
patches_sha256=ab48f979f962f90949ee847861d0702e00fa98d1e52d564b4dfd8f823707dc5d
```

## Observações da fase

Os efeitos são montados diretamente sobre os objetos `Dl*`, sem uma costura
adicional com Dart. A igualdade por conteúdo permite comparar as fábricas da
ABI com as fábricas usadas pelo `dart:ui`; o shader de imagem usa o mesmo
`DlImage` nos dois lados. A tabela de handles mantém os objetos vivos quando
uma picture já os capturou.

O campo `paint_effects` foi acrescentado ao fim de `FlutterSpiEngineApi` e os
novos campos de `FlutterSpiPaint` também ficam no fim, preservando paints com
o tamanho antigo. A primeira conferência arm-hard revelou que o tamanho de
`FlutterSpiEngineApi` em 32 bits é **88 bytes**, e não 84: a ABI 0.6 acrescenta
um ponteiro de 4 bytes. As expectativas congeladas foram atualizadas para
esse valor.

Não houve benchmark novo nesta fase.
