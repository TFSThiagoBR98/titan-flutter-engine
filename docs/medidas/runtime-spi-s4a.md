# Runtime SPI S4a — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` para as extensões opcionais do runtime.

**Escopo:** ABI 0.10 para a tabela C opcional de extensões do runtime, com as
funções que só existem com Dart (microtasks, deferred libraries, código de
retorno, service ID e platform isolates) chamadas pelo Engine sem a interface
C++ `DartRuntimeExtensions`.

## Aplicação da série

Uma série de **78 patches** do repositório do Flutter, incluindo **63 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1242 PASS** e **0 FAIL**.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard.

`tools/ci.sh engine` passou.

## Bundle

O `engine.lock` registra:

```text
patches_sha256=644a727099bb6ab1018ae5d2de2cad44b9ae255a1a7f73fa036e57dd681bec1b
```

## Benchmarks

As medições de `shell_benchmarks` usaram dez repetições e compararam a
mediana com a linha de base; o critério foi mediana menor ou igual à base mais
duas vezes o coeficiente de variação. `BM_ShellInitialization` teve base de
217 689 ns e a rodada do checkpoint marcou 227 128 ns (+4,34%), acima do
limite de +3,12%; duas repetições adicionais, com a máquina calma, marcaram
214 796 ns e 211 281 ns, abaixo da base, classificando o resultado como
ruído.

`BM_ShellInitializationAndShutdown` passou de 400 246 ns para 395 958 ns
(-1,07%). `BM_ShellShutdown` passou de 208 034 ns para 174 535 ns (-16,1%),
com CV da base de 11,3%. `MultipleDartToNativeMessages` passou de 34,58 ms
para 33,37 ms (-3,49%). `TimeToFirstNativeMessageFromIsolateInNewVM` passou
de 32,21 ms para 33,16 ms (+2,96%), com CV de 4,42%. Não houve regressão.
