#!/usr/bin/env python3
"""Build a Debian cross-compilation sysroot without requiring root."""

from __future__ import annotations

import argparse
import hashlib
import lzma
import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from urllib.error import HTTPError
from urllib.parse import quote


BASE_PACKAGES = (
    "libc6-dev",
    "linux-libc-dev",
    "libgcc-10-dev",
    "libstdc++-10-dev",
    "libx11-dev",
    "libgtk-3-dev",
    "libegl1-mesa-dev",
    "libepoxy-dev",
    "libwayland-dev",
)


@dataclass(frozen=True)
class Package:
    name: str
    version: str
    architecture: str
    filename: str
    sha256: str
    depends: tuple[tuple[str, ...], ...]
    provides: tuple[tuple[str, ...], ...]


def parse_packages(contents: str) -> dict[str, Package]:
    packages: dict[str, Package] = {}
    for stanza in re.split(r"\n\s*\n", contents.strip()):
        fields: dict[str, str] = {}
        current_field = ""
        for line in stanza.splitlines():
            if line.startswith((" ", "\t")) and current_field:
                fields[current_field] += " " + line.strip()
                continue
            if ":" not in line:
                continue
            current_field, value = line.split(":", 1)
            fields[current_field] = value.strip()

        required = ("Package", "Version", "Architecture", "Filename", "SHA256")
        if any(field not in fields for field in required):
            continue
        if fields["Architecture"] not in {"all", "armel"}:
            continue
        packages[fields["Package"]] = Package(
            name=fields["Package"],
            version=fields["Version"],
            architecture=fields["Architecture"],
            filename=fields["Filename"],
            sha256=fields["SHA256"],
            depends=tuple(_dependency_names(fields.get("Depends", ""))),
            provides=tuple(_dependency_names(fields.get("Provides", ""))),
        )
    return packages


def _dependency_names(value: str) -> list[tuple[str, ...]]:
    dependencies: list[tuple[str, ...]] = []
    for dependency in value.split(","):
        alternatives: list[str] = []
        for candidate in dependency.split("|"):
            package = candidate.strip()
            package = re.sub(r"\s*\([^)]*\)", "", package)
            package = package.split(":", 1)[0]
            if package:
                alternatives.append(package)
        if not alternatives:
            continue
        dependencies.append(tuple(alternatives))
    return dependencies


def resolve_dependencies(
    packages: dict[str, Package], roots: Iterable[str]
) -> dict[str, Package]:
    resolved: dict[str, Package] = {}
    providers = {
        provided: package.name
        for package in packages.values()
        for alternatives in package.provides
        for provided in alternatives
    }
    pending = list(roots)
    while pending:
        name = pending.pop(0)
        if name in resolved:
            continue
        package = packages.get(name)
        if package is None:
            raise RuntimeError(f"package is missing from Packages index: {name}")
        resolved[name] = package
        for alternatives in package.depends:
            dependency = next(
                (
                    packages.get(candidate, packages.get(providers.get(candidate, "")))
                    for candidate in alternatives
                    if candidate in packages or candidate in providers
                ),
                None,
            )
            if dependency is None:
                joined = " | ".join(alternatives)
                raise RuntimeError(f"dependency is missing from Packages index: {joined}")
            pending.append(dependency.name)
    return resolved


def rewrite_absolute_symlinks(sysroot: Path) -> int:
    rewritten = 0
    for path in _paths(sysroot):
        if not path.is_symlink():
            continue
        target = os.readlink(path)
        if not target.startswith("/"):
            continue
        target_path = sysroot / target.lstrip("/")
        relative_target = os.path.relpath(target_path, path.parent)
        path.unlink()
        path.symlink_to(relative_target)
        rewritten += 1
    return rewritten


def _paths(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        yield path


def _download(url: str, destination: Path) -> None:
    with urllib.request.urlopen(url) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output)


def _download_package(
    package: Package, base_url: str, destination: Path
) -> None:
    package_path = package.filename
    security_path = package_path.replace("pool/main/", "pool/updates/main/", 1)
    candidates = (
        (base_url, package_path),
        (base_url, quote(package_path, safe="/")),
        (
            "https://snapshot.debian.org/archive/debian/20240707T211122Z",
            package_path,
        ),
        (
            "https://snapshot.debian.org/archive/debian/20240707T211122Z",
            quote(package_path, safe="/"),
        ),
        (
            "https://snapshot.debian.org/archive/debian-security/20240705T211620Z",
            security_path,
        ),
        (
            "https://snapshot.debian.org/archive/debian-security/20240705T211620Z",
            quote(security_path, safe="/"),
        ),
    )
    for candidate_base, candidate_path in candidates:
        try:
            _download(f"{candidate_base}/{candidate_path}", destination)
            return
        except HTTPError:
            continue
    raise RuntimeError(f"package is unavailable from Debian archives: {package.name}")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _release_sha256(release: str, relative_path: str) -> tuple[str, int]:
    in_sha256 = False
    for line in release.splitlines():
        if line == "SHA256:":
            in_sha256 = True
            continue
        if in_sha256 and line and not line.startswith(" "):
            break
        if in_sha256:
            fields = line.split()
            if len(fields) == 3 and fields[2] == relative_path:
                return fields[0], int(fields[1])
    raise RuntimeError(f"Release has no SHA256 entry for {relative_path}")


def _load_index(
    suite: str, architecture: str, directory: Path
) -> tuple[dict[str, Package], str]:
    relative_path = f"main/binary-{architecture}/Packages.xz"
    bases = (
        f"https://deb.debian.org/debian/dists/{suite}",
        f"https://archive.debian.org/debian/dists/{suite}",
    )
    for base_url in bases:
        release_path = directory / "Release"
        index_path = directory / "Packages.xz"
        try:
            _download(f"{base_url}/Release", release_path)
            expected_hash, expected_size = _release_sha256(
                release_path.read_text(encoding="utf-8"), relative_path
            )
            _download(f"{base_url}/{relative_path}", index_path)
        except (HTTPError, RuntimeError):
            continue
        if index_path.stat().st_size != expected_size:
            raise RuntimeError("Packages index size does not match Release")
        if _sha256(index_path) != expected_hash:
            raise RuntimeError("Packages index SHA-256 does not match Release")
        contents = lzma.decompress(index_path.read_bytes()).decode("utf-8")
        return parse_packages(contents), base_url.rsplit("/dists/", 1)[0]
    raise RuntimeError(
        f"no verified Packages index for {suite}/{architecture} on Debian mirrors"
    )


def build_sysroot(architecture: str, suite: str, output: Path) -> None:
    if architecture != "armel":
        raise ValueError("this generator currently supports only --arch armel")
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="titan-debian-sysroot-") as temporary:
        download_directory = Path(temporary)
        packages, base_url = _load_index(suite, architecture, download_directory)
        selected = resolve_dependencies(packages, BASE_PACKAGES)
        for package in selected.values():
            archive = download_directory / Path(package.filename).name
            _download_package(package, base_url, archive)
            if _sha256(archive) != package.sha256:
                raise RuntimeError(f"SHA-256 mismatch for {package.name}")
            subprocess.run(
                ["dpkg-deb", "-x", str(archive), str(output)],
                check=True,
            )
    rewrite_absolute_symlinks(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--arch", default="armel")
    parser.add_argument("--suite", default="bullseye")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("engine/src/build/linux/debian_bullseye_armel-sysroot"),
    )
    arguments = parser.parse_args()
    build_sysroot(arguments.arch, arguments.suite, arguments.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
