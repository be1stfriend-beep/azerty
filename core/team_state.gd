extends Node
## Host-owned shared state. The host mutates a copy, then pushes the whole dictionary.
## Clients only receive it.

var state: Dictionary = {}


func reset() -> void:
	if not multiplayer.is_server():
		return
	_commit({
		"carried": [],
		"stash": {},
		"tools": ["tongs"],
		"current_tool": "tongs",
		"inventory": {},
		"picked": [],
		"towers": [],
		"mount": MountController.SOLO,
		"dismount_pos": Vector3.ZERO,
		"air": float(Data.balance("air_max")),
	})


func clear() -> void:
	state = {}


func mount_state() -> String:
	return state.get("mount", MountController.SOLO)


## Host only. Used by MountController, which owns the mount rules.
func set_mount(mount: String, dismount_pos: Vector3 = Vector3.ZERO) -> void:
	var next := state.duplicate(true)
	next["mount"] = mount
	if mount == MountController.DISMOUNTING:
		next["dismount_pos"] = dismount_pos
	_commit(next)


## Disconnect while merged: both sides drop to SOLO without waiting for the host.
func force_solo(drop_pos: Vector3) -> void:
	if mount_state() == MountController.SOLO:
		return
	var next := state.duplicate(true)
	next["mount"] = MountController.SOLO
	next["dismount_pos"] = drop_pos
	if multiplayer.is_server():
		_commit(next)
	else:
		_apply(next)


func request_use_tool(point: Vector3) -> void:
	if multiplayer.is_server():
		_server_use_tool(point, multiplayer.get_unique_id())
	else:
		_rpc_request_use_tool.rpc_id(1, point)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_use_tool(point: Vector3) -> void:
	if multiplayer.is_server():
		_server_use_tool(point, multiplayer.get_remote_sender_id())


func request_tool_next() -> void:
	if multiplayer.is_server():
		_server_tool_next(multiplayer.get_unique_id())
	else:
		_rpc_request_tool_next.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_tool_next() -> void:
	if multiplayer.is_server():
		_server_tool_next(multiplayer.get_remote_sender_id())


func _server_use_tool(point: Vector3, sender: int) -> void:
	if sender != Net.peer_for_character(Characters.Character.IMAD) or Game.world == null:
		return
	if state.get("current_tool") == "tongs":
		_server_tongs(point)


func _server_tongs(point: Vector3) -> void:
	var carried: Array = state["carried"]
	if carried.size() >= int(Data.balance("carry_capacity")):
		return
	var imad := Game.world.get_node_or_null("imad") as Node3D
	var radius: float = Data.balance("tongs_radius")
	if imad == null or _flat_distance(imad.global_position, point) > float(Data.balance("tongs_reach")) + radius:
		return
	var picked: Array = state["picked"]
	var best: Node3D = null
	var best_distance := radius
	for entity: Node in Game.world.get_node("Entities").get_children():
		if entity.get_meta("kind", "") != "trash" or String(entity.name) in picked:
			continue
		var distance := _flat_distance((entity as Node3D).global_position, point)
		if distance <= best_distance:
			best = entity
			best_distance = distance
	if best == null:
		return
	var next := state.duplicate(true)
	next["carried"].append(best.get_meta("item"))
	next["picked"].append(String(best.name))
	_commit(next)


func _server_tool_next(sender: int) -> void:
	if sender != Net.peer_for_character(Characters.Character.IMAD):
		return
	var tools: Array = state.get("tools", [])
	if tools.size() < 2:
		return
	var next := state.duplicate(true)
	next["current_tool"] = tools[(tools.find(state["current_tool"]) + 1) % tools.size()]
	_commit(next)


func _commit(next: Dictionary) -> void:
	_rpc_state.rpc(next)
	_apply(next)


@rpc("authority", "call_remote", "reliable")
func _rpc_state(next: Dictionary) -> void:
	_apply(next)


func _apply(next: Dictionary) -> void:
	var previous_mount := mount_state()
	state = next
	Events.state_changed.emit()
	if mount_state() != previous_mount:
		Events.mount_changed.emit(mount_state())
		Events.context_changed.emit()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
