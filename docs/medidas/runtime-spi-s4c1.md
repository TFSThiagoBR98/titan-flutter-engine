# Runtime SPI S4c-1 — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` para o contrato completo entre engine e
runtime.

**Escopo:** ABI 0.12 com as funções de telas, tempos de quadro e hit test do
engine para o runtime, e com o contrato restante do `RuntimeDelegate`, além da
leitura de assets pelo engine.

## Aplicação da série

Uma série de **85 patches** do repositório do Flutter, incluindo **70 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1275 PASS** e **0 FAIL**.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard.

`tools/ci.sh engine` passou.

## Bundle

O `engine.lock` registra:

```text
patches_sha256=a02204f0857fc6a46f7e1dc1315f48368bbd88b4c2b157295710bbec820512de
```

## Benchmarks

Benchmarks não foram medidos nesta fase, porque o contrato do Runtime SPI não
altera o pipeline de quadros.
