extends Node3D
## Pressure plate: active while any player stands on it (or forever once pressed, if latched).
## The host decides; every peer recolours it from TeamState.plates.

## A player counts only when standing at the plate's height, so a plate on a ledge ignores the ground.
const HEIGHT_TOLERANCE := 0.6

var latched := false
var activates := ""

var _vents_off_left := 0.0


func _ready() -> void:
	var params: Dictionary = get_meta("params", {})
	latched = params.get("latched", false)
	activates = params.get("activates", "")
	Events.state_changed.connect(_refresh_look)
	_refresh_look()


func is_active() -> bool:
	return bool((TeamState.state.get("plates", {}) as Dictionary).get(String(name), false))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or TeamState.state.is_empty():
		return
	var active := is_active()
	var next_active := _anyone_on() or (latched and active)
	if next_active != active:
		var plates: Dictionary = (TeamState.state.get("plates", {}) as Dictionary).duplicate()
		plates[String(name)] = next_active
		var changes := {"plates": plates}
		# The window opens on the press itself and then runs on its own timer.
		if next_active and activates == "vents_off":
			changes["vents_off"] = true
			_vents_off_left = float(Data.balance("valve_seconds"))
		TeamState.set_values(changes)
	if _vents_off_left > 0.0:
		_vents_off_left -= delta
		if _vents_off_left <= 0.0:
			TeamState.set_values({"vents_off": false})


func _anyone_on() -> bool:
	var radius := float(Data.balance("plate_radius"))
	for player in RoachTargets.players():
		var on_top := absf(player.global_position.y - global_position.y) < HEIGHT_TOLERANCE
		if on_top and StationRules.flat_distance(player.global_position, global_position) <= radius:
			return true
	return false


func _refresh_look() -> void:
	var disc := get_node_or_null("Visual/Disc") as MeshInstance3D
	if disc != null:
		disc.material_override = Style.material("teal" if is_active() else "danger")
