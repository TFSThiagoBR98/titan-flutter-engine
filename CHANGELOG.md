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
