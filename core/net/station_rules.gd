class_name StationRules
## Pure host rules: each takes the current state and returns the next one, or {} when refused.

## Ray heights above the feet: from Imad's hands to the middle of a trash item.
const SIGHT_FROM_HEIGHT := 0.6
const SIGHT_TO_HEIGHT := 0.3
const WORLD_MASK := 1


static func tongs(state: Dictionary, point: Vector3, imad_pos: Vector3, entities: Node) -> Dictionary:
	var carried: Array = state["carried"]
	var radius: float = Data.balance("tongs_radius")
	if carried.size() >= int(Data.balance("carry_capacity")):
		return {}
	if flat_distance(imad_pos, point) > float(Data.balance("tongs_reach")) + radius:
		return {}
	var picked: Array = state["picked"]
	var best: Node3D = null
	var best_distance := radius
	for entity: Node in entities.get_children():
		if entity.get_meta("kind", "") != "trash" or String(entity.name) in picked:
			continue
		var distance := flat_distance((entity as Node3D).global_position, point)
		if distance <= best_distance and in_sight(imad_pos, entity as Node3D):
			best = entity
			best_distance = distance
	if best == null:
		return {}
	var next := state.duplicate(true)
	next["carried"].append(best.get_meta("item"))
	next["carried_ids"].append(String(best.name))
	next["picked"].append(String(best.name))
	return next


## Tongs cannot reach through walls, fences or closed doors (anything on the world layer).
static func in_sight(from: Vector3, target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * SIGHT_FROM_HEIGHT, target.global_position + Vector3.UP * SIGHT_TO_HEIGHT, WORLD_MASK)
	return target.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func recycle(state: Dictionary) -> Dictionary:
	var carried: Array = state["carried"]
	if carried.is_empty():
		return {}
	var next := state.duplicate(true)
	var stash: Dictionary = next["stash"]
	for item_id: String in carried:
		var item := Data.item(item_id)
		var material: String = item.get("material", "")
		stash[material] = int(stash.get(material, 0)) + int(item.get("yield", 0))
	next["carried"] = []
	next["carried_ids"] = []
	return next


static func can_afford(stash: Dictionary, recipe: Dictionary) -> bool:
	var cost: Dictionary = recipe.get("cost", {})
	for material: String in cost:
		if int(stash.get(material, 0)) < int(cost[material]):
			return false
	return true


static func craft(state: Dictionary, recipe_id: String) -> Dictionary:
	var recipe := Data.recipe(recipe_id)
	if recipe.is_empty() or not can_afford(state["stash"], recipe):
		return {}
	var next := state.duplicate(true)
	if recipe["result"] == "tool":
		if recipe_id in next["tools"]:
			return {}
		next["tools"].append(recipe_id)
	else:
		next["inventory"][recipe_id] = int(next["inventory"].get(recipe_id, 0)) + 1
	var cost: Dictionary = recipe["cost"]
	for material: String in cost:
		next["stash"][material] = int(next["stash"][material]) - int(cost[material])
	return next


static func next_tool(state: Dictionary) -> Dictionary:
	var tools: Array = state.get("tools", [])
	if tools.size() < 2:
		return {}
	var next := state.duplicate(true)
	next["current_tool"] = tools[(tools.find(state["current_tool"]) + 1) % tools.size()]
	return next


static func activate_tower(state: Dictionary, index: int) -> Dictionary:
	var next := state.duplicate(true)
	next["inventory"]["filter"] = int(next["inventory"].get("filter", 0)) - 1
	next["towers"].append(index)
	next["hold_progress"] = 0.0
	next["holding"] = ""
	return next


## Nothing is thrown away: carried trash goes back into the world in a ring where the team fell.
static func out_of_air(state: Dictionary, imad_spawn: Vector3, fall_point: Vector3) -> Dictionary:
	var next := state.duplicate(true)
	next["air"] = float(Data.balance("air_max"))
	var ids: Array = state.get("carried_ids", [])
	var radius := float(Data.balance("knockout_drop_radius"))
	for i in ids.size():
		var angle := TAU * i / ids.size()
		next["drops"][ids[i]] = Vector3(fall_point.x, 0.0, fall_point.z) + Vector3(cos(angle), 0.0, sin(angle)) * radius
		next["picked"].erase(ids[i])
	next["carried"] = []
	next["carried_ids"] = []
	next["mount"] = MountController.SOLO
	next["dismount_pos"] = imad_spawn
	next["on_perch"] = false
	return next


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
