# Runtime SPI S1 — Resultado do Checkpoint B

**Data:** 2026-10-16
**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a série de patches até `runtime-spi`.
**Build:** x64 glibc debug e profile, com a série reaplicada em checkout limpo; alvos cruzados configurados por GN.

Este relatório registra o resultado do Checkpoint B da S1. O caminho Dart
continua sendo o oráculo de comportamento para as seams do Runtime SPI.

## Aplicação da série

A série de 22 patches do repositório do Flutter e 7 patches de `runtime-spi`
aplicou em um worktree limpo do commit fixado de `flutter.lock`.

## gtests

Os gtests x64 debug registraram **1019 PASS** e **0 FAIL**. A linha de base
tinha 1010 testes, e os testes novos da S1 foram executados sem falha.

## Benchmarks

Foram feitas 10 repetições. As medianas abaixo permaneceram dentro da mediana
da linha de base mais duas vezes o coeficiente de variação:

| Benchmark | Resultado |
|---|---:|
| `BM_ShellInitialization` | 216,5 µs (−0,5%) |
| `BM_ShellShutdown` | 170,7 µs (−18%) |
| `BM_ShellInitializationAndShutdown` | 384,6 µs (−3,9%) |
| `TimeToFirstNativeMessage…` | +5,2% |
| `MultipleDartToNativeMessages` | +2,3% |
| `BM_PlatformMessageResponseDartComplete` | +4,1% |

Com três repetições, `BM_ShellInitialization` havia apresentado +10,6% por
ruído; as próximas fases usarão 10 repetições.

## Probe e CI

O hash do probe foi `9afdbcd18abd9b35` em x64 e arm64-musl sob QEMU, igual ao
da referência. `tools/ci.sh engine` passou; os panics registrados no log
pertencem ao teste `a_panicking_frame_sink_does_not_abort_the_process`.

O `--gn-only` passou em 10 dos 12 alvos. `riscv32-glibc` e `riscv32-musl`
foram recusados antes do GN porque os sysroots tinham carimbo desatualizado,
uma condição pré-existente sem relação com a S1; recriá-los exige Buildroot.
