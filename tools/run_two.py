"""Launch two Godot instances side by side: a host and a guest on 127.0.0.1."""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZE = "960x540"
INSTANCES = [
    ("0,0", ["--host"]),
    ("960,0", ["--join", "127.0.0.1"]),
]


def main() -> int:
    godot = os.environ.get("GODOT_BIN")
    if not godot or not Path(godot).exists():
        print("Set GODOT_BIN to the Godot 4.7 executable.")
        return 1
    extra = sys.argv[1:]
    processes = []
    for position, user_args in INSTANCES:
        command = [godot, "--path", str(ROOT), "--position", position,
                   "--resolution", SIZE, "--", *user_args, *extra]
        processes.append(subprocess.Popen(command))
    for process in processes:
        process.wait()
    return 0


if __name__ == "__main__":
    sys.exit(main())
