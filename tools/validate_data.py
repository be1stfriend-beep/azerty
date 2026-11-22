"""Validate data/*.json: everything parses and every cross-reference resolves."""
import json
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"
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


def main() -> int:
    tables, levels, errors = load_all()
    errors += check(tables, levels)
    for error in errors:
        print("ERROR:", error)
    if errors:
        return 1
    print(f"data ok: {len(tables)} tables, {len(levels)} levels")
    return 0


if __name__ == "__main__":
    sys.exit(main())
