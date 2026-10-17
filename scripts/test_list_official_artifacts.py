#!/usr/bin/env python3
"""Tests for the official Flutter engine artifact inventory."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("list-official-artifacts.py")


class ListOfficialArtifactsTest(unittest.TestCase):
    def test_lists_cache_artifacts_with_builder_hosts_and_maven_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            fixture_root = Path(temporary_directory)
            cache_path = fixture_root / "flutter_cache.dart"
            builders_path = fixture_root / "builders"
            maven_path = fixture_root / "resolve_dependencies.gradle.kts"
            output_path = fixture_root / "official-artifacts.txt"

            cache_path.write_text(
                """
const _binaryDirs = <List<String>>[
  <String>['common', 'flutter_patched_sdk.zip'],
  <String>['linux-x64', 'linux-x64/artifacts.zip'],
  <String>['linux-$arch', 'linux-$arch/font-subset.zip'],
  <String>['android-arm-profile/linux-x64', 'android-arm-profile/linux-x64.zip'],
  <String>['ios', 'ios/artifacts.zip'],
];
List<String> getPackageDirs() => const <String>['sky_engine', 'flutter_gpu'];
const webArchive = 'flutter-web-sdk.zip';
""",
                encoding="utf-8",
            )
            builders_path.mkdir()
            (builders_path / "linux_host_engine.json").write_text(
                '{"archives": [{"include_paths": ["out/host/zip_archives/flutter_patched_sdk.zip", "out/host/zip_archives/linux-x64/artifacts.zip", "out/host/zip_archives/linux-x64/font-subset.zip", "out/host/zip_archives/linux-arm64/font-subset.zip", "out/host/zip_archives/android-arm-profile/linux-x64.zip"]}]}',
                encoding="utf-8",
            )
            (builders_path / "mac_ios_engine.json").write_text(
                '{"archives": [{"include_paths": ["out/ios/zip_archives/ios/artifacts.zip"]}]}',
                encoding="utf-8",
            )
            maven_path.write_text(
                '"flutterRelease"("io.flutter:flutter_embedding_release:1.0.0-$engineVersion")\n',
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--flutter-cache",
                    str(cache_path),
                    "--builders",
                    str(builders_path),
                    "--maven-script",
                    str(maven_path),
                    "--output",
                    str(output_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                output_path.read_text(encoding="utf-8").splitlines(),
                sorted(
                    [
                        "linux-x64\tandroid-arm-profile/linux-x64.zip",
                        "linux-x64\tflutter_patched_sdk.zip",
                        "linux-x64\tlinux-x64/artifacts.zip",
                        "linux-x64\tlinux-arm64/font-subset.zip",
                        "linux-x64\tlinux-x64/font-subset.zip",
                        "linux-x64\tflutter-web-sdk.zip",
                        "macos\tios/artifacts.zip",
                        "linux-x64\tsky_engine.zip",
                        "linux-x64\tflutter_gpu.zip",
                        "linux-x64\tandroid-maven/io.flutter/flutter_embedding_release/1.0.0-{engine-version}/flutter_embedding_release-1.0.0-{engine-version}.pom",
                        "linux-x64\tandroid-maven/io.flutter/flutter_embedding_release/1.0.0-{engine-version}/flutter_embedding_release-1.0.0-{engine-version}.aar",
                    ]
                ),
            )


if __name__ == "__main__":
    unittest.main()
