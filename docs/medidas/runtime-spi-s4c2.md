# Runtime SPI S4c-2 — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` que transforma o runtime Dart em um runtime
de tabela.

**Escopo:** ABI 0.13 com warm-up frames, lançamento opaco do isolate e o
runtime Dart sobre a tabela do SPI; ABI 0.14 com resultados de views, estado do
runtime e métricas completas de view.

## Aplicação da série

Uma série de **91 patches** do repositório do Flutter, incluindo **76 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1298 PASS** e **0 FAIL**.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard.

`tools/ci.sh engine` passou.

## Bundle

O `engine.lock` registra:

```text
patches_sha256=1e5f99699a9a3b4efaf91a9b209ff1097d270bc9d9681661c6f29809d9def115
```

## Benchmarks

Os benchmarks de `shell_benchmarks` e `ui_benchmarks` estão **pendentes**. A
rodada isolada será executada depois da preparação dos sysroots, porque os
seis núcleos ocupados pelo checkpoint contaminariam a medição.
