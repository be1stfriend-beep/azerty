"""Validate data/*.json: everything parses and every cross-reference resolves."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
REQUIRED = ["config", "balance", "items", "recipes", "prefabs", "entities", "dialogue"]


def load_all() -> tuple[dict, dict, list[str]]:
    errors: list[str] = []
    tables: dict = {}
    levels: dict = {}
    for target, folder in ((tables, DATA), (levels, DATA / "levels")):
        for path in sorted(folder.glob("*.json")):
            try:
                target[path.stem] = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                errors.append(f"{path.name}: {exc}")
    return tables, levels, errors


def check(tables: dict, levels: dict) -> list[str]:
    errors = [f"missing data/{name}.json" for name in REQUIRED if name not in tables]
    if errors:
        return errors
    items, prefabs, entities = tables["items"], tables["prefabs"], tables["entities"]
    materials = {item.get("material") for item in items.values()}
    for item_id, item in items.items():
        if item.get("prefab") not in prefabs:
            errors.append(f"item {item_id}: unknown prefab {item.get('prefab')}")
    for recipe_id, recipe in tables["recipes"].items():
        for material in recipe.get("cost", {}):
            if material not in materials:
                errors.append(f"recipe {recipe_id}: no item yields {material}")
    for kind, rule in entities.items():
        if "prefab" in rule and rule["prefab"] not in prefabs:
            errors.append(f"entity {kind}: unknown prefab {rule['prefab']}")
        script = rule.get("script", "")
        if script and not (ROOT / script.removeprefix("res://")).exists():
            errors.append(f"entity {kind}: missing script {script}")
    for recipe_id, recipe in tables["recipes"].items():
        if recipe.get("result") not in ("inventory", "tool"):
            errors.append(f"recipe {recipe_id}: result must be inventory or tool")
    for level_name, level in levels.items():
        for index, entity in enumerate(level.get("entities", [])):
            where = f"level {level_name} entity {index}"
            if entity.get("kind") not in entities:
                errors.append(f"{where}: unknown kind {entity.get('kind')}")
            if entity.get("kind") == "trash" and entity.get("item") not in items:
                errors.append(f"{where}: unknown item {entity.get('item')}")
            if "prefab" in entity and entity["prefab"] not in prefabs:
                errors.append(f"{where}: unknown prefab {entity['prefab']}")
    return errors


PLATE_EFFECTS = ("", "vents_off")


def jump_heights(balance: dict) -> tuple[float, float]:
    """Peak heights (solo, merged) from v^2 / (2 g): the co-op ledges sit between them."""
    gravity = balance["gravity"]
    solo = balance["bjorn_jump"] ** 2 / (2 * gravity)
    merged = (balance["bjorn_jump"] * balance["merged_jump_mult"]) ** 2 / (2 * gravity)
    return solo, merged


def check_puzzles(tables: dict, levels: dict) -> list[str]:
    errors: list[str] = []
    solo, merged = jump_heights(tables["balance"])
    ledge = tables["prefabs"].get("prop_ledge", {}).get("height")
    if ledge is not None and not merged < ledge < solo:
        errors.append(f"prop_ledge height {ledge} must be between merged jump {merged:.2f} and solo jump {solo:.2f}")
    for level_name, level in levels.items():
        counters: dict[str, int] = {}
        ids: dict[str, dict] = {}
        for entity in level.get("entities", []):
            kind = entity.get("kind")
            index = counters.get(kind, 0)
            counters[kind] = index + 1
            ids[f"{kind}_{index}"] = entity
        for entity_id, entity in ids.items():
            where = f"level {level_name} {entity_id}"
            if entity["kind"] == "door":
                links = entity.get("links", [])
                if not links:
                    errors.append(f"{where}: door has no links")
                for link in links:
                    if ids.get(link, {}).get("kind") != "plate":
                        errors.append(f"{where}: link {link} is not a plate")
            if entity["kind"] == "plate":
                if entity.get("activates", "") not in PLATE_EFFECTS:
                    errors.append(f"{where}: unknown activates {entity.get('activates')}")
                height = entity["pos"][1]
                if height > 0 and not merged < height < solo:
                    errors.append(f"{where}: raised plate at {height} m must be between {merged:.2f} and {solo:.2f}")
    return errors


STATIONS = ("recycler", "bench")
STATION_CLEARANCE = 2.0
SLICE_FORBIDDEN = ("tower", "pillar", "perch", "gate", "plate", "door", "vent")


def check_level_layout(tables: dict, levels: dict) -> list[str]:
    """Trash must not crowd a station; the slice level carries none of the frozen features."""
    errors: list[str] = []
    for level_name, level in levels.items():
        entities = level.get("entities", [])
        stations = [e["pos"] for e in entities if e.get("kind") in STATIONS]
        for index, entity in enumerate(entities):
            if entity.get("kind") != "trash":
                continue
            x, _, z = entity["pos"]
            for sx, _, sz in stations:
                if ((x - sx) ** 2 + (z - sz) ** 2) ** 0.5 < STATION_CLEARANCE:
                    errors.append(f"level {level_name} entity {index}: trash closer than {STATION_CLEARANCE} m to a station")
    if tables["config"].get("start_level") not in levels:
        errors.append(f"config start_level {tables['config'].get('start_level')} has no level file")
    for index, entity in enumerate(levels.get("slice", {}).get("entities", [])):
        if entity.get("kind") in SLICE_FORBIDDEN:
            errors.append(f"level slice entity {index}: {entity['kind']} is frozen until the slice works")
    if "slice" in levels and "mask" not in tables["recipes"]:
        errors.append("slice level needs recipe mask")
    return errors


def main() -> int:
    tables, levels, errors = load_all()
    errors += check(tables, levels)
    if not errors:
        errors += check_puzzles(tables, levels)
        errors += check_level_layout(tables, levels)
    for error in errors:
        print("ERROR:", error)
    if errors:
        return 1
    print(f"data ok: {len(tables)} tables, {len(levels)} levels")
    return 0


if __name__ == "__main__":
    sys.exit(main())
