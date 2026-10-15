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

Todo bundle ARM é verificado com `readelf -A`: hard-float deve mostrar
`Tag_ABI_VFP_args: VFP registers`, enquanto softfp/soft não podem mostrar
`Tag_ABI_VFP_args`.
