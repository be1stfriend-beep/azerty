"""List the model files under assets/models/ and add skeleton entries to data/prefabs.json.

Existing entries are never touched: hand-tuned prefabs (model, scale, tint_group) survive a rescan.
Usage: python tools/scan_assets.py [--ext glb,fbx] [--dry-run]
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "assets" / "models"
PREFABS = ROOT / "data" / "prefabs.json"
DEFAULT_TINT = "concrete"


def skeleton_id(path: Path) -> str:
    return "model_" + re.sub(r"[^a-z0-9]+", "_", path.stem.lower()).strip("_")


def res_path(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ext", default="glb", help="comma-separated extensions to scan")
    parser.add_argument("--dry-run", action="store_true", help="list only, do not write prefabs.json")
    args = parser.parse_args()
    extensions = {"." + e.strip().lower().lstrip(".") for e in args.ext.split(",") if e.strip()}

    files = sorted(p for p in MODELS.rglob("*") if p.is_file() and p.suffix.lower() in extensions)
    prefabs: dict = json.loads(PREFABS.read_text(encoding="utf-8"))
    used_models = {entry.get("model") for entry in prefabs.values()}
    added = 0
    for path in files:
        model = res_path(path)
        prefab_id = skeleton_id(path)
        status = "in use"
        if model not in used_models:
            if prefab_id in prefabs:
                status = "id taken, skipped"
            else:
                prefabs[prefab_id] = {"model": model, "scale": 1.0, "tint_group": DEFAULT_TINT}
                used_models.add(model)
                added += 1
                status = "added"
        print(f"{prefab_id:40s} {status:18s} {model}")

    if not args.dry_run and added:
        PREFABS.write_text(json.dumps(prefabs, indent="\t") + "\n", encoding="utf-8")
    print(f"scan: {len(files)} model files, {added} skeleton entries {'listed' if args.dry_run else 'added'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
