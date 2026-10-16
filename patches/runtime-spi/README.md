# Runtime SPI

Patches do seam interno entre o core do Flutter Engine e os backends de
runtime. Cada patch exportado registra uma mudança isolada do branch
`titan/runtime-spi`.

A série `runtime-spi` só modifica o repositório do Flutter.

| Patch | Por quê | Plataformas |
|---|---|---|
| `0001-build-engine-add-the-no-dart-dependency-checker.patch` | Adicionar o alvo GN e o checker antes de mover as fontes de `lib/ui`. | |
| `0002-feat-engine-split-the-dart-free-lib-ui-types.patch` | Separar os tipos de dados de `lib/ui` sem Dart no próprio alvo. | |
| `0003-feat-engine-route-fml-tracing-through-a-pluggable-timeline-backend.patch` | Encaminhar o tracing de FML por um backend de timeline substituível. | |
| `0004-feat-engine-drive-the-runtime-through-a-runtimebackend-interface.patch` | Conduzir o runtime por uma interface `RuntimeBackend`. | |
| `0005-feat-engine-create-the-shell-runtime-through-a-backend-factory.patch` | Criar o runtime do shell por uma fábrica de backends. | |
| `0006-fix-engine-make-the-runtime-spi-seams-compile.patch` | Restaurar includes e declarações removidos pela divisão do seam. | |
| `0007-refactor-engine-keep-dart-types-out-of-the-runtime-backend-seam.patch` | Consolidar as correções da revisão S1 para manter o seam sem tipos Dart. | |

O fluxo é:

1. `scripts/patch-branch.sh prepare <flutter_dir> <worktree_dir>` cria o
   worktree no commit de `flutter.lock` e aplica a série anterior.
2. Cada mudança é feita no worktree como um commit com corpo explicando o
   motivo.
3. `scripts/patch-branch.sh export <worktree_dir> runtime-spi` converte os
   commits em patches numerados para a série.

## Verificar o build

Com um build que tenha os testes habilitados, execute os gtests a partir do
diretório de saída:

```bash
scripts/run-engine-tests.sh <out_dir> \
  --baseline tests/runtime-spi/baseline-failures.txt
```

Os benchmarks estão listados separadamente em
`tests/runtime-spi/benchmark-targets.txt` e não são executados pelo runner de
gtests. Para medir a participação do Dart, use a biblioteca não despojada:

```bash
scripts/measure-dart-footprint.sh \
  <out_dir>/lib.unstripped/libflutter_engine.so
```
