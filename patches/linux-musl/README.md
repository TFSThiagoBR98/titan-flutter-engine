# Linux musl

Correções para builds Linux com a libc musl (Kindle e sistemas de nicho). A
seleção de CPU, ABI, tripla e sysroot fica na pasta `linux-target-matrix`;
esta pasta só testa `titan_target_libc == "musl"`.
O `build-engine.sh --libc musl` também passa `--no-backtrace` (o `fml` usa o
stub, porque `execinfo.h` é só da glibc).

| Patch | Por quê | Plataformas afetadas |
|---|---|---|
| `0001-libcxx-config.patch` | liga os *fallbacks* de musl que a libc++ embutida já tem no toolchain do alvo | Todos os alvos musl |
| `0002-cmsg-sign-compare.patch` | o `CMSG_NXTHDR` do musl dispara `-Wsign-compare` no código de sockets do Dart | Todos os alvos musl |
| `0003-flatbuffers-locale.patch` | o musl anuncia `_XOPEN_VERSION` 700 sem ter `strtoll_l`/`strtoull_l` | Todos os alvos musl |
| `0004-snapshot-own-library.patch` | o `RTLD_DEFAULT` do musl só busca o namespace global; o engine carregado com `RTLD_LOCAL` precisa procurar a própria biblioteca | Todos os alvos musl |
