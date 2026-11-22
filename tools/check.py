"""One-shot project check: boot, data validation, autotest. Prints one summary line."""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BOOT_FRAMES = "120"
BOOT_TIMEOUT = 120
AUTOTEST_TIMEOUT = 240
ERROR_MARKERS = ("SCRIPT ERROR", "Parse Error", "ERROR:")


def run(command: list[str], timeout: int) -> tuple[int, str]:
    try:
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        return -1, f"timed out after {timeout}s"
    return done.returncode, done.stdout + done.stderr


def engine_errors(output: str) -> list[str]:
    return [line.strip() for line in output.splitlines() if any(m in line for m in ERROR_MARKERS)]


def main() -> int:
    godot = os.environ.get("GODOT_BIN")
    if not godot or not Path(godot).exists():
        print("check: GODOT_BIN is not set to an existing Godot executable")
        return 1
    parts: list[str] = []
    ok = True

    _, boot_out = run([godot, "--headless", "--path", str(ROOT), "--quit-after", BOOT_FRAMES], BOOT_TIMEOUT)
    boot_errors = engine_errors(boot_out)
    ok &= not boot_errors
    parts.append("boot OK" if not boot_errors else f"boot {len(boot_errors)} errors")

    data_code, data_out = run([sys.executable, str(ROOT / "tools" / "validate_data.py")], BOOT_TIMEOUT)
    ok &= data_code == 0
    parts.append("data OK" if data_code == 0 else "data FAIL")

    test_code, test_out = run([godot, "--headless", "--path", str(ROOT), "--", "--autotest"], AUTOTEST_TIMEOUT)
    lines = test_out.splitlines()
    passes = sum(line.startswith("PASS ") for line in lines)
    fails = [line for line in lines if line.startswith("FAIL ")]
    test_errors = engine_errors(test_out)
    ok &= test_code == 0 and not fails and not test_errors and passes > 0
    parts.append(f"autotest {passes} PASS {len(fails)} FAIL {len(test_errors)} engine errors (exit {test_code})")

    for line in boot_errors + data_out.splitlines() * (data_code != 0) + fails + test_errors:
        print("  " + line)
    print(("check PASS: " if ok else "check FAIL: ") + " | ".join(parts))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
