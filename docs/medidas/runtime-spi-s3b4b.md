# Runtime SPI S3b-4b — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` até as camadas restantes do scene builder.

**Escopo:** ABI 0.7 para color filter, image filter, backdrop, shader mask,
clip de superelipse, textura, platform view e performance overlay; camadas
retidas entre quadros; blur com tile mode dinâmico e bounds; conformidade ponta
a ponta sem Dart.

## Aplicação da série

Uma série de **68 patches** do repositório do Flutter, incluindo **53 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1204 PASS** e **0 FAIL**.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard.

`tools/ci.sh engine` passou.

## Bundle

O `engine.lock` registra:

```text
patches_sha256=4e340893527f72a8ec7484072d880dfd5008af87450de8608a42fb0341644f20
```

## Benchmarks

Nenhum benchmark novo nesta fase.
