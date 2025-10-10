#!/usr/bin/env python3
"""Generate gRPC Python stubs for the bidding logic service."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> None:
    service_dir = Path(__file__).resolve().parent.parent
    repo_root = service_dir.parent.parent
    proto_path = repo_root / "proto"
    proto_file = proto_path / "user_profile.proto"
    output_dir = service_dir / "src"

    if not proto_file.exists():
        raise FileNotFoundError(f"Unable to locate proto file: {proto_file}")

    output_dir.mkdir(parents=True, exist_ok=True)

    command = [
        sys.executable,
        "-m",
        "grpc_tools.protoc",
        f"-I{proto_path}",
        f"--python_out={output_dir}",
        f"--grpc_python_out={output_dir}",
        str(proto_file),
    ]

    subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
