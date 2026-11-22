class_name DomeGate
extends Node3D
## Until the Mask exists the Dome edge holds the team in. There is no wall: each body's owner
## clamps itself from the shared TeamState, so neither peer can drift out on lag. Posts on the
## edge glow red while it is closed and green once the Mask is invented.

const POST_COUNT := 12
const POST_SIZE := Vector3(0.25, 1.6, 0.25)
const LAMP_RADIUS := 0.22
const LAMP_HEIGHT := 1.75

static var _last_message_msec := -1000000

var _lamps: Array[MeshInstance3D] = []


func _init() -> void:
	name = "DomeGate"


func _ready() -> void:
	var center: Vector3 = get_parent().get_meta("dome", Vector3.ZERO)
	var radius := float(Data.balance("dome_radius"))
	for i in POST_COUNT:
		var angle := TAU * i / POST_COUNT
		var post := Node3D.new()
		post.position = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		ProcProps.part(post, ProcProps.box(POST_SIZE), Vector3(0, POST_SIZE.y * 0.5, 0), "rust")
		_lamps.append(ProcProps.part(post, ProcProps.sphere(LAMP_RADIUS), Vector3(0, LAMP_HEIGHT, 0), "post_locked"))
		Style.apply(post)
		add_child(post)
	Events.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var lit := Style.material("post_open" if has_mask() else "post_locked")
	for lamp in _lamps:
		lamp.material_override = lit


static func has_mask() -> bool:
	return int((TeamState.state.get("inventory", {}) as Dictionary).get(Objective.SLICE_RECIPE, 0)) > 0


## Called by a body's owner right after it moves. Only active in levels that spawn a DomeGate.
static func hold_inside(player: PlayerBase) -> void:
	var world := Game.world
	if world == null or not world.has_node("DomeGate") or TeamState.state.is_empty() or has_mask():
		return
	var center: Vector3 = world.get_meta("dome", Vector3.ZERO)
	var offset := player.global_position - center
	offset.y = 0.0
	var radius := float(Data.balance("dome_radius"))
	if offset.length() <= radius:
		return
	var inward := -offset.normalized()
	player.global_position += inward * (offset.length() - radius + float(Data.balance("mask_gate_push")))
	var outward_speed := -player.velocity.dot(inward)
	if outward_speed > 0.0:
		player.velocity += inward * outward_speed
	var now := Time.get_ticks_msec()
	if now - _last_message_msec >= int(float(Data.balance("mask_gate_message_seconds")) * 1000.0):
		_last_message_msec = now
		Game.show_message(Data.hint("prompt_need_mask"))
