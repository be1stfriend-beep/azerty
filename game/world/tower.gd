class_name Tower
extends Interactable
## Imad holds interact here for tower_hold_seconds with a Filter in the inventory.
## The host tracks the hold. Colour follows the replicated "towers" list, so both peers
## and a late joiner restore from the same state rather than from a one-shot RPC.

const PROGRESS_PUSH_STEP := 0.05

var index: int = 0

var _holding := false
var _elapsed := 0.0
var _pushed := 0.0
var _restored := false
var _ring: MeshInstance3D


func _ready() -> void:
	index = int(String(name).get_slice("_", 1))
	_ring = LevelLoader.ground_ring(float(Data.balance("tower_radius")), "tower_ring")
	_ring.name = "RadiusRing"
	_ring.visible = false
	add_child(_ring)
	# No check here: every new world receives a fresh state push after it loads.
	Events.state_changed.connect(_on_state_changed)


func interact(_player: PlayerBase) -> void:
	TeamState.request_hold(name, true)


func release(_player: PlayerBase) -> void:
	TeamState.request_hold(name, false)


func is_active() -> bool:
	return index in TeamState.state.get("towers", [])


## Host only.
func server_hold(held: bool, sender: int) -> void:
	if not held:
		_cancel()
		return
	if _holding or is_active():
		return
	if int(TeamState.state.get("inventory", {}).get("filter", 0)) < 1:
		Game.tell(sender, "The tower needs a Filter")
		return
	_holding = true
	_elapsed = 0.0
	TeamState.set_values({"holding": String(name)})


func _process(delta: float) -> void:
	if not _holding or not multiplayer.is_server():
		return
	var body := Game.team_body()
	if body == null or not in_range(body.global_position, HOST_RANGE_SLACK):
		_cancel()
		return
	_elapsed += delta
	var progress := minf(_elapsed / float(Data.balance("tower_hold_seconds")), 1.0)
	if progress >= 1.0:
		_holding = false
		_pushed = 0.0
		TeamState.commit(StationRules.activate_tower(TeamState.state, index))
	elif progress - _pushed >= PROGRESS_PUSH_STEP:
		_pushed = progress
		TeamState.set_values({"hold_progress": progress})


func _cancel() -> void:
	if not _holding:
		return
	_holding = false
	_pushed = 0.0
	TeamState.set_values({"hold_progress": 0.0, "holding": ""})


func _on_state_changed() -> void:
	if is_active():
		restore_colour()


## Local only: idempotent, so repeated state pushes restart nothing.
func restore_colour() -> void:
	if _restored:
		return
	_restored = true
	_ring.visible = true
	Style.set_tower(index, global_position, Data.balance("tower_radius"))
	Style.restore(index)
	Events.tower_activated.emit(index)
