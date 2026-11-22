extends Node
## Host-owned shared state. The host builds the next dictionary, then pushes all of it.
## Clients only receive it. Rules live in StationRules and MountController.

var state: Dictionary = {}


func reset() -> void:
	if not multiplayer.is_server():
		return
	_commit({
		"carried": [], "carried_ids": [], "drops": {}, "holding": "", "plates": {}, "vents_off": false, "stash": {}, "tools": ["tongs"], "current_tool": "tongs",
		"inventory": {}, "picked": [], "towers": [],
		"mount": MountController.SOLO, "dismount_pos": Vector3.ZERO,
		"air": float(Data.balance("air_max")), "hold_progress": 0.0, "on_perch": false,
	})


func clear() -> void:
	state = {}


func mount_state() -> String:
	return state.get("mount", MountController.SOLO)


# --- Requests (SPEC 6.5 pattern) ---

func request_use_tool(point: Vector3) -> void:
	if multiplayer.is_server():
		_server_use_tool(point, multiplayer.get_unique_id())
	else:
		_rpc_request_use_tool.rpc_id(1, point)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_use_tool(point: Vector3) -> void:
	if multiplayer.is_server():
		_server_use_tool(point, multiplayer.get_remote_sender_id())


## The context button always grabs with the tongs, whatever tool is equipped.
func request_grab(point: Vector3) -> void:
	if multiplayer.is_server():
		_server_grab(point, multiplayer.get_unique_id())
	else:
		_rpc_request_grab.rpc_id(1, point)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_grab(point: Vector3) -> void:
	if multiplayer.is_server():
		_server_grab(point, multiplayer.get_remote_sender_id())


func request_tool_next() -> void:
	if multiplayer.is_server():
		_server_tool_next(multiplayer.get_unique_id())
	else:
		_rpc_request_tool_next.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_tool_next() -> void:
	if multiplayer.is_server():
		_server_tool_next(multiplayer.get_remote_sender_id())


func request_recycle(station_id: String) -> void:
	if multiplayer.is_server():
		_server_recycle(station_id, multiplayer.get_unique_id())
	else:
		_rpc_request_recycle.rpc_id(1, station_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_recycle(station_id: String) -> void:
	if multiplayer.is_server():
		_server_recycle(station_id, multiplayer.get_remote_sender_id())


func request_craft(recipe_id: String) -> void:
	if multiplayer.is_server():
		_server_craft(recipe_id, multiplayer.get_unique_id())
	else:
		_rpc_request_craft.rpc_id(1, recipe_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_craft(recipe_id: String) -> void:
	if multiplayer.is_server():
		_server_craft(recipe_id, multiplayer.get_remote_sender_id())


func request_hold(station_id: String, held: bool) -> void:
	if multiplayer.is_server():
		_server_hold(station_id, held, multiplayer.get_unique_id())
	else:
		_rpc_request_hold.rpc_id(1, station_id, held)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_hold(station_id: String, held: bool) -> void:
	if multiplayer.is_server():
		_server_hold(station_id, held, multiplayer.get_remote_sender_id())


# --- Host-side validation ---

func _server_use_tool(point: Vector3, sender: int) -> void:
	var imad := Game.player(Characters.Character.IMAD)
	if not _is_imad(sender) or imad == null:
		return
	match state.get("current_tool"):
		"tongs":
			_server_grab(point, sender)
		"broomstick":
			var roach := Game.world.get_node_or_null("cockroach") as Cockroach
			var reach := float(Data.balance("tongs_reach")) + float(Data.balance("broom_radius"))
			if roach != null and StationRules.flat_distance(imad.global_position, point) <= reach:
				roach.server_broom_hit(point, imad)


func _server_grab(point: Vector3, sender: int) -> void:
	var imad := Game.player(Characters.Character.IMAD)
	if _is_imad(sender) and imad != null:
		_commit_if(StationRules.tongs(state, point, imad.global_position, Game.world.get_node("Entities")))


func _server_tool_next(sender: int) -> void:
	if _is_imad(sender):
		_commit_if(StationRules.next_tool(state))


func _server_recycle(station_id: String, sender: int) -> void:
	var station := Interactable.near_team_body(station_id, "recycler")
	if not _is_imad(sender) or station == null:
		return
	if _commit_if(StationRules.recycle(state)):
		station.rpc("play_effect")


func _server_craft(recipe_id: String, sender: int) -> void:
	if not _is_imad(sender) or not Interactable.any_near_team_body("bench"):
		return
	if _commit_if(StationRules.craft(state, recipe_id)):
		_rpc_invented.rpc(recipe_id)


func _server_hold(station_id: String, held: bool, sender: int) -> void:
	var station := Interactable.near_team_body(station_id, "tower")
	if _is_imad(sender) and station != null:
		station.call("server_hold", held, sender)


# --- Host-side mutations used by stations and systems ---

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


## Air changes every frame, so it bypasses the reliable full-state push: the host sets it
## locally and AirSystem sends it unreliably at air_sync_hz.
func apply_air(value: float) -> void:
	if state.is_empty():
		return
	state["air"] = value
	Events.air_changed.emit(value)


## Host only: merge changes into the state and push it.
func set_values(changes: Dictionary) -> void:
	var next := state.duplicate(true)
	next.merge(changes, true)
	_commit(next)


func commit(next: Dictionary) -> void:
	if multiplayer.is_server():
		_commit(next)


@rpc("authority", "call_local", "reliable")
func _rpc_invented(recipe_id: String) -> void:
	Events.item_crafted.emit(recipe_id)


# --- Replication ---

func _commit_if(next: Dictionary) -> bool:
	if next.is_empty():
		return false
	_commit(next)
	return true


func _commit(next: Dictionary) -> void:
	_rpc_state.rpc(next)
	_apply(next)


@rpc("authority", "call_remote", "reliable")
func _rpc_state(next: Dictionary) -> void:
	_apply(next)


func _apply(next: Dictionary) -> void:
	var previous_mount := mount_state()
	var previous_air: Variant = state.get("air")
	state = next
	Events.state_changed.emit()
	if state.get("air") != previous_air:
		Events.air_changed.emit(float(state.get("air", 0.0)))
	if mount_state() != previous_mount:
		Events.mount_changed.emit(mount_state())
		Events.context_changed.emit()


func _is_imad(sender: int) -> bool:
	return sender == Net.peer_for_character(Characters.Character.IMAD) and Game.world != null
