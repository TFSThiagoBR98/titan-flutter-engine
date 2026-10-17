# Runtime SPI S4b — Resultado do Checkpoint

**Data:** 2026-10-17

**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a
série de patches do `runtime-spi` para o Shell sem dependência direta da VM do
Dart.

**Escopo:** ABI 0.11 para handlers do service protocol no core, transporte
através do VM service pela tabela de extensões do runtime e remoção dos pontos
restantes de Dart do `shell.cc`.

## Aplicação da série

Uma série de **82 patches** do repositório do Flutter, incluindo **67 patches
de `runtime-spi`**, aplicou em um worktree limpo do commit fixado em
`flutter.lock`.

## Checker e alvos

`check-runtime-spi.sh` passou com os testes habilitados e desabilitados, com
**1250 PASS** e **0 FAIL**.

O probe produziu o hash `9afdbcd18abd9b35` em x64 e em arm64-musl sob QEMU,
igual ao da referência. A configuração `--gn-only` passou nos dez alvos
previstos. O alvo `runtime_spi_c_api` compilou em arm-hard.

`tools/ci.sh engine` passou.

## Bundle

O `engine.lock` registra:

```text
patches_sha256=4d4caa68c747fa9e2c341454c7f97cef15ebfe8ab941e9322fa4fbeccabeca57
```

## Benchmarks

As medições de `shell_benchmarks` usaram dez repetições e compararam a
mediana com a linha de base; o critério foi mediana menor ou igual à base mais
duas vezes o coeficiente de variação. `BM_ShellInitializationAndShutdown`
ficou em **+2,42%**, dentro do limite de **+2,96%**. `BM_ShellShutdown` ficou
em **−14,9%**, `MultipleDartToNativeMessages` em **−3,5%** e
`TimeToFirstNativeMessageFromIsolateInNewVM` em **+3,0%**, todos dentro do
critério.

`BM_ShellInitialization` ficou inconclusivo: marcou **227 233 ns** na rodada
do checkpoint e **229 991 ns**, **226 086 ns** e **229 566 ns** em três rodadas
isoladas, contra a base de **217 689 ns** (**+4–5%**, limite de **+3,11%**).
Entretanto, a variação entre sessões da mesma medida já chegou a **10%**; a
S1 mediu **240 763 ns**, com CV de **7,7%**, e as rodadas isoladas da S4a
ficaram entre **211 e 215 µs**. O critério de uma única sessão não separa uma
regressão de aproximadamente 10 µs por inicialização da oscilação da máquina.
O A/B controlado entre as duas revisões compiladas, em rodadas intercaladas,
fica pendente para a S5.5.
