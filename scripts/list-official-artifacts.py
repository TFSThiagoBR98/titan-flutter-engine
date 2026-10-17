#!/usr/bin/env python3
"""List the engine artifacts downloaded by the pinned Flutter tool."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


ENGINE_VERSION_PLACEHOLDER = "{engine-version}"
DEFAULT_HOST = "linux-x64"
IGNORED_BUILDER_MARKERS = ("_test", "clang_tidy", "unopt", "standalone")
PAIR_PATTERN = re.compile(
    r"\[\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+\.zip)['\"]\s*\]"
)
PACKAGE_DIRS_PATTERN = re.compile(
    r"getPackageDirs\(\).*?\[(?P<items>.*?)\]", re.DOTALL
)
PACKAGE_NAME_PATTERN = re.compile(r"['\"]([^'\"]+)['\"]")
MAVEN_DEPENDENCY_PATTERN = re.compile(
    r"io\.flutter:([A-Za-z0-9_]+):1\.0\.0-\$engineVersion"
)


@dataclass(frozen=True)
class Artifact:
    """An artifact path and the host that produces it."""

    host: str
    path: str


def add_artifact(artifacts: dict[str, Artifact], host: str, path: str) -> None:
    normalized_path = path.strip().lstrip("/")
    if not normalized_path.endswith((".aar", ".pom", ".zip")):
        return
    artifact = Artifact(host=host, path=normalized_path)
    existing = artifacts.get(normalized_path)
    if existing is not None and existing.host != host:
        raise ValueError(
            f"artifact {normalized_path!r} has conflicting producers: "
            f"{existing.host} and {host}"
        )
    artifacts[normalized_path] = artifact


def host_for_builder(builder_path: Path) -> str:
    builder_name = builder_path.stem
    if builder_name.startswith("mac_"):
        return "macos"
    if builder_name.startswith("windows_"):
        return "windows"
    return DEFAULT_HOST


def collect_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from collect_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from collect_strings(item)


def builder_artifacts(builders_directory: Path) -> dict[str, str]:
    paths: dict[str, str] = {}
    for builder_path in sorted(builders_directory.rglob("*.json")):
        if any(marker in builder_path.name for marker in IGNORED_BUILDER_MARKERS):
            continue
        document = json.loads(builder_path.read_text(encoding="utf-8"))
        host = host_for_builder(builder_path)
        for candidate in collect_strings(document):
            if ".zip" not in candidate:
                continue
            if "zip_archives/" in candidate:
                candidate = candidate.split("zip_archives/", 1)[1]
            if candidate.endswith(".zip"):
                paths[candidate] = host
    return paths


def cache_artifacts(cache_source: str) -> list[str]:
    paths = [match.group(2) for match in PAIR_PATTERN.finditer(cache_source)]
    for package_block in PACKAGE_DIRS_PATTERN.finditer(cache_source):
        paths.extend(
            f"{package_name}.zip"
            for package_name in PACKAGE_NAME_PATTERN.findall(package_block.group("items"))
        )
    if "flutter-web-sdk.zip" in cache_source:
        paths.append("flutter-web-sdk.zip")
    return list(dict.fromkeys(paths))


def expand_cache_path(path: str, builder_paths: Iterable[str]) -> list[str]:
    if "$" not in path:
        return [path]
    pattern = re.escape(path)
    for variable in ("arch", "artifactName"):
        pattern = pattern.replace(re.escape(f"${variable}"), r"[^/]+")
    matches = sorted(candidate for candidate in builder_paths if re.fullmatch(pattern, candidate))
    if not matches:
        raise ValueError(f"could not expand cache artifact template: {path}")
    return matches


def maven_artifacts(maven_source: str) -> list[str]:
    paths: list[str] = []
    for artifact_name in dict.fromkeys(MAVEN_DEPENDENCY_PATTERN.findall(maven_source)):
        version = f"1.0.0-{ENGINE_VERSION_PLACEHOLDER}"
        base_path = f"android-maven/io.flutter/{artifact_name}/{version}"
        file_prefix = f"{artifact_name}-{version}"
        paths.extend((f"{base_path}/{file_prefix}.pom", f"{base_path}/{file_prefix}.aar"))
    return paths


def build_inventory(
    cache_path: Path, builders_path: Path, maven_path: Path
) -> list[Artifact]:
    builder_hosts = builder_artifacts(builders_path)
    artifacts: dict[str, Artifact] = {}
    cache_source = cache_path.read_text(encoding="utf-8")
    for template in cache_artifacts(cache_source):
        for path in expand_cache_path(template, builder_hosts):
            add_artifact(artifacts, builder_hosts.get(path, DEFAULT_HOST), path)
    for path in maven_artifacts(maven_path.read_text(encoding="utf-8")):
        add_artifact(artifacts, DEFAULT_HOST, path)
    return sorted(artifacts.values(), key=lambda artifact: (artifact.host, artifact.path))


def default_paths() -> tuple[Path, Path, Path]:
    project_root = Path(__file__).resolve().parents[3]
    flutter_root = project_root / ".build_flutter" / "flutter-tools-src"
    return (
        flutter_root / "packages/flutter_tools/lib/src/flutter_cache.dart",
        flutter_root / "engine/src/flutter/ci/builders",
        flutter_root / "packages/flutter_tools/gradle/resolve_dependencies.gradle.kts",
    )


def main() -> int:
    default_cache, default_builders, default_maven = default_paths()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-cache", type=Path, default=default_cache)
    parser.add_argument("--builders", type=Path, default=default_builders)
    parser.add_argument("--maven-script", type=Path, default=default_maven)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "sdk/official-artifacts.txt",
    )
    arguments = parser.parse_args()

    inventory = build_inventory(
        arguments.flutter_cache,
        arguments.builders,
        arguments.maven_script,
    )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        "".join(f"{artifact.host}\t{artifact.path}\n" for artifact in inventory),
        encoding="utf-8",
    )
    print(f"wrote {len(inventory)} artifacts to {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
