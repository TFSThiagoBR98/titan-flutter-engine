# Linux musl

Engine ARM softfp com a libc musl (Kindle e sistemas de nicho), com o sysroot
Buildroot `titan_armv7a_softfp_musl`. Aplica-se somente quando `cpu=arm` e
`libc=musl`; o argumento de gn `titan_target_libc` mantém glibc como padrão.
O `build-engine.sh --libc musl` também passa `--no-backtrace` (o `fml` usa o
stub, porque `execinfo.h` é só da glibc).

| Patch | Por quê |
|---|---|
| `0001-linux-musl-target` | argumento `titan_target_libc`, tripla `arm-linux-musleabi` e sysroot musl |
| `0002-linux-musl-libcxx-config` | liga os *fallbacks* de musl que a libc++ embutida já tem (só no alvo ARM; as ferramentas de host seguem na glibc) |
| `0003-linux-musl-cmsg-sign-compare` | o `CMSG_NXTHDR` do musl dispara `-Wsign-compare` no código de sockets do Dart |
| `0004-linux-musl-flatbuffers-locale` | o musl anuncia `_XOPEN_VERSION` 700 sem ter `strtoll_l`/`strtoull_l` |
| `0005-linux-musl-snapshot-own-library` | o `RTLD_DEFAULT` do musl só busca o namespace global: o engine carregado com `RTLD_LOCAL` não achava o próprio snapshot do Dart |
