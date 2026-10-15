#!/usr/bin/env python3
"""Parse the feature patch series used by build-engine.sh."""

from __future__ import annotations

import argparse
from pathlib import Path
import shlex
from collections.abc import Iterable


def collect_patch_paths(patch_paths: Iterable[Path]) -> list[str]:
    """Return every repository path touched by the supplied patch files."""
    collected: list[str] = []
    seen: set[str] = set()
    for patch_path in patch_paths:
        for line_number, line in enumerate(
            patch_path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if not line.startswith("diff --git "):
                continue
            fields = shlex.split(line[len("diff --git ") :])
            if len(fields) != 2:
                raise ValueError(
                    f"invalid diff header in {patch_path} on line {line_number}"
                )
            for field, prefix in zip(fields, ("a/", "b/")):
                if field == "/dev/null":
                    continue
                if not field.startswith(prefix):
                    raise ValueError(
                        f"invalid diff path in {patch_path} on line {line_number}: {field}"
                    )
                path = field[len(prefix) :]
                if not path or path.startswith("/") or ".." in Path(path).parts:
                    raise ValueError(
                        f"invalid repository path in {patch_path} on line {line_number}: {path}"
                    )
                if path not in seen:
                    seen.add(path)
                    collected.append(path)
    return collected


def parse_series(series: str, *, cpu: str, libc: str) -> list[str]:
    """Return feature directories whose conditions match the target."""
    selected: list[str] = []
    for line_number, line in enumerate(series.splitlines(), start=1):
        fields = line.split("#", 1)[0].split()
        if not fields:
            continue
        folder, *conditions = fields
        if "/" in folder or folder in {".", ".."}:
            raise ValueError(f"invalid patch folder on line {line_number}: {folder}")
        values = {"cpu": cpu, "libc": libc}
        for condition in conditions:
            key, separator, value = condition.partition("=")
            if not separator or key not in values:
                raise ValueError(
                    f"invalid patch condition on line {line_number}: {condition}"
                )
            if values[key] != value:
                break
        else:
            selected.append(folder)
    return selected


def parse_all_series(series: str) -> list[str]:
    """Return every valid feature directory, preserving legacy conditions."""
    selected: list[str] = []
    for line_number, line in enumerate(series.splitlines(), start=1):
        fields = line.split("#", 1)[0].split()
        if not fields:
            continue
        folder, *conditions = fields
        if "/" in folder or folder in {".", ".."}:
            raise ValueError(f"invalid patch folder on line {line_number}: {folder}")
        for condition in conditions:
            key, separator, _ = condition.partition("=")
            if not separator or key not in {"cpu", "libc"}:
                raise ValueError(
                    f"invalid patch condition on line {line_number}: {condition}"
                )
        selected.append(folder)
    return selected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--series", type=Path)
    parser.add_argument("--cpu")
    parser.add_argument("--libc", default="glibc")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--patch-root", type=Path)
    parser.add_argument("--paths", action="store_true")
    arguments = parser.parse_args()
    if arguments.paths:
        if arguments.patch_root is None:
            parser.error("--paths requires --patch-root")
        for path in collect_patch_paths(
            sorted(arguments.patch_root.rglob("*.patch"))
        ):
            print(path)
        return 0
    if arguments.all:
        if arguments.series is None:
            parser.error("--all requires --series")
        for folder in parse_all_series(arguments.series.read_text(encoding="utf-8")):
            print(folder)
        return 0
    if arguments.series is None or arguments.cpu is None:
        parser.error("--series and --cpu are required unless --paths is used")
    for folder in parse_series(
        arguments.series.read_text(encoding="utf-8"),
        cpu=arguments.cpu,
        libc=arguments.libc,
    ):
        print(folder)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
