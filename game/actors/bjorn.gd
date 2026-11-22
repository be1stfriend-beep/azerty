class_name Bjorn
extends PlayerBase

const STATE_KICK := 2
const KICK_SECONDS := 0.36

var _jump_speed: float
var _kick_left := 0.0


func _init() -> void:
	name = "bjorn"
	character = Characters.Character.BJORN


func _ready() -> void:
	move_speed = Data.balance("bjorn_walk")
	_jump_speed = Data.balance("bjorn_jump")
	super._ready()


func _build_rig() -> CharacterBuilder:
	return CharacterBuilder.build_bjorn()


func _collider_radius() -> float:
	return 0.3


func _collider_height() -> float:
	return 1.9


func _action_input(delta: float) -> void:
	_kick_left = maxf(_kick_left - delta, 0.0)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _jump_speed
	if Input.is_action_just_pressed("kick") and _kick_left <= 0.0:
		_kick_left = KICK_SECONDS
		rig.kick()


func _extra_state() -> int:
	return STATE_KICK if _kick_left > 0.0 else 0


func _on_remote_state(state: int, previous: int) -> void:
	if (state & STATE_KICK) != 0 and (previous & STATE_KICK) == 0:
		rig.kick()
