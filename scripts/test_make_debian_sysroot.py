#!/usr/bin/env python3
import os
import sys
import tempfile
import unittest
import importlib.util
from pathlib import Path

_MODULE_PATH = Path(__file__).with_name("make-debian-sysroot.py")
_SPEC = importlib.util.spec_from_file_location("make_debian_sysroot", _MODULE_PATH)
assert _SPEC is not None and _SPEC.loader is not None
_MODULE = importlib.util.module_from_spec(_SPEC)
sys.modules[_SPEC.name] = _MODULE
_SPEC.loader.exec_module(_MODULE)
parse_packages = _MODULE.parse_packages
resolve_dependencies = _MODULE.resolve_dependencies
rewrite_absolute_symlinks = _MODULE.rewrite_absolute_symlinks


class MakeDebianSysrootTest(unittest.TestCase):
    def test_resolves_dependencies_and_alternatives_from_packages_index(self) -> None:
        packages = parse_packages(
            """
Package: libc6-dev
Version: 2.31-13+deb11u5
Architecture: armel
Depends: libc6 (= 2.31-13+deb11u5), linux-libc-dev
Filename: pool/main/g/glibc/libc6-dev.deb
SHA256: libc6-dev-sha

Package: libc6
Version: 2.31-13+deb11u5
Architecture: armel
Filename: pool/main/g/glibc/libc6.deb
SHA256: libc6-sha

Package: linux-libc-dev
Version: 5.10.223-1
Architecture: armel
Depends: libc6
Filename: pool/main/l/linux/linux-libc-dev.deb
SHA256: linux-libc-dev-sha

Package: libgcc-10-dev
Version: 10.2.1-6
Architecture: armel
Depends: libc6
Filename: pool/main/g/gcc-10/libgcc-10-dev.deb
SHA256: libgcc-sha

Package: libstdc++-10-dev
Version: 10.2.1-6
Architecture: armel
Depends: libgcc-10-dev, libc6-dev, libstdc++6 | libstdc++6-10-dbg
Filename: pool/main/g/gcc-10/libstdc++-10-dev.deb
SHA256: libstdcxx-dev-sha

Package: libstdc++6
Version: 10.2.1-6
Architecture: armel
Depends: libc6
Filename: pool/main/g/gcc-10/libstdc++6.deb
SHA256: libstdcxx-sha
"""
        )

        resolved = resolve_dependencies(
            packages,
            ["libc6-dev", "linux-libc-dev", "libgcc-10-dev", "libstdc++-10-dev"],
        )

        self.assertEqual(
            set(resolved),
            {
                "libc6-dev",
                "libc6",
                "linux-libc-dev",
                "libgcc-10-dev",
                "libstdc++-10-dev",
                "libstdc++6",
            },
        )

    def test_rewrites_absolute_symlinks_inside_sysroot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            sysroot = Path(temporary_directory)
            target = sysroot / "lib/arm-linux-gnueabi/libc.so.6"
            target.parent.mkdir(parents=True)
            target.touch()
            link = sysroot / "usr/lib/libc.so"
            link.parent.mkdir(parents=True)
            link.symlink_to("/lib/arm-linux-gnueabi/libc.so.6")

            rewritten = rewrite_absolute_symlinks(sysroot)

            self.assertEqual(rewritten, 1)
            self.assertEqual(
                os.readlink(link),
                "../../lib/arm-linux-gnueabi/libc.so.6",
            )


if __name__ == "__main__":
    unittest.main()
