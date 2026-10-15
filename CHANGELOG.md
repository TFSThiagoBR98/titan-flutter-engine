# Changelog

All notable changes to `titan-flutter-engine` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Self-hosted GitHub Actions workflow for x64, ARM hard-float, ARM soft-float
  with glibc, and ARM soft-float with musl.
- Documentation for cross-compilation, QEMU validation, and the future Dart
  dependency study.

### Changed

- Buildroot sysroots and QEMU probes are generated and checked in the same CI
  pipeline that publishes engine bundles.
