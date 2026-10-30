# Changelog

All notable changes to `titan-flutter-engine` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `scripts/build-engine.sh --unittests` builds the engine gtests and benchmarks;
  `scripts/run-engine-tests.sh` runs them from `engine/src` against a list of known failures.
- `scripts/patch-branch.sh` keeps a patch folder as commits in a worktree of the Flutter checkout and exports
  them back (`prepare`/`export`); the `runtime-spi` folder is maintained this way.
- `scripts/measure-dart-footprint.sh` reports the Dart share of an unstripped engine library (VM code, snapshots
  and kernel).
- Patch folder `runtime-spi` (S1): Dart-free `lib/ui` data types, pluggable `fml` tracing, a `RuntimeBackend`
  interface between the engine and its runtime, and a shell created through a runtime backend factory. Dart apps
  render the same frame as before (probe hash unchanged on x64 and arm64-musl).
- Runtime SPI S2: versioned C11 ABI, pure-C conformance runtime, frame and
  message ownership rules, and validation of the x64, arm64-musl and 32-bit
  layout paths.
- Runtime SPI S3a: scene API for paths, paints, picture recording, canvas
  operations, scene layers and canonical scene tracing, with end-to-end
  conformance tests and an ABI-versus-direct-builder benchmark.
- Runtime SPI S3b-1: text styles, dynamic font loading, paragraph layout and
  metrics, UTF-16 text queries, paragraph drawing, and end-to-end conformance
  tests.
- Runtime SPI S3b-2: ABI C11 de imagens, handles e operações de desenho,
  decodificação assíncrona e testes de conformidade ponta a ponta.
- Runtime SPI S3b-3: API ABI 0.5 para transformar pictures e cenas em imagens,
  ler pixels e PNGs, decodificar codecs quadro a quadro e validar o caminho de
  saída de imagens ponta a ponta.
- Runtime SPI S3b-4a: ABI 0.6 para shaders, filtros de cor e imagem, máscara de
  blur e vertices, com pintura e conformidade ponta a ponta sem Dart.
- Runtime SPI S3b-4b: ABI 0.7 para as camadas restantes do scene builder (color filter, image filter, backdrop,
  shader mask, clip de superelipse, textura, platform view e performance overlay), camadas retidas entre quadros e
  blur com tile mode dinâmico e bounds, com conformidade ponta a ponta sem Dart.
- Runtime SPI S3b-4c: ABI 0.8 para fragment programs (runtime effects do impellerc) carregados de asset ou bytes, com uniforms, samplers e
  conversão em shader de paint ou image filter, sem Dart.
- Runtime SPI S3b-5: ABI 0.9 para publicar a árvore de semântica (nós, flags, textos com atributos, transformações, filhos e ações
  customizadas) de uma view, com o mesmo resultado do SemanticsUpdateBuilder do dart:ui e sem Dart.
- Runtime SPI S4c-1: ABI 0.12 com o contrato completo entre o engine e o runtime
  (telas, tempos de quadro, hit test, rota inicial, locale, deferred libraries, foco, assets e demais pedidos do
  runtime ao engine).
- Runtime SPI S4g-2: `Image`, `Picture.toImage`, `Scene.toImage` e `ImageShader` do `dart:ui` passam a usar handles da
  API de imagens do SPI; a ABI 0.20 acrescenta criação síncrona de imagens de pixels, espaço de cor e formato de
  snapshot, enquanto codecs, descriptors, buffers, fragment programs e assets permanecem para a S4g-3.
- Runtime SPI S4g-3: `ImageDescriptor`, `Codec`, `ImmutableBuffer.fromAsset` e os fragment shaders do `dart:ui` passam a usar o SPI; a ABI 0.21 acrescenta descriptors de imagem, leitura de assets, validação de shaders e o formato de pixel de destino nas opções de decodificação; `codec_release` deixa de descartar quadros já pedidos.
- Runtime SPI S4h-1: a semântica do `dart:ui` (`SemanticsUpdateBuilder`, `SemanticsUpdate`, `updateSemantics`) passa a usar o SPI; o release de um builder de semântica vale depois de o engine ser destruído; o SPI valida UTF-8 sem o ICU.
- Runtime SPI S4h-2: platform messages de isolates de fundo passam pelo SPI (ABI 0.22, sender seguro em qualquer thread); um envio de isolate de fundo sem handler volta a lançar a exceção no Dart em vez de derrubar o isolate.
- Runtime SPI S4i-1: o `dart:ui` passa a ler a ABI do SPI por um acessor único, instalado pelo runtime Dart, em vez de funções C++ do core.
- Runtime SPI S4i-2: os últimos natives do `dart:ui` passam a usar só a ABI pública do SPI (exceto a ponte do `flutter_gpu`, até a S7); a ABI 0.23 acrescenta `path_set_volatile`; código do `dart:ui` sem uso desde a migração é removido.
- Runtime SPI S4i-3a: o alvo Dart do `dart:ui` deixa de conter código do core (fontes, imagens diferidas, ponte do `flutter_gpu` em alvos próprios) e de expor tipos do core nas assinaturas dos natives; a ABI 0.24 acrescenta `rsuperellipse_contains`.
- Runtime SPI S4i-3b: o alvo Dart do `dart:ui` só vê o core pela ABI C do SPI, com `assert_no_deps` no GN (exceções do `flutter_gpu` até a S7); corrigido o formato de pixel de `ImageDescriptor.raw`/`decodeImageFromPixels`, que trocava vermelho e azul em RGBA desde a migração dos codecs.
- Runtime SPI S5a: o alvo do core `shell/common:common` deixa de conter e de depender de Dart, com `assert_no_deps` no GN; o código Dart do shell vai para `shell/common:dart`; corrigido um teste instável da leitura de assets no worker.
- Runtime SPI S5b-1: host API do core (`flutter_core_host.h`, funções `FlutterCore*`) sem Dart, num alvo próprio com `assert_no_deps`; a Embedder API (`embedder.h`) continua igual e passa a traduzir para ela.
- Runtime SPI S5b-2: o build gera também o `libflutter_engine_core.so`, só com o core e a host API (`FlutterCore*`), como artefato alternativo ao `libflutter_engine.so`.
- Runtime SPI S5c: prova no artefato de que o `libflutter_engine_core.so` não tem Dart, build só do core (`--runtime none`, arg GN `titan_flutter_runtime_dart`) e um programa C que roda um runtime SPI só com o core.
- Runtime SPI S5.5a: busca de handles sem trava e cache de paint sem alocação no miss (quadro composto −1,7%).
- Runtime SPI S5.5b: atualização de semântica sem nó temporário nem vetores por nó (quadro de semântica −3,2%).
- Runtime SPI S5.5c: texto e codecs remedidos; a camada SPI custa ≤ 1% do quadro de texto e nenhum salto de tarefa extra sobrou nos codecs.
- Runtime SPI S5.5d: série `runtime-spi` reorganizada (270 → 153 patches; correções, testes vermelhos e otimizações juntados ao commit de origem; árvore final idêntica).
- Runtime SPI S5.5e: diagnóstico com símbolos (texto: pressão de cache de instruções, não a camada SPI; codecs: tabela de tipos canônicos da VM) e codec estático sem handle de imagem intermediário.
- Runtime SPI S7-0: `flutter_tester` volta a compilar sobre o SPI; `gpu_unittests` e `gpu_test.dart` (Impeller em Vulkan) no check; benchmark `BM_DartGpuFrame`.
- Runtime SPI S7a: tabela `FlutterSpiGpuApi` (ABI do SPI 0.25) para contexto, buffers e texturas do `flutter_gpu`; o `lib/gpu` guarda handles do SPI nesses três objetos.
- Runtime SPI S7b: shader libraries, shaders, render pipelines e binding sets do `flutter_gpu` pela `FlutterSpiGpuApi` (ABI do SPI 0.26); a lógica e os testes deles passam para o core.
- Builds completos em ARM 32-bit voltam a compilar: conversões explícitas de ids de display e de campos de reflexão de shader de 64 bits para `size_t`.
- Runtime SPI S7c-1: command buffers, render passes e image surfaces do `flutter_gpu` pela `FlutterSpiGpuApi` (ABI do SPI 0.27); o `gpu_unittests` deixa de existir e os testes dele rodam no `runtime_spi_unittests`.

### Fixed

- `LICENSE` holds the unmodified Apache 2.0 text, so GitHub detects it; the
  copyright and the note on Flutter's BSD-3-Clause patches moved to `NOTICE`.

## [0.1.0] - 2026-10-15

### Added

- Runtime SPI S1: branch-based patch workflow, on-demand engine tests and Dart
  footprint measurements, plus the Dart-free type, tracing, runtime backend
  and shell factory seams with their baseline reports.
- Flutter SDK host artifacts (Linux x64): the same zips the `flutter` tool
  downloads, built from the patched engine (including the GTK shell,
  `sky_engine` and `flutter_gpu`), assembled in the official storage layout
  with `engine_stamp.json` and a `MANIFEST`, and installed through
  `flutter precache` from a local server (`scripts/assemble-sdk-artifacts.sh`,
  `scripts/install-sdk-artifacts.sh`).

- GitHub Actions workflow on hosted `ubuntu-24.04` runners, with one matrix
  job per engine variant and sysroots published through `sysroots-cache`.
- Documentation for cross-compilation, QEMU validation, the platform matrix
  (`docs/plataformas.md`) and the runtime-neutral SPI study for a Dart-free
  engine.
- `scripts/build-matrix.sh` builds several engine variants in parallel, each in
  its own output directory.
- Linux platform matrix for x86_64, armv7-a, arm64, riscv32 and riscv64, with
  glibc and musl variants; GN-only configuration and quick checks cover the
  target triples and ELF bundle metadata.
- Patches can target the gclient dependency repositories (SwiftShader, Skia,
  Dart…) with a `# Repo:` header line; each repository is restored to its own
  pinned revision before the series is applied.
- riscv32 Linux engine builds: Marl's generic `ucontext` fibers and LLVM's
  RISC-V sources in SwiftShader, no `analyze_snapshot` for 32-bit targets, and
  the Debian i386 host sysroot installed on demand (Dart needs a 32-bit host
  `gen_snapshot` for riscv32).

### Changed

- Runtime SPI S4c-2: apps Dart passam a rodar pelo SPI (o runtime Dart é um runtime de tabela, como o Rust); ABI 0.13 com warm-up frame (token 0) e lançamento opaco do isolate; ABI 0.14 com resultado de adicionar/remover view, estado "rodando" do runtime e métricas de view completas (restrições, insets de gesto, display features).
- Runtime SPI S4d-1: `Canvas`, `PictureRecorder` e `Picture` do `dart:ui` passam a gravar pela API de cena do SPI; a ABI 0.15 acrescenta operações de superelipse e consultas de transformação e clips, com handles de pintura em cache.
- Runtime SPI S4d-2: `Path` e `PathMeasure` do `dart:ui` passam a usar a API de cena do SPI; a ABI 0.16 acrescenta a geometria de paths, operações derivadas e medidas de contornos sobre `SkPath`.
- Runtime SPI S4e: `SceneBuilder`, `EngineLayer` e `Scene` do `dart:ui` passam a usar a API de cena do SPI; a ABI 0.17 acrescenta `scene_build_root`, `scene_create_from_root` e `scene_retain_last_layer`, e filtros nulos geram camadas de passagem.
- Runtime SPI S4f: `ParagraphBuilder`, `Paragraph` e fontes do `dart:ui` passam a usar a API de texto do SPI; a ABI 0.18 acrescenta as máscaras de estilo ativadas por `kFlutterSpiStyleFieldsMasked`, seis consultas de parágrafo, `add_text_utf16` e `ellipsis_utf16`, corrige a escolha do caminho Impeller nos parágrafos, aceita o domínio de entrada do `txt` (inclusive largura infinita, evitando o abort no primeiro layout) e mantém as tabelas de handles vivas até o fim do processo.
- Runtime SPI S4g-1: `Gradient`, `ColorFilter`, `ImageFilter` e `Vertices` do `dart:ui` passam a ser criados diretamente pela API de efeitos do SPI e mantêm apenas handles; as pontes restantes para `ImageShader`, `FragmentShader` e filtros de imagem de fragment shader ficam para a S4g-2 (ABI 0.19).
- Runtime SPI: tabelas de handles seguras entre threads com um `std::mutex` por tabela; inserções, buscas, retenções, liberações e a contagem de entradas deixam de disputar estruturas sem sincronização, e os destrutores de valores liberados continuam fora da trava.
- Runtime SPI S4b: o Shell deixa de depender da VM do Dart; os handlers do service
  protocol ficam no core e são servidos pelo VM service através da tabela de extensões (ABI 0.11).
- Runtime SPI S4a: o engine chama as funções que só existem com Dart (microtasks, deferred libraries, código de retorno,
  service ID, platform isolates) por uma tabela C opcional de extensões do runtime (ABI 0.10), e não mais por uma
  interface C++.
- riscv32 stays out of the default build and CI matrix; request it by name.
- CI runs on GitHub-hosted runners with a shallow Flutter checkout, ccache in
  `actions/cache`, one variant per job, and releases via `gh`.
- Scripts resolve the work and bundle directories in `scripts/lib/paths.sh`
  (`TITAN_WORK_DIR`, `TITAN_BUNDLE_DIR`), so the repository builds on its own.
- Buildroot is pinned in `buildroot/buildroot.lock` and cloned on demand.
- The QEMU probe uses a self-contained app and requires the same frame hash
  on every target, including a native x64 run.
- The QEMU probe accepts `--target <variant>` for the complete matrix and keeps
  `--abi` as an alias for the four historical targets.

- Engine patches are organized by concern (`linux-target-matrix`,
  `linux-compiler-runtime`, `linux-musl`) and cover every planned target; the
  whole series always applies, with each patch limited to its targets in GN.
- Debug and profile builds no longer use LTO.

- Buildroot sysroots and QEMU probes are generated and checked in the same CI
  pipeline that publishes engine bundles.
- Buildroot sysroots use a content key and completion stamp, with local and
  GitHub prerelease cache tarballs shared by the host and CI.
- Buildroot and engine builds run within a hard CPU budget controlled by
  `TITAN_JOBS` and the systemd CPU quota when available.

### Fixed

- The QEMU probe frame no longer depends on the host's fonts: the probe app bundles
  its font and hides the DEBUG ribbon (expected hash `9afdbcd18abd9b35`), and
  `PROBE_DUMP_PPM` saves the frame for inspection.
- CI keeps the ccache of a build even when a later step fails.
- x86_64 musl builds: host tools (`flatc`, `impellerc`, `gen_snapshot`) build
  in a separate glibc host toolchain instead of being linked against musl.
- riscv32 engines link `libatomic.so.1` (RV32 has no 64-bit atomic
  instructions).
- The x86_64 musl bundle uses the full `<commit>-debug-x64-musl` name instead of
  `<commit>-musl`.

[Unreleased]: https://github.com/TFSThiagoBR98/titan-flutter-engine/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/TFSThiagoBR98/titan-flutter-engine/releases/tag/v0.1.0
