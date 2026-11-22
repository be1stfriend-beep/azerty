class_name Bjorn
extends PlayerBase

const STATE_KICK := 2
const KICK_SECONDS := 0.36
const NUDGE_HEIGHT := 0.3
const NUDGE_SECONDS := 0.15

var _jump_speed: float
var _merged_speed: float
var _merged_jump_mult: float
var _kick_left := 0.0
var _cooldown_left := 0.0
## Host-side clock of the last accepted kick, so a client cannot kick faster than the cooldown.
var _last_kick_msec := -1000000


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
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var mount := TeamState.mount_state()
	if mount == MountController.MOUNTING:
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _jump_speed if _is_solo() else _jump_speed * _merged_jump_mult
	if Input.is_action_just_pressed("kick") and _cooldown_left <= 0.0:
		_cooldown_left = float(Data.balance("kick_cooldown"))
		_kick_left = KICK_SECONDS
		rig.kick()
		_nudge_trash()
		request_kick()
	if mount == MountController.MERGED and Input.is_action_just_pressed("dismount"):
		var controller := get_parent().get_node_or_null("MountController") as MountController
		if controller != null:
			controller.request_dismount()


func _extra_state() -> int:
	return STATE_KICK if _kick_left > 0.0 else 0


func _on_remote_state(state: int, previous: int) -> void:
	if (state & STATE_KICK) != 0 and (previous & STATE_KICK) == 0:
		rig.kick()
		_nudge_trash()


## Visual only: loose trash in front hops in place, so the peers never disagree on where it lies.
func _nudge_trash() -> void:
	var picked: Array = TeamState.state.get("picked", [])
	for node: Node in get_parent().get_node("Entities").get_children():
		if node.get_meta("kind", "") != "trash" or String(node.name) in picked:
			continue
		var trash := node as Node3D
		var to_trash := trash.global_position - global_position
		to_trash.y = 0.0
		if to_trash.length() > float(Data.balance("kick_range")) or global_basis.z.dot(to_trash.normalized()) < float(Data.balance("kick_facing_dot")):
			continue
		var tween := trash.create_tween()
		tween.tween_property(trash, "position:y", trash.position.y + NUDGE_HEIGHT, NUDGE_SECONDS).set_ease(Tween.EASE_OUT)
		tween.tween_property(trash, "position:y", trash.position.y, NUDGE_SECONDS).set_ease(Tween.EASE_IN)


func _is_solo() -> bool:
	return TeamState.mount_state() == MountController.SOLO


## The swing itself plays locally and replicates through the sync state bit; only the hit is asked for.
func request_kick() -> void:
	if multiplayer.is_server():
		server_kick(multiplayer.get_unique_id())
	else:
		_rpc_request_kick.rpc_id(SERVER_PEER)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_kick() -> void:
	if multiplayer.is_server():
		server_kick(multiplayer.get_remote_sender_id())


func server_kick(sender: int) -> void:
	if sender != Net.peer_for_character(Characters.Character.BJORN) or TeamState.mount_state() == MountController.MOUNTING:
		return
	var now := Time.get_ticks_msec()
	if now - _last_kick_msec < int(float(Data.balance("kick_cooldown")) * 1000.0):
		return
	_last_kick_msec = now
	var target := _kick_target()
	if target == null:
		return
	var stunned := target.machine.state == Cockroach.STUNNED
	target.take_damage(int(Data.balance("kick_damage_stunned" if stunned else "kick_damage")), character)
	target.push(global_basis.z * float(Data.balance("kick_knockback")))


## Range is measured to the roach's shell, not its centre, and Bjorn must be facing it.
func _kick_target() -> Cockroach:
	for node in get_tree().get_nodes_in_group("vermin"):
		var vermin := node as Cockroach
		if vermin == null:
			continue
		var to_target := vermin.global_position - global_position
		to_target.y = 0.0
		var in_range := to_target.length() - Cockroach.BODY_RADIUS <= float(Data.balance("kick_range"))
		if in_range and global_basis.z.dot(to_target.normalized()) >= float(Data.balance("kick_facing_dot")):
			return vermin
	return null
