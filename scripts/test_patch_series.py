#!/usr/bin/env python3
import unittest
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).parent))

from patch_series import collect_patch_paths, parse_all_series, parse_series


class PatchSeriesTest(unittest.TestCase):
    def test_collects_paths_from_all_patch_files(self) -> None:
        samples = {
            "always.patch": """\
diff --git a/engine/src/always.gn b/engine/src/always.gn
index 1111111..2222222 100644
--- a/engine/src/always.gn
+++ b/engine/src/always.gn
""",
            "conditional.patch": """\
diff --git a/engine/src/conditional.gn b/engine/src/conditional.gn
index 3333333..4444444 100644
--- a/engine/src/conditional.gn
+++ b/engine/src/conditional.gn
diff --git a/engine/src/created.gn b/engine/src/created.gn
new file mode 100644
--- /dev/null
+++ b/engine/src/created.gn
""",
        }
        with TemporaryDirectory() as temporary_directory:
            patch_paths = []
            for name, contents in samples.items():
                patch_path = Path(temporary_directory) / name
                patch_path.write_text(contents, encoding="utf-8")
                patch_paths.append(patch_path)

            self.assertEqual(
                collect_patch_paths(patch_paths),
                [
                    "engine/src/always.gn",
                    "engine/src/conditional.gn",
                    "engine/src/created.gn",
                ],
            )

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

    def test_returns_all_entries_for_the_unconditional_build_series(self) -> None:
        series = """
        linux-target-matrix cpu=arm
        linux-compiler-runtime libc=musl
        linux-musl cpu=arm libc=musl
        """

        self.assertEqual(
            parse_all_series(series),
            ["linux-target-matrix", "linux-compiler-runtime", "linux-musl"],
        )


if __name__ == "__main__":
    unittest.main()
