# Changelog

All notable changes to `titan-flutter-engine` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Flutter SDK host artifacts (Linux x64): the same zips the `flutter` tool
  downloads, built from the patched engine (including the GTK shell,
  `sky_engine` and `flutter_gpu`), assembled in the official storage layout
  with `engine_stamp.json` and a `MANIFEST`, and installed through
  `flutter precache` from a local server (`scripts/assemble-sdk-artifacts.sh`,
  `scripts/install-sdk-artifacts.sh`).

- Self-hosted GitHub Actions workflow for x64, ARM hard-float, ARM soft-float
  with glibc, and ARM soft-float with musl.
- Documentation for cross-compilation, QEMU validation, the platform matrix
  (`docs/plataformas.md`) and the runtime-neutral SPI study for a Dart-free
  engine.
- `scripts/build-matrix.sh` builds several engine variants in parallel, each in
  its own output directory.

### Changed

- CI runs on the Forgejo `docker` runner: one container job calling
  `scripts/ci.sh` stages, a persistent volume for the workspace, and releases
  through the Forgejo API.
- Scripts resolve the work and bundle directories in `scripts/lib/paths.sh`
  (`TITAN_WORK_DIR`, `TITAN_BUNDLE_DIR`), so the repository builds on its own.
- Buildroot is pinned in `buildroot/buildroot.lock` and cloned on demand.
- The QEMU probe uses a self-contained app and requires the same frame hash
  on every target, including a native x64 run.

- Engine patches are organized by concern (`linux-target-matrix`,
  `linux-compiler-runtime`, `linux-musl`) and cover every planned target; the
  whole series always applies, with each patch limited to its targets in GN.
- Debug and profile builds no longer use LTO.

- Buildroot sysroots and QEMU probes are generated and checked in the same CI
  pipeline that publishes engine bundles.
