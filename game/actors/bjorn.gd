class_name Bjorn
extends PlayerBase

const STATE_KICK := 2
const KICK_SECONDS := 0.36

var _jump_speed: float
var _merged_speed: float
var _merged_jump_mult: float
var _kick_left := 0.0


func _init() -> void:
	name = "bjorn"
	character = Characters.Character.BJORN


func _ready() -> void:
	move_speed = Data.balance("bjorn_walk")
	_jump_speed = Data.balance("bjorn_jump")
	_merged_speed = Data.balance("merged_speed")
	_merged_jump_mult = Data.balance("merged_jump_mult")
	super._ready()


func _build_rig() -> CharacterBuilder:
	return CharacterBuilder.build_bjorn()


func _collider_radius() -> float:
	return 0.3


func _collider_height() -> float:
	return 1.9


## Inputs are locked while the rider climbs on.
func _move_input() -> Vector2:
	if TeamState.mount_state() == MountController.MOUNTING:
		return Vector2.ZERO
	return super._move_input()


func _current_speed() -> float:
	return move_speed if _is_solo() else _merged_speed


func _action_input(delta: float) -> void:
	_kick_left = maxf(_kick_left - delta, 0.0)
	var mount := TeamState.mount_state()
	if mount == MountController.MOUNTING:
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _jump_speed if _is_solo() else _jump_speed * _merged_jump_mult
	if _is_solo() and Input.is_action_just_pressed("kick") and _kick_left <= 0.0:
		_kick_left = KICK_SECONDS
		rig.kick()
	if mount == MountController.MERGED and Input.is_action_just_pressed("dismount"):
		var controller := get_parent().get_node_or_null("MountController") as MountController
		if controller != null:
			controller.request_dismount()


func _extra_state() -> int:
	return STATE_KICK if _kick_left > 0.0 else 0


func _on_remote_state(state: int, previous: int) -> void:
	if (state & STATE_KICK) != 0 and (previous & STATE_KICK) == 0:
		rig.kick()


func _is_solo() -> bool:
	return TeamState.mount_state() == MountController.SOLO
