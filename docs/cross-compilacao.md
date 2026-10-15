# Cross-compilação do Flutter Engine

Todos os alvos são compilados num host Linux x86_64, com o Clang embutido no checkout do Flutter e um sysroot por
alvo gerado pelo Buildroot. A matriz oficial (alvo → tripla → sysroot → runtime → estado) está em
[plataformas.md](plataformas.md).

## Como um alvo é escolhido

Um alvo é a combinação **CPU × ABI de ponto flutuante (só ARM) × libc**, passada ao script:

```sh
scripts/build-engine.sh --mode debug|profile|release \
  --cpu x64|arm64|arm|riscv64 [--arm-float-abi hard|softfp|soft] [--libc glibc|musl] \
  [--target-sysroot <sysroot>]
```

O script repassa ao GN o `arm_float_abi` e o `titan_target_libc`; tudo o que muda por alvo é decidido **dentro do
GN**, pelos patches em `patches/` (veja a seção seguinte). Sem `--target-sysroot`, o GN usa o sysroot padrão do alvo
(`engine/src/build/linux/titan_<alvo>-sysroot`, o link que o `make-buildroot-sysroot.sh` cria); o x64 glibc sem
sysroot explícito continua com o sysroot Debian do Chromium, que é o do bundle do TitanDM.

Cada alvo compila num diretório próprio em `engine/src/out/`: `host_<modo>` para o x64 glibc (o nome padrão do
Flutter) e `linux_<modo>_<cpu>[_<abi>]_<libc>` para os demais (por exemplo `linux_debug_arm_softfp_musl`). Por isso
vários alvos podem compilar ao mesmo tempo.

## Patches por assunto

`patches/series` lista as pastas na ordem de aplicação e **não tem condições**: a série inteira se aplica a todo
build, e cada patch se limita ao alvo certo por condições no próprio GN (`current_cpu`, `arm_float_abi`,
`titan_target_libc`, `build_linux_gtk_shell`, e o toolchain do alvo quando os de host precisam ficar intactos).

| Pasta | Assunto |
|---|---|
| `impeller-vulkan/` | backing stores Vulkan do Impeller na Embedder API |
| `linux-embedder-only/` | `build_linux_gtk_shell`: engine sem o shell GTK quando só o embedder é pedido |
| `linux-target-matrix/` | `titan_target_libc`, sysroot padrão e tripla do Clang de cada alvo |
| `linux-compiler-runtime/` | runtime do GCC do sysroot onde o `compiler-rt` embutido não cobre a tripla |
| `linux-musl/` | portabilidade para a libc musl, em qualquer CPU |

Cada pasta tem um README com a tabela patch → por quê → plataformas afetadas, e cada patch começa com um cabeçalho
`# Why:`. O script aplica a série sob um `flock` e grava o hash da série aplicada no checkout; se o checkout já está
com a mesma série, a fase de patch é pulada, para nunca restaurar arquivos enquanto outro build compila.

## Vários alvos em paralelo

```sh
scripts/build-matrix.sh [--parallel N] [variante …]
```

Roda até `N` builds ao mesmo tempo (padrão 3), cada um com `ninja -j <núcleos> -l <núcleos>`: o `-l` segura novos
jobs quando a carga passa do número de núcleos, de modo que o link de um build se sobrepõe à compilação de outro. Os
logs ficam em `.build_flutter/matrix/<variante>.log` e o script termina com um resumo (variante, duração, resultado).
Debug e profile compilam **sem LTO** (como o CI do Flutter nos artefatos de host); o release mantém o LTO.

## Runtime do compilador (`linux-compiler-runtime`)

O Clang embutido traz o `compiler-rt` e o `libunwind` só para algumas triplas glibc; no ARM, só para
`armv7-unknown-linux-gnueabihf`, cuja convenção de chamada hard-float (argumentos em registradores VFP) não pode ser
misturada com um alvo soft/softfp. Onde o embutido não serve — todo alvo musl, ARM soft/softfp e riscv32 —, o link
usa o runtime do GCC que o Buildroot compila para a ABI certa (`crtbegin*.o`, `libgcc.a`, `libgcc_eh.a`), com
`--rtlib=libgcc --unwindlib=libgcc -static-libgcc`; o `libflutter_engine.so` segue dependendo só da libc. O
`make-buildroot-sysroot.sh` instala esse runtime em `usr/lib/gcc/<tripla>/<versão>/` dentro do sysroot, onde o Clang
o encontra sozinho.

## Conferências do bundle

- **ABI de ponto flutuante (ARM):** pela flag do cabeçalho ELF (`readelf -h`: `hard-float ABI` ou `soft-float ABI`),
  que é o que o loader confere. A seção `.ARM.attributes` (`readelf -A`) não serve: o `lld` mantém a do primeiro
  objeto do link, o `crti.o` do sysroot, e o do Buildroot (montado de assembly) não traz `Tag_ABI_VFP_args`.
- **musl:** `NEEDED` só `libc.so` e nenhum símbolo `GLIBC_*` (um `.so` não tem `PT_INTERP` para conferir).

## Versão da glibc

O engine linkado num sysroot glibc exige no aparelho a glibc **do sysroot**: com a glibc 2.42 do Buildroot, os
bundles pedem `GLIBC_2.38` (`__isoc23_strtol`, `fmod`, `pthread_*@GLIBC_2.34`). Os alvos glibc servem às distros
atuais; sistemas com glibc antiga ou kernels antigos (o Kindle, por exemplo) usam o alvo musl. O glibc do Buildroot
também é configurado com `--enable-kernel=5.10`.

## musl

Os patches de `linux-musl/` cobrem o que o build e o runtime esbarraram: os *fallbacks* de musl da libc++, o
`-Wsign-compare` do `CMSG_NXTHDR`, o `strtoll_l` do flatbuffers e a busca do snapshot do Dart (o `RTLD_DEFAULT` do
musl só busca o namespace global, e o engine carregado com `RTLD_LOCAL` não achava o próprio snapshot). O
`build-engine.sh --libc musl` passa também `--no-backtrace` (o `execinfo.h` é só da glibc; o `fml` usa o stub).

**Distribuição:** o aparelho não precisa ter musl. Leve junto do bundle o `lib/ld-musl-<arch>.so.1` do sysroot (no
musl, o loader e a `libc.so` são o mesmo arquivo; crie o link `libc.so` → `ld-musl-<arch>.so.1`) e rode o embedder com
esse loader (`./ld-musl-arm.so.1 --library-path . ./runner …`), ou linke o embedder com `-Wl,--dynamic-linker`
apontando para o caminho do bundle. O musl roda em kernels antigos.

## Validação no QEMU (modo usuário)

`scripts/qemu-probe.sh --abi x64|hf|softfp|softfp-musl [--cpu <cpu>] [--assets <dir>]` compila
`tests/qemu/probe_engine.c` com o Clang embutido e o roda nativo (x64) ou com `qemu-arm-static -cpu <cpu> -L <sysroot>`. O probe carrega o `libflutter_engine.so`, inicia o
engine com o renderer por software e um *platform task runner* próprio (sem ele, as tarefas de plataforma nunca rodam
e o primeiro quadro não sai), manda métricas de 320×240 e espera o primeiro quadro do app (`PROBE_TIMEOUT_SECONDS`, padrão 120). O app padrão é o de
`tests/qemu/app`; dentro do TitanDM, o app spike. O `scripts/ci.sh probe` roda todos os alvos com o mesmo app e exige
o mesmo hash de quadro (com o app de `tests/qemu/app`, `8dca0036f583054a` em x64, hf, softfp e softfp musl, em
2026-10-15).

Resultado (2026-10-14, engine debug/JIT, app `titan_spike_counter`):

| Alvo | CPU emulada | Resultado | Tempo |
|---|---|---|---|
| armv7-a hf glibc | `cortex-a8` | quadro 320×240 + `ok` | 12,1 s |
| armv7-a hf glibc | `cortex-a7` | quadro 320×240 + `ok` | 12,2 s |
| armv7-a softfp glibc | `cortex-a8` | quadro 320×240 + `ok` | 12,3 s |
| armv7-a softfp musl | `cortex-a8` | quadro 320×240 + `ok` | — |
| armv7-a softfp glibc | `arm1176` (armv6j) | `SIGILL` em 0,2 s | — |

O hash do quadro é o mesmo em todos os casos ARMv7 e no x64 nativo (`b49a7f31cecb7983`): o Dart e o engine rodam e
desenham igual. No armv6j, a falha vem já da primeira instrução ARMv7 do userland, antes do engine; como o Dart VM só
suporta ARMv7+, o armv6j (base do Debian armel) fica **fora**.

## Atualizar o Flutter e os patches

O commit e a versão legível ficam em `flutter.lock`. Depois de atualizar o commit, aplique os patches um por vez no
checkout (`git apply --check`), resolva só os conflitos do código correspondente e regenere cada patch com
`git diff` (o cabeçalho `diff --git` é obrigatório: o script usa essas linhas para restaurar os arquivos tocados).
Confirme com o build da matriz, o probe do QEMU e `scripts/test_patch_series.py`; o `engine.lock` do TitanDM recebe o
hash novo da série.
