"""Per-machine settings for the tools, read from local.env in the project root.

local.env is gitignored so every PC keeps its own paths; local.env.example is the template.
Real environment variables win over the file, so CI or a shell export can still override it.
"""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT / "local.env"
IMPORT_TIMEOUT = 600


def load() -> None:
    if not ENV_FILE.exists():
        return
    for raw in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"').strip("'")
        if value and not os.environ.get(key.strip()):
            os.environ[key.strip()] = value


def godot_bin() -> str:
    """The Godot executable, or "" when it is not configured or does not exist."""
    load()
    godot = os.environ.get("GODOT_BIN", "")
    return godot if godot and Path(godot).exists() else ""


def ensure_imported(godot: str) -> None:
    """A fresh clone has no .godot cache, so models would not load until assets are imported once."""
    if (ROOT / ".godot" / "imported").exists():
        return
    print("First run on this machine: importing assets (one time) ...")
    subprocess.run([godot, "--headless", "--path", str(ROOT), "--import"], cwd=ROOT, timeout=IMPORT_TIMEOUT)
