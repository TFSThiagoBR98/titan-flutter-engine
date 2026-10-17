# Runtime SPI S3b-5 — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` para a atualização de semântica.

**Escopo:** ABI 0.9 para publicar nós de semântica com flags, ações, textos
com atributos, geometria, transformações, filhos e ações customizadas,
reproduzindo o resultado do `SemanticsUpdateBuilder` do `dart:ui` sem Dart.

## Aplicação da série

Uma série de **75 patches** do repositório do Flutter, incluindo **60 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1236 PASS** e **0 FAIL**.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard.

`tools/ci.sh engine` passou.

## Bundle

O `engine.lock` registra:

```text
patches_sha256=6d0d5a87f04b484c75a377ba1f01794109e1d2c7ba02d0e96e4894002b9a4dfb
```

## Benchmarks

Nenhum benchmark novo nesta fase.
