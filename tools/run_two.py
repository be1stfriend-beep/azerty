"""Launch two Godot instances side by side: a host and a guest on 127.0.0.1."""
import subprocess
import sys
from pathlib import Path

import local_env

ROOT = Path(__file__).resolve().parent.parent
SIZE = "960x540"
INSTANCES = [
    ("0,0", ["--host"]),
    ("960,0", ["--join", "127.0.0.1"]),
]


def main() -> int:
    godot = local_env.godot_bin()
    if not godot:
        print("Set GODOT_BIN to the Godot 4.7 executable in local.env (copy local.env.example).")
        return 1
    local_env.ensure_imported(godot)
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
