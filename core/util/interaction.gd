class_name Interaction
## Imad's single contextual action. Every peer resolves it from replicated positions and state,
## so the button label, the target ring and the world prompts agree on both screens.

const NONE := ""
const GRAB := "grab"
const STATION := "station"
const MOUNT := "mount"
const DISMOUNT := "dismount"
const STATION_LABELS: Dictionary = {"recycler": "label_recycle", "bench": "label_craft", "tower": "label_activate"}


## {action, label, target: Node3D or null, full: trash is in reach but the sack is full}.
static func resolve(imad: Imad) -> Dictionary:
	var result := {"action": NONE, "label": Data.hint("label_none"), "target": null, "full": false}
	var mount := TeamState.mount_state()
	if Game.world == null or imad == null or TeamState.state.is_empty() or mount in [MountController.MOUNTING, MountController.DISMOUNTING]:
		return result
	var bjorn := Game.player(Characters.Character.BJORN)
	var riding := mount == MountController.MERGED and bjorn != null
	var body: Node3D = bjorn if riding else imad
	var carried: Array = TeamState.state.get("carried", [])
	var trash := nearest_trash(imad, bjorn, riding)
	if trash != null:
		if carried.size() < int(Data.balance("carry_capacity")):
			return _with(result, GRAB, Data.hint("label_grab"), trash)
		result["full"] = true
	var station := nearest_station(body.global_position)
	if station != null and STATION_LABELS.has(station.kind):
		if station.kind != "recycler":
			return _with(result, STATION, Data.hint(STATION_LABELS[station.kind]), station)
		if not carried.is_empty():
			return _with(result, STATION, Data.hint("label_recycle") % carried.size(), station)
	var controller := Game.world.get_node_or_null("MountController") as MountController
	if not riding and bjorn != null and controller != null and controller.can_mount(imad, bjorn):
		return _with(result, MOUNT, Data.hint("label_mount"), bjorn)
	if riding:
		return _with(result, DISMOUNT, Data.hint("label_dismount"), null)
	return result


## Called on Imad's own client when the action button goes down.
static func perform(imad: Imad, context: Dictionary) -> void:
	var controller := Game.world.get_node_or_null("MountController") as MountController
	match context["action"]:
		GRAB:
			TeamState.request_grab((context["target"] as Node3D).global_position)
		STATION:
			(context["target"] as Interactable).interact(imad)
		MOUNT:
			if controller != null:
				controller.request_mount()
		DISMOUNT:
			if controller != null:
				controller.request_dismount()
		_:
			if context["full"]:
				Game.show_message(Data.hint("prompt_full"))


## Solo: within tongs_radius of Imad. Riding: anywhere within tongs_reach of the pair,
## unless the right stick is aiming, which narrows it to the reticle.
static func nearest_trash(imad: Imad, bjorn: PlayerBase, riding: bool) -> Node3D:
	var center := imad.global_position
	var radius := float(Data.balance("tongs_radius"))
	if riding:
		center = imad.reticle_point(bjorn) if imad.aim_override else bjorn.global_position
		radius = radius if imad.aim_override else float(Data.balance("tongs_reach"))
	var best: Node3D = null
	var best_distance := radius
	for node: Node in Game.world.get_node("Entities").get_children():
		if not StationRules.is_loose(node, TeamState.state):
			continue
		var trash := node as Node3D
		var distance := StationRules.flat_distance(trash.global_position, center)
		if distance <= best_distance and StationRules.in_sight(imad.global_position, trash):
			best = trash
			best_distance = distance
	return best


static func nearest_station(point: Vector3) -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for node: Node in Game.world.get_node("Entities").get_children():
		var station := node as Interactable
		if station == null or not station.in_range(point):
			continue
		var distance := StationRules.flat_distance(point, station.global_position)
		if distance < best_distance:
			best = station
			best_distance = distance
	return best


static func _with(result: Dictionary, action: String, label: String, target: Node3D) -> Dictionary:
	result.merge({"action": action, "label": label, "target": target}, true)
	return result
