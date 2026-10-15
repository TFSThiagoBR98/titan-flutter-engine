# Changelog

All notable changes to `titan-flutter-engine` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Self-hosted GitHub Actions workflow for x64, ARM hard-float, ARM soft-float
  with glibc, and ARM soft-float with musl.
- Documentation for cross-compilation, QEMU validation, the platform matrix
  (`docs/plataformas.md`) and the runtime-neutral SPI study for a Dart-free
  engine.
- `scripts/build-matrix.sh` builds several engine variants in parallel, each in
  its own output directory.

### Changed

- Engine patches are organized by concern (`linux-target-matrix`,
  `linux-compiler-runtime`, `linux-musl`) and cover every planned target; the
  whole series always applies, with each patch limited to its targets in GN.
- Debug and profile builds no longer use LTO.

- Buildroot sysroots and QEMU probes are generated and checked in the same CI
  pipeline that publishes engine bundles.
