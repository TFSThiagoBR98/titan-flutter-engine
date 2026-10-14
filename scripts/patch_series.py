#!/usr/bin/env python3
"""Parse the feature patch series used by build-engine.sh."""

from __future__ import annotations

import argparse
from pathlib import Path


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--series", type=Path, required=True)
    parser.add_argument("--cpu", required=True)
    parser.add_argument("--libc", default="glibc")
    arguments = parser.parse_args()
    for folder in parse_series(
        arguments.series.read_text(encoding="utf-8"),
        cpu=arguments.cpu,
        libc=arguments.libc,
    ):
        print(folder)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
