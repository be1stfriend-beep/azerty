"""Export the debug APK with Godot and install it on every connected Android phone.

Usage: python tools/build_android.py [--launch] [--no-install]
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRESET = "Android"
APK = ROOT / "builds" / "piggyback-debug.apk"
PRESETS_FILE = ROOT / "export_presets.cfg"
EXPORT_TIMEOUT = 900
ADB_TIMEOUT = 300


class BuildError(Exception):
    pass


def run(command: list[str], timeout: int) -> tuple[int, str]:
    try:
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        raise BuildError(f"timed out after {timeout}s: {' '.join(command[:3])} ...")
    except OSError as exc:
        raise BuildError(f"could not start {command[0]}: {exc}")
    return done.returncode, done.stdout + done.stderr


def package_name() -> str:
    if not PRESETS_FILE.exists():
        raise BuildError("export_presets.cfg is missing in the project root.")
    match = re.search(r'^package/unique_name="([^"]+)"', PRESETS_FILE.read_text(encoding="utf-8"), re.M)
    if not match:
        raise BuildError("export_presets.cfg has no package/unique_name.")
    return match.group(1)


def editor_sdk_path() -> str:
    """The Android SDK path the Godot editor was told about, if any."""
    settings = Path(os.environ.get("APPDATA", "")) / "Godot"
    for file in sorted(settings.glob("editor_settings-*.tres"), reverse=True):
        match = re.search(r'export/android/android_sdk_path = "([^"]*)"', file.read_text(encoding="utf-8", errors="replace"))
        if match and match.group(1):
            return match.group(1).replace("\\\\", "\\")
    return ""


def find_adb() -> str:
    on_path = shutil.which("adb")
    if on_path:
        return on_path
    roots = [os.environ.get("ANDROID_HOME", ""), os.environ.get("ANDROID_SDK_ROOT", ""), editor_sdk_path(),
             str(Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk")]
    for root in roots:
        candidate = Path(root) / "platform-tools" / "adb.exe" if root else None
        if candidate and candidate.exists():
            return str(candidate)
    raise BuildError("adb not found. Install Android SDK platform-tools, or set ANDROID_HOME to the SDK folder.")


def export_apk() -> None:
    godot = os.environ.get("GODOT_BIN", "")
    if not godot or not Path(godot).exists():
        raise BuildError("GODOT_BIN is not set to the Godot 4.7.2 executable.")
    APK.parent.mkdir(parents=True, exist_ok=True)
    if APK.exists():
        APK.unlink()
    print(f"Exporting preset '{PRESET}' to {APK.relative_to(ROOT)} ...")
    code, output = run([godot, "--headless", "--path", str(ROOT), "--export-debug", PRESET, str(APK)], EXPORT_TIMEOUT)
    if code != 0 or not APK.exists():
        hints = [line.strip() for line in output.splitlines() if "ERROR" in line or "error" in line.lower()]
        for line in hints[-10:]:
            print("  " + line)
        raise BuildError("export failed. Check export templates (Editor > Manage Export Templates) and the "
                         "Java/Android SDK paths in Editor Settings > Export > Android. See docs/RUN.md.")
    print(f"Exported {APK.name}: {APK.stat().st_size / 1_048_576:.1f} MB")


def devices(adb: str) -> tuple[list[str], list[tuple[str, str]]]:
    code, output = run([adb, "devices"], ADB_TIMEOUT)
    if code != 0:
        raise BuildError(f"adb devices failed:\n{output}")
    ready: list[str] = []
    blocked: list[tuple[str, str]] = []
    for line in output.splitlines():
        parts = line.split()
        # Skip the header and the "* daemon started" chatter adb prints on its first run.
        if len(parts) < 2 or line.startswith(("*", "List of")):
            continue
        if parts[1] == "device":
            ready.append(parts[0])
        else:
            blocked.append((parts[0], parts[1]))
    return ready, blocked


def install(adb: str, launch: bool) -> int:
    ready, blocked = devices(adb)
    for serial, state in blocked:
        if state == "unauthorized":
            print(f"Device {serial} is unauthorised: unlock it and accept the USB debugging prompt on the phone, then rerun.")
        else:
            print(f"Device {serial} is {state}: unplug and replug the cable, then rerun.")
    if not ready:
        print("No authorised Android device connected. Plug in a phone with USB debugging on (see docs/RUN.md).")
        return 1
    package = package_name()
    failures = 0
    for serial in ready:
        print(f"Installing on {serial} ...")
        code, output = run([adb, "-s", serial, "install", "-r", str(APK)], ADB_TIMEOUT)
        if code != 0 or "Success" not in output:
            failures += 1
            print(f"  install failed on {serial}: {output.strip().splitlines()[-1] if output.strip() else 'no output'}")
            continue
        print("  installed")
        if launch:
            run([adb, "-s", serial, "shell", "monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1"], ADB_TIMEOUT)
            print(f"  launched {package}")
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Export the debug APK and install it on connected phones.")
    parser.add_argument("--launch", action="store_true", help="start the app on each phone after installing")
    parser.add_argument("--no-install", action="store_true", help="only export the APK")
    args = parser.parse_args()
    try:
        package_name()
        export_apk()
        if args.no_install:
            return 0
        return install(find_adb(), args.launch)
    except BuildError as exc:
        print(f"ERROR: {exc}")
        return 1
    except KeyboardInterrupt:
        print("Cancelled.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
