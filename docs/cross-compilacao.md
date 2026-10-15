# Cross-compilação do Flutter Engine

Os builds ARM usam os sysroots mínimos gerados pelo Buildroot
(`scripts/make-buildroot-sysroot.sh`) e o Clang embutido no checkout do Flutter.

## Runtime do compilador no ARM soft-float

O Clang embutido traz o `compiler-rt` e o `libunwind` só para
`armv7-unknown-linux-gnueabihf`. Esse runtime usa a convenção de chamada
hard-float (argumentos de ponto flutuante em registradores VFP) e não pode ser
misturado com um alvo `gnueabi` (soft/softfp).

Em vez de compilar outro `compiler-rt`, o alvo softfp usa o runtime do GCC que o
Buildroot já compila para a ABI certa (`crtbegin*.o`, `libgcc.a`,
`libgcc_eh.a`). O `make-buildroot-sysroot.sh` o instala em
`usr/lib/gcc/arm-linux-gnueabi[hf]/<versão>/` dentro do sysroot, onde o Clang o
encontra sozinho. O patch `cross-linux-arm/0004` faz o link do ARM não-hard com
`--rtlib=libgcc --unwindlib=libgcc -static-libgcc`, de modo que o
`libflutter_engine.so` continua dependendo só da libc. O hard-float segue com o
`compiler-rt` embutido.

## Verificação da ABI

Todo bundle ARM é verificado pela flag de ABI do cabeçalho ELF
(`readelf -h`): hard-float deve mostrar `hard-float ABI` e softfp/soft deve
mostrar `soft-float ABI`. É essa flag que o loader da glibc confere. A seção
`.ARM.attributes` (`readelf -A`) não serve para isso: o `lld` mantém a do
primeiro objeto do link, que é o `crti.o` do sysroot, e o do Buildroot (montado
de assembly) não traz `Tag_ABI_VFP_args`.

## Versão da glibc

O engine linkado num sysroot glibc exige no aparelho a glibc do sysroot, não só
a versão que o código usa: com a glibc 2.42 do Buildroot, os dois bundles pedem
`GLIBC_2.38` (`__isoc23_strtol`, `fmod`, `pthread_*@GLIBC_2.34`). Os sysroots
glibc servem às distros atuais; o Kindle e outros sistemas de nicho usam o
sysroot musl (`titan_armv7a_softfp_musl_defconfig`), com a libc distribuída
junto do engine.

## Validação em QEMU (modo usuário)

`scripts/qemu-probe.sh --abi hf|softfp --cpu <cpu>` compila `tests/qemu/probe_engine.c` com o Clang embutido e o
roda com `qemu-arm-static -L <sysroot>`. O probe carrega o `libflutter_engine.so`, inicia o engine com o renderer por
software e um *platform task runner* próprio (sem ele, as tarefas de plataforma nunca rodam e o primeiro quadro não
sai), manda métricas de 320×240 e espera o primeiro quadro do app spike (`PROBE_TIMEOUT_SECONDS`, padrão 120).

Resultado (2026-10-14, engine debug/JIT, app `titan_spike_counter`):

| ABI | CPU emulada | Resultado | Tempo |
|---|---|---|---|
| hf | `cortex-a8` | quadro 320×240 + `ok` | 12,1 s |
| hf | `cortex-a7` | quadro 320×240 + `ok` | 12,2 s |
| softfp | `cortex-a8` | quadro 320×240 + `ok` | 12,3 s |
| softfp | `arm1176` (armv6j) | `SIGILL` em 0,2 s | — |

O hash do quadro é o mesmo nos três casos ARMv7 e no x64 nativo (`b49a7f31cecb7983`): o Dart e o engine rodam e
desenham igual. No armv6j, a falha vem já da primeira instrução ARMv7 do userland (glibc do sysroot e o probe são
ARMv7), antes do engine; como o Dart VM só suporta ARMv7+, o armv6j (base do Debian armel) fica **fora**. O Kindle
(armv7-a soft-float) é suportado.
