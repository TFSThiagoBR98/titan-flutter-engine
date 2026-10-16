# Runtime SPI

Patches do seam interno entre o core do Flutter Engine e os backends de
runtime. A pasta começa vazia; cada patch exportado registra uma mudança
isolada do branch `titan/runtime-spi`.

| Patch | Por quê | Plataformas |
|---|---|---|

O fluxo é:

1. `scripts/patch-branch.sh prepare <flutter_dir> <worktree_dir>` cria o
   worktree no commit de `flutter.lock` e aplica a série anterior.
2. Cada mudança é feita no worktree como um commit com corpo explicando o
   motivo.
3. `scripts/patch-branch.sh export <worktree_dir> runtime-spi` converte os
   commits em patches numerados para a série.
