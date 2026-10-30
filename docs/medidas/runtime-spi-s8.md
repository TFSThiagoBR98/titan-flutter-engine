# Runtime SPI S8 — Estudo: `libflutter_engine.so` dependendo do core

**Data:** 2026-10-30
**Pergunta (usuário, 2026-10-29):** vale voltar ao modelo original do ADR-0027, em que o `libflutter_engine.so`
tem `DT_NEEDED` no `libflutter_engine_core.so` em vez de conter uma cópia do core?

Este documento só estuda. Nenhuma implementação começa antes da decisão do usuário.

## Resumo

| Opção | O que muda | Custo | Ganho |
|---|---|---|---|
| **A — dois artefatos alternativos (hoje)** | nada | nenhum | — |
| **B — `DT_NEEDED` com C++ exportado** | o core exporta `flutter::`/`fml::` e o `.so` Dart deixa de linkar os objetos do core | médio: grafo GN, uma `libc++` só, superfície exportada de milhares de símbolos | até ~6 MB de RAM no sistema e ~13 MB de disco, só com apps Dart **e** Rust instalados |
| **C — fronteira só em C** | o lado Dart vira um runtime do SPI sobre `FlutterCore*`, com `fml` próprio | alto: reescrever a cola do caminho Dart (~12 arquivos) e acrescentar ganchos ao SPI | o mesmo de B, mais a prova de que o SPI basta para o Dart |
| **D — `fml` e `libc++` como `.so`** | dois artefatos a mais | médio | não resolve as classes `flutter::` que atravessam a fronteira |

**Recomendação: ficar com A agora.** O ganho tem teto baixo e hoje é zero, porque todos os apps do TitanDM são
Dart. Reabrir a decisão quando o primeiro app em Rust (trilha `flutter-rs`) for instalado por padrão junto do
shell Dart. Se reabrir, preferir C a B.

## Como os artefatos se compõem hoje

Pelas entradas de link do ninja (`out/host_debug`):

| Conjunto | Objetos |
|---|---:|
| comuns aos dois `.so` (o core) | 2840 |
| só no `libflutter_engine.so` (Dart VM, `dart:ui`, `runtime/`, `lib/gpu`, cola) | 622 |
| só no `libflutter_engine_core.so` | 0 |

O core é um subconjunto exato do artefato Dart: o `libflutter_engine.so` é o core mais 622 objetos.

## Medidas

### Disco

| Build | Artefato | Arquivo | `.text` | `.rodata` |
|---|---|---:|---:|---:|
| release x64 | `libflutter_engine.so` | 17,4 MB | 12,8 MB | 1,9 MB |
| release x64 | `libflutter_engine_core.so` | 13,3 MB | 9,7 MB | 1,7 MB |
| debug x64 | `libflutter_engine.so` | 43,5 MB | 14,6 MB | 24,2 MB (snapshots JIT) |
| debug x64 | `libflutter_engine_core.so` | 13,6 MB | 9,1 MB | 1,8 MB |

Em release, ~76% do `libflutter_engine.so` é o core. Com B ou C, o `.so` Dart cairia para ~4–5 MB, e o sistema
que instala as duas pilhas economizaria ~13 MB. O sistema com uma pilha só não economiza nada: precisaria dos dois
arquivos de qualquer jeito.

### Memória (páginas residentes)

`Rss` do segmento de código (`r-xp`) e do de dados somente leitura (`r--p`) em `/proc/<pid>/smaps`, build debug:

| Processo | Biblioteca | `r-xp` residente / mapeado | `r--p` residente |
|---|---|---:|---:|
| `flutter_engine_core_smoke` (renderizador software) | core | 4,6 / 8,7 MB | 1,6 MB |
| `flutter_engine_core_gpu_triangle` (Impeller em Vulkan) | core | 4,5 / 8,7 MB | — |
| `titan-flutter-runner` com o app `titan_spike_counter` | `libflutter_engine.so` | 10,0 / 13,9 MB | 9,4 MB |

O compartilhamento de páginas é **por arquivo**: os apps Rust já compartilham entre si o mesmo
`libflutter_engine_core.so`, e os apps Dart compartilham entre si o mesmo `libflutter_engine.so`. Com A, o que se
duplica no sistema inteiro é **uma** cópia das páginas do core que as duas pilhas tocam — no máximo ~4,5 MB de código
e ~1,6 MB de dados somente leitura —, qualquer que seja o número de apps. B e C eliminam essa cópia; nenhuma opção
ganha mais que isso.

## O que atravessa a fronteira

Símbolos que os 622 objetos do lado Dart importam dos 2840 do core (`nm -u` contra os definidos):

| Origem | Símbolos | Observação |
|---|---:|---|
| `libc++` (`std::`) | ~85 | estática em cada `.so`, com visibilidade oculta |
| BoringSSL (`SSL_`, `X509_`, `BIO_`…) | ~95 | usada pelo `dart:io` |
| ICU | 31 | |
| Skia/Ganesh (`Sk*`, `Gr*`) | ~12 | partes da `embedder.cc` |
| `fml::` | 58 | mapeamentos, `MessageLoop`, `TaskRunner`, tracing, log |
| `flutter::` | 67 (28 classes) | `RunConfiguration`, `TaskRunners`, `Settings`, `Engine`, `Shell`, `SpiRuntimeBackend`, `AssetManager`, `PlatformMessage`… |
| API C `FlutterCore*` | ~20 | já é fronteira C estável |
| **total** | **408** | |

O C++ do engine (`fml::` e `flutter::`) é usado por uns 12 arquivos de cola: `flutter_dart_runtime.cc`,
`engine_dart.cc`, `runtime_controller.cc`, `dart_isolate.cc`, `embedder.cc`, `dart_runtime_backend_factory.cc`,
`run_configuration_dart.cc`, `platform_configuration.cc`, `ui_dart_state.cc` e afins. É eles que montam o engine em
C++ e ligam o isolate ao `MessageLoop` da thread da UI.

## As opções

### A — dois artefatos alternativos (hoje)

Sem custo. A duplicação está medida acima. Mantém a `embedder.h` e o caminho Dart intactos e os dois artefatos
verificáveis em separado (`assert_no_deps`, `readelf`, o triângulo em C).

### B — `DT_NEEDED` com C++ exportado

O core exportaria `flutter::*` e `fml::*` (um *version script* com `extern "C++"` faz isso com pouco texto), e os alvos
Dart passariam a depender do `.so` do core em vez dos `source_set`/`static_library` dele. Custos:

- **Grafo GN:** hoje os alvos Dart linkam estaticamente os mesmos alvos do core; seria preciso um alvo "core como
  biblioteca compartilhada" e tirar o core do link do `.so` Dart sem deixar cópias de `fml`/Skia (o motivo da decisão
  da S5b-2).
- **`libc++`:** cada `.so` tem a sua cópia estática e oculta; as classes que atravessam a fronteira carregam
  `std::string`, `std::function` e `std::shared_ptr`. Com duas cópias isso funciona por acaso (mesmo build), não por
  contrato. O certo é uma `libc++` só: exportada pelo core ou como `.so` próprio.
- **Superfície exportada:** de 36 funções `FlutterCore*` para milhares de símbolos C++, com tabela dinâmica maior,
  mais relocações no carregamento e perda das otimizações que a visibilidade oculta permite.
- **BoringSSL, ICU e Skia** usados pelo lado Dart: ou o core os exporta também, ou o `.so` Dart guarda cópias próprias
  (ICU tem dados carregados uma vez por cópia).
- Os dois `.so` viram um **par casado**: só funcionam juntos, do mesmo build. É aceitável (sempre saem juntos), mas a
  fronteira deixa de ser uma ABI.

### C — fronteira só em C

O `.so` Dart vira um runtime do SPI, como o Rust: sobe o engine por `FlutterCore*` e fala com ele só pelas tabelas, com
um `fml` próprio para as threads da VM. Boa parte do que a cola usa já tem par em C: subir o engine
(`FlutterCoreHostArgs` + `FlutterCoreEngineRun`), assets (`asset_get`, `asset_read`), tracing (`FlutterCoreTrace*`),
tarefas (`post_task`). Faltariam ganchos para o que liga o isolate ao `MessageLoop` da UI (microtasks depois de cada
tarefa, rodar tarefas vencidas), e a `embedder.h` inteira passaria a ser traduzida sobre `FlutterCore*`. Custos: alto —
a cola de ~12 arquivos e a `embedder.cc` reescritas, com risco de paridade no caminho que hoje é o oráculo. Ganho além
da memória: a prova de que o SPI basta para o próprio Dart, e um só core para verificar. A S5b-2 rejeitou esta opção
por acrescentar uma ponte no caminho de host; os números acima não mudam esse balanço enquanto não houver apps Rust.

### D — `fml` e `libc++` como `.so` próprios

Resolve a duplicação de `libc++` de B, mas não as 28 classes `flutter::` que a cola usa; acrescenta dois artefatos e uma
ABI de suporte. Rejeitada na S5b-2 e continua sem vantagem própria.

## Recomendação e gatilho

Ficar com **A**. O teto do ganho é uma cópia do core no sistema (~6 MB de RAM, ~13 MB de disco em release), e só existe
quando apps Dart e Rust rodam juntos; hoje todos os apps do TitanDM (shell, greeter, lock, settings, polkit, files,
terminal, portal) são Dart.

**Gatilho para reabrir:** o primeiro app da trilha `flutter-rs` instalado por padrão junto do shell Dart, ou um alvo
pequeno (ARM 32-bit, RISC-V) em que ~6 MB de RAM pesem. Se reabrir, preferir **C**: segue o objetivo do ADR-0027 (o
Dart como mais um runtime sobre o core) e evita a ABI C++ implícita de B.

**Preparação barata, compatível com A:** quando a cola do caminho Dart for tocada por outro motivo, trocar o uso de C++
do core pelo par em C que já existe (`asset_get` no lugar de `AssetManager`, `FlutterCoreTrace*` no lugar de
`fml::tracing`), para que o custo de C diminua com o tempo.

## Achado à parte

`build-engine.sh --mode release` (e `profile`) no host termina com `ninja: error: unknown target
'flutter/shell/common:gen_snapshot'`: esse alvo não existe nem no upstream de base. O `gen_snapshot` copiado está em
`//flutter:gen_snapshot` (`BUILD.gn` da raiz do engine). As bibliotecas saem; falha o passo seguinte. Fica para a S6,
que produz os artefatos release.

## Método

- Entradas de link: `ninja -t query libflutter_engine{,_core}.so` em `out/host_debug`.
- Símbolos: `nm -u` dos objetos só do Dart contra `nm --defined-only --extern-only` dos comuns; agrupamento por
  `c++filt`.
- Residência: `smaps` lido com o processo parado em `FlutterCoreEngineShutdown` (gdb) para os dois programas do core, e
  12 s depois de o app Dart abrir no `titan-compositor --backend virtual` para o runner.
- Tamanhos: `size -A` em `out/host_debug` e `out/host_release` (build da série de 175 patches).
