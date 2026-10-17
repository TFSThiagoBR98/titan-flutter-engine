# Runtime SPI S3b-4c — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` até os fragment programs.

**Escopo:** ABI 0.8 para fragment programs carregados de assets ou bytes,
uniforms float e samplers, e conversão em shaders de paint ou image filters;
carregamento Dart-free de runtime stages do `impellerc`.

## Aplicação da série

Uma série de **72 patches** do repositório do Flutter, incluindo **57 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1221 PASS** e **0 FAIL**.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard.

`tools/ci.sh engine` passou.

## Bundle

O `engine.lock` registra:

```text
patches_sha256=94269ed8c3d24e9e52bb09ca1ded81a2c166307f57e4f4058a874cd8bbb7fc78
```

## Benchmarks

Nenhum benchmark novo nesta fase.
