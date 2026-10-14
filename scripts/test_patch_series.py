#!/usr/bin/env python3
import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from patch_series import parse_series


class PatchSeriesTest(unittest.TestCase):
    def test_filters_entries_by_cpu_and_libc(self) -> None:
        series = """
        # Always applied.
        impeller-vulkan
        cross-linux-arm cpu=arm
        musl libc=musl
        """

        self.assertEqual(
            parse_series(series, cpu="x64", libc="glibc"),
            ["impeller-vulkan"],
        )
        self.assertEqual(
            parse_series(series, cpu="arm", libc="glibc"),
            ["impeller-vulkan", "cross-linux-arm"],
        )
        self.assertEqual(
            parse_series(series, cpu="arm", libc="musl"),
            ["impeller-vulkan", "cross-linux-arm", "musl"],
        )


if __name__ == "__main__":
    unittest.main()
