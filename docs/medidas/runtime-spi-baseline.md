# Linha de base do Runtime SPI (S1, Checkpoint A)

**Data:** 2026-10-16
**Engine:** `flutter_commit=e81f444cc0835365bda671876183e3f9cd149925` com a série de patches até `sdk-dart-packages`
(a pasta `runtime-spi/` ainda está vazia).
**Build:** x64 glibc debug, `scripts/build-engine.sh --mode debug --unittests`, no host (metade dos núcleos, `nice`).

Esta é a referência das fases S1–S6: nenhuma delas pode criar uma falha nova de gtest, mudar o hash do probe ou
piorar os benchmarks além da variação medida aqui.

## gtests

`scripts/run-engine-tests.sh <out_dir> --baseline tests/runtime-spi/baseline-failures.txt` (roda de `engine/src`):

| Binário | Testes | Falhas |
|---|---:|---:|
| `fml_unittests` | 195 | 0 |
| `runtime_unittests` | 42 | 0 |
| `shell_unittests` | 204 (5 pulados) | 0 |
| `ui_unittests` | 90 (6 pulados) | 0 |
| `embedder_unittests` | 195 (5 pulados) | 0 |
| `flow_unittests` | 279 | 0 |

Os pulados são do upstream (Metal, AOT/ELF, Impeller sem GPU). `baseline-failures.txt` fica vazio.

## Peso do Dart no `libflutter_engine.so`

`scripts/measure-dart-footprint.sh out/host_debug/lib.unstripped/libflutter_engine.so` (o `.so` distribuído tem
43 001 776 bytes; o sem *strip*, 104 460 752):

| Grupo | Bytes |
|---|---:|
| `.text` | 14 360 590 |
| `.rodata` | 24 113 368 |
| Snapshots e kernel do Dart (`kDartSnapshotData`, `kPlatformStrongDill`, …) | 21 894 741 |
| Código da VM (`dart::`, `Dart_`) | 3 635 602 |
| `tonic::` | 26 997 |
| `flutter::` do runtime Dart (`Dart*`, `RuntimeController`) | 54 863 |
| `flutter::` de `lib/ui` | 50 053 |
| `flutter::` restante | 650 650 |
| `impeller::` | 1 075 770 |
| Skia | 1 832 235 |
| Outros | 8 921 920 |

Cerca de metade do `.so` distribuído é dado do Dart (snapshot da VM e kernel do `dart:ui`), não código. É esse o
ganho principal de um core sem Dart.

## Benchmarks

Três repetições, mediana e coeficiente de variação (`--benchmark_repetitions=3`), rodando de `engine/src`:

| Benchmark | Mediana | CV |
|---|---:|---:|
| `DartNativeBenchmarks/TimeToFirstNativeMessageFromIsolateInNewVM` | 32,2 ms | 4,4% |
| `DartNativeBenchmarks/MultipleDartToNativeMessages` | 34,6 ms | 9,8% |
| `BM_ShellInitialization` | 217,7 µs | 1,6% |
| `BM_ShellShutdown` | 208,0 µs | 11,3% |
| `BM_ShellInitializationAndShutdown` | 400,2 µs | 1,5% |
| `BM_PlatformMessageResponseDartComplete` | 65,5 µs | 8,0% |

Critério das próximas fases: a mediana nova não passa da mediana daqui somada a duas vezes o CV dela. Nenhum desses
benchmarks mede a montagem de quadro pelo `Canvas`; esse microbenchmark entra na S3, antes da conversão do `dart:ui`
na S4.

## Probe

O hash de quadro de referência continua `9afdbcd18abd9b35` (`tests/qemu/expected-frame-hash`): a série ainda não tem
patches de `runtime-spi/`, então o engine do probe é o mesmo da última verificação da matriz.
