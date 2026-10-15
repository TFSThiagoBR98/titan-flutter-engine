#!/usr/bin/env python3
"""Serve local Flutter SDK artifacts and redirect misses to Google storage."""

import argparse
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from urllib.parse import unquote, urlsplit


class SdkArtifactsRequestHandler(BaseHTTPRequestHandler):
    server: "SdkArtifactsServer"

    def do_GET(self) -> None:
        request_path = urlsplit(self.path).path
        relative_path = unquote(request_path).lstrip("/")
        local_path = (self.server.artifact_root / relative_path).resolve()
        root_path = self.server.artifact_root.resolve()
        is_local = os.path.commonpath((root_path, local_path)) == str(root_path) and local_path.is_file()

        self.server.record("local" if is_local else "upstream", request_path)
        if is_local:
            self.send_response(200)
            self.send_header("Content-Length", str(local_path.stat().st_size))
            self.end_headers()
            with local_path.open("rb") as artifact:
                self.wfile.write(artifact.read())
            return

        self.send_response(302)
        self.send_header("Location", f"https://storage.googleapis.com{self.path}")
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        return


class SdkArtifactsServer(ThreadingHTTPServer):
    artifact_root: Path
    log_path: Path
    log_lock: Lock

    def record(self, source: str, request_path: str) -> None:
        with self.log_lock:
            with self.log_path.open("a", encoding="utf-8") as log:
                log.write(f"{source} {request_path}\n")


def create_server(root: Path, log_path: Path, port: int) -> SdkArtifactsServer:
    server = SdkArtifactsServer(("127.0.0.1", port), SdkArtifactsRequestHandler)
    server.artifact_root = root.resolve()
    server.log_path = log_path
    server.log_path.parent.mkdir(parents=True, exist_ok=True)
    server.log_lock = Lock()
    return server


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--work-dir", type=Path, default=Path(os.environ.get("TITAN_WORK_DIR", ".")))
    parser.add_argument("--port", type=int, default=0)
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    log_path = arguments.work_dir / "sdk-server.log"
    server = create_server(arguments.root, log_path, arguments.port)
    print(f"PORT={server.server_port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
