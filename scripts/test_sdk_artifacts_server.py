#!/usr/bin/env python3
import importlib.util
import os
import subprocess
import threading
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.request import HTTPRedirectHandler, Request, build_opener


SCRIPT_PATH = Path(__file__).with_name("sdk-artifacts-server.py")
SPEC = importlib.util.spec_from_file_location("sdk_artifacts_server", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)
INSTALL_SCRIPT = SCRIPT_PATH.with_name("install-sdk-artifacts.sh")


class NoRedirectHandler(HTTPRedirectHandler):
    def http_error_302(self, request, fp, code, msg, headers):
        return fp


class SdkArtifactsServerTest(unittest.TestCase):
    def test_serves_local_artifact_and_redirects_missing_artifact(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            local_path = root / "flutter_infra_release/flutter/test-hash/local.zip"
            local_path.parent.mkdir(parents=True)
            local_path.write_bytes(b"local artifact")
            log_path = root / "sdk-server.log"
            server = SERVER.create_server(root, log_path, 0)
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                opener = build_opener(NoRedirectHandler())
                base_url = f"http://127.0.0.1:{server.server_port}"
                with opener.open(
                    Request(base_url + "/flutter_infra_release/flutter/test-hash/local.zip")
                ) as response:
                    self.assertEqual(response.status, 200)
                    self.assertEqual(response.read(), b"local artifact")

                with opener.open(
                    Request(
                        base_url
                        + "/flutter_infra_release/flutter/test-hash/missing.zip"
                    )
                ) as response:
                    self.assertEqual(response.status, 302)
                    self.assertEqual(
                        response.headers["Location"],
                        "https://storage.googleapis.com/flutter_infra_release/flutter/test-hash/missing.zip",
                    )
            finally:
                server.shutdown()
                thread.join(timeout=5)
                server.server_close()

            log = log_path.read_text(encoding="utf-8").splitlines()
            self.assertIn(
                "local /flutter_infra_release/flutter/test-hash/local.zip", log
            )
            self.assertIn(
                "upstream /flutter_infra_release/flutter/test-hash/missing.zip", log
            )

    def test_install_runs_linux_precache_and_preserves_dart_sdk_by_default(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            bundle = root / "bundle/sdk"
            work_dir = root / "work"
            sdk = root / "flutter-sdk"
            artifact = bundle / "flutter_infra_release/flutter/test-hash/linux-x64/artifacts.zip"
            artifact.parent.mkdir(parents=True)
            artifact.write_bytes(b"local artifact")
            manifest = bundle / "MANIFEST"
            manifest.write_text(
                "linux-x64/artifacts.zip\t14\t"
                "placeholder\n",
                encoding="utf-8",
            )
            flutter = sdk / "bin/flutter"
            flutter.parent.mkdir(parents=True)
            flutter.write_text(
                "#!/usr/bin/env python3\n"
                "import os, sys\n"
                "from pathlib import Path\n"
                "from urllib.request import urlopen\n"
                "assert sys.argv[1:] == ['precache', '--linux', '--force']\n"
                "for line in Path(os.environ['TEST_MANIFEST']).read_text().splitlines():\n"
                "    path = line.split('\\t', 1)[0]\n"
                "    urlopen(os.environ['FLUTTER_STORAGE_BASE_URL'] + "
                "'/flutter_infra_release/flutter/test-hash/' + path).read()\n",
                encoding="utf-8",
            )
            flutter.chmod(0o755)
            dart_marker = sdk / "bin/cache/dart-sdk/marker"
            dart_marker.parent.mkdir(parents=True)
            dart_marker.write_text("keep", encoding="utf-8")
            environment = os.environ.copy()
            environment.update(
                {
                    "TITAN_BUNDLE_DIR": str(root / "bundle"),
                    "TITAN_WORK_DIR": str(work_dir),
                    "TEST_MANIFEST": str(manifest),
                }
            )

            subprocess.run(
                ["bash", str(INSTALL_SCRIPT), str(sdk)],
                check=True,
                env=environment,
                capture_output=True,
                text=True,
            )
            self.assertTrue(dart_marker.exists())
            self.assertIn(
                "local /flutter_infra_release/flutter/test-hash/linux-x64/artifacts.zip",
                (work_dir / "sdk-server.log").read_text(encoding="utf-8"),
            )

            subprocess.run(
                ["bash", str(INSTALL_SCRIPT), "--with-dart-sdk", str(sdk)],
                check=True,
                env=environment,
                capture_output=True,
                text=True,
            )
            self.assertFalse(dart_marker.exists())


if __name__ == "__main__":
    unittest.main()
