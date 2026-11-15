#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ENGINE_BUILD = ROOT / "libs/gammaraylib/build.py"

target = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in ("native", "wasm") else "native"
extra_args = sys.argv[2:] if len(sys.argv) > 1 and sys.argv[1] in ("native", "wasm") else sys.argv[1:]

if target == "native":
    cmd = [sys.executable, str(ENGINE_BUILD), "native", "--src", "src/main.mojo", "-I", "src", *extra_args]
else:
    cmd = [
        sys.executable, str(ENGINE_BUILD), "wasm",
        "--src", "src/main.mojo",
        "-I", "src",
        "--assets", "assets",
        "--title", "Walrus Wars",
        *extra_args,
    ]

try:
    subprocess.run(cmd, cwd=ROOT, check=True)
except KeyboardInterrupt:
    sys.exit(0)
