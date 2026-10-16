#!/usr/bin/env bash
set -euo pipefail

library=${1:-}
if [[ -z "$library" || $# -ne 1 ]]; then
  printf 'Usage: %s <lib.so>\n' "$0" >&2
  exit 2
fi
[[ -f "$library" ]] || {
  printf 'error: shared library does not exist: %s\n' "$library" >&2
  exit 1
}
command -v nm >/dev/null || {
  printf 'error: nm is required\n' >&2
  exit 1
}
command -v readelf >/dev/null || {
  printf 'error: readelf is required\n' >&2
  exit 1
}

python3 - "$library" <<'PY'
import os
import re
import subprocess
import sys

library = sys.argv[1]
sections = subprocess.run(
    ["readelf", "-SW", library],
    check=True,
    capture_output=True,
    text=True,
).stdout
section_pattern = re.compile(
    r"^\s*\[\s*\d+\]\s+(\S+)\s+\S+\s+\S+\s+\S+\s+([0-9A-Fa-f]+)"
)
section_sizes = {".text": 0, ".rodata": 0, ".data": 0}
for line in sections.splitlines():
    match = section_pattern.match(line)
    if match and match.group(1) in section_sizes:
        section_sizes[match.group(1)] = int(match.group(2), 16)

symbols = subprocess.run(
    ["nm", "-C", "-S", "--size-sort", library],
    check=True,
    capture_output=True,
    text=True,
).stdout
groups = {
    "dart::/Dart_ (VM)": 0,
    "tonic::": 0,
    "flutter::Dart*/RuntimeController": 0,
    "flutter::lib/ui": 0,
    "flutter::other": 0,
    "impeller::": 0,
    "skia/Sk*": 0,
    "Other": 0,
}
snapshot_size = 0

for line in symbols.splitlines():
    fields = line.split(maxsplit=3)
    if len(fields) != 4:
        continue
    try:
        size = int(fields[1], 16)
    except ValueError:
        continue
    symbol = fields[3]
    if symbol.startswith(("kDartVmSnapshot", "kDartIsolateSnapshot")):
        snapshot_size += size
    elif symbol.startswith(("dart::", "Dart_")):
        groups["dart::/Dart_ (VM)"] += size
    elif symbol.startswith("tonic::"):
        groups["tonic::"] += size
    elif symbol.startswith(("flutter::Dart", "flutter::RuntimeController")):
        groups["flutter::Dart*/RuntimeController"] += size
    elif symbol.startswith(("flutter::Canvas", "flutter::SceneBuilder", "flutter::Paragraph")):
        groups["flutter::lib/ui"] += size
    elif symbol.startswith("flutter::"):
        groups["flutter::other"] += size
    elif symbol.startswith("impeller::"):
        groups["impeller::"] += size
    elif symbol.startswith(("skia", "Sk")):
        groups["skia/Sk*"] += size
    else:
        groups["Other"] += size

print(f"# Dart footprint: {os.path.basename(library)}")
print()
print("| Metric | Bytes |")
print("|---|---:|")
print(f"| File size | {os.path.getsize(library)} |")
for section_name in (".text", ".rodata", ".data"):
    print(f"| {section_name} | {section_sizes[section_name]} |")
for group_name, size in groups.items():
    print(f"| {group_name} | {size} |")
print(f"| kDartVmSnapshot*/kDartIsolateSnapshot* | {snapshot_size} |")
PY
