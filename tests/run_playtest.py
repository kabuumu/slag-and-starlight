#!/usr/bin/env python3
"""Run the Slag & Starlight automated playtest under Xvfb + OpenGL3 and fail on any runtime error."""

import argparse
import os
import re
import subprocess
import sys

ERROR_PATTERNS = [
    re.compile(r"SCRIPT ERROR:", re.IGNORECASE),
    re.compile(r"Parse Error:", re.IGNORECASE),
    re.compile(r"Failed to load script", re.IGNORECASE),
    re.compile(r"Node not found:", re.IGNORECASE),
    re.compile(r"\[PLAYTEST FAIL\]"),
    # Godot C++ errors (excluding harmless ALSA/VSync driver messages if any)
    re.compile(r"^ERROR:\s+", re.MULTILINE),
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "/tmp/godot/godot"))
    parser.add_argument("--shots", default="/tmp/playtest_shots")
    parser.add_argument("--allow-warnings", action="store_true", default=True)
    args = parser.parse_args()

    os.makedirs(args.shots, exist_ok=True)
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    cmd = [
        "xvfb-run",
        "-a",
        "-s",
        "-screen 0 1280x800x24",
        args.godot,
        "--rendering-driver",
        "opengl3",
        "--audio-driver",
        "Dummy",
        "--path",
        repo_root,
        "--script",
        "res://tests/playtest_bot.gd",
        "--",
        f"--shots={args.shots}",
    ]

    print(f"Running: {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    print(combined)

    detected_errors = []
    for pat in ERROR_PATTERNS:
        for m in pat.finditer(combined):
            line_start = combined.rfind("\n", 0, m.start()) + 1
            line_end = combined.find("\n", m.end())
            if line_end == -1:
                line_end = len(combined)
            detected_errors.append(combined[line_start:line_end].strip())

    if proc.returncode != 0 or detected_errors:
        print("\n=== PLAYTEST GATE FAILED ===")
        print(f"Exit code: {proc.returncode}")
        for err in detected_errors:
            print(f"  - {err}")
        return 1

    print("\n=== PLAYTEST GATE PASSED (0 runtime errors) ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
