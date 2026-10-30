# Runtime SPI S6 — Core estático e artefatos

**Data:** 2026-10-30
**Decisão:** emenda de 2026-10-30 no ADR-0027 (core estático em cada consumidor; core dinâmico para FFI).

## Artefatos por bundle

| Artefato | x64 debug | arm64-musl debug | Uso |
|---|---:|---:|---|
| `libflutter_engine.so` | 41,4 MB | 40,1 MB | apps Dart (`embedder.h`) |
| `libflutter_engine_core.so` | 12,9 MB | 12,0 MB | FFI de outras linguagens (`FlutterCore*`) |
| `libflutter_engine_core.a` | 57,5 MB | 57,1 MB | link estático (Rust e outros hosts nativos) |
| `include/` | — | — | `flutter_core_host.h`, `embedder.h` e os headers do SPI |

O `.a` é maior porque leva todo o código do core, inclusive o que o consumidor não usa; o link final descarta o resto.

## Verificações

| Verificação | Resultado |
|---|---|
| globais definidos do `.a` além de `FlutterCore*` | 0 (os mesmos `FlutterCore*` do `.so` do core) |
| símbolos C++ indefinidos no `.a` | 0 (a `libc++` está dentro) |
| outros indefinidos do `.a` | libc, libm, libdl e rotinas do compilador; `OPENSSL_memory_*` fracos |
| header do bundle compila sozinho (`-I<bundle>/include`) | ok |
| binário Rust (`tests/rust-static-link`) linka o `.a` e roda o smoke | `core static rust: ok` |
| `NEEDED` do binário Rust | `libm`, `libgcc_s`, `libc`, `ld-linux` — nenhuma `libflutter_engine*` |
| `.text` do binário Rust | 9,3 MB (o `.text` do `libflutter_engine_core.so` é 8,7 MB) |

## Checkpoint em cópia limpa

Série de 176 patches aplicada do zero (`patches_sha256` `c6ddc7c6…`):

| Passo | Resultado |
|---|---|
| build x64 + probe | `9afdbcd18abd9b35` |
| build arm64-musl + probe (bundle com os três artefatos) | `9afdbcd18abd9b35` |
| build completo ARM 32-bit (hard float) | ok |
| GN nas 10 variantes | ok |
| check do runtime SPI | 1530 PASS, 0 FAIL; `core static symbols: ok`, `core static rust: ok` |
