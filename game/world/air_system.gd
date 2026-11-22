class_name AirSystem
extends Node
## Host ticks team air: safe inside the Dome and active tower radii, drains if anyone is outside.

var _air: float
var _air_max: float
var _sync_elapsed := 0.0


func _init() -> void:
	name = "AirSystem"


func _ready() -> void:
	_air_max = Data.balance("air_max")
	_air = _air_max


func is_safe(point: Vector3) -> bool:
	var world := get_parent()
	if StationRules.flat_distance(point, world.get_meta("dome", Vector3.ZERO)) <= float(Data.balance("dome_radius")):
		return true
	for index: int in TeamState.state.get("towers", []):
		var tower := world.get_node_or_null("Entities/tower_%d" % index) as Node3D
		if tower != null and StationRules.flat_distance(point, tower.global_position) <= float(Data.balance("tower_radius")):
			return true
	return false


## Host only.
func damage(amount: float) -> void:
	_air = maxf(_air - amount, 0.0)
	TeamState.set_values({"air": _air})


func _process(delta: float) -> void:
	if not multiplayer.is_server() or TeamState.state.is_empty():
		return
	var all_safe := true
	for character: int in [Characters.Character.BJORN, Characters.Character.IMAD]:
		var player := Game.player(character)
		if player != null and not is_safe(player.global_position):
			all_safe = false
	var drain := float(Data.balance("air_drain")) * (float(Data.balance("air_drain_mask_mult")) if DomeGate.has_mask() else 1.0)
	var rate: float = Data.balance("air_refill") if all_safe else -drain
	_air = clampf(_air + rate * delta, 0.0, _air_max)
	if _air <= 0.0:
		_out_of_air()
		return
	_sync_elapsed += delta
	if _sync_elapsed >= 1.0 / float(Data.balance("air_sync_hz")):
		_sync_elapsed = 0.0
		TeamState.apply_air(_air)
		_rpc_air.rpc(_air)


@rpc("authority", "call_remote", "unreliable")
func _rpc_air(value: float) -> void:
	TeamState.apply_air(value)


func _out_of_air() -> void:
	_air = _air_max
	var imad_spawn := get_parent().get_node("Markers/imad") as Node3D
	var body := Game.team_body()
	var fall_point := body.global_position if body != null else imad_spawn.global_position
	TeamState.commit(StationRules.out_of_air(TeamState.state, imad_spawn.global_position, fall_point))
	_rpc_respawn.rpc()
	var roach := get_parent().get_node_or_null("cockroach") as Cockroach
	if roach != null:
		roach.reset()


@rpc("authority", "call_local", "reliable")
func _rpc_respawn() -> void:
	for character: int in [Characters.Character.BJORN, Characters.Character.IMAD]:
		var player := Game.player(character)
		if player == null:
			continue
		var marker := get_parent().get_node_or_null("Markers/%s" % player.name) as Node3D
		if marker != null:
			player.respawn(marker.global_position)
	Game.show_message("Out of air. Back to the Dome. Your trash is where you fell.")
