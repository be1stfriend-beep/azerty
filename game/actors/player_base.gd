class_name PlayerBase
extends CharacterBody3D
## Owner-authoritative movement: the owning peer moves and broadcasts, the other interpolates.

const PLAYER_LAYER := 2
const WORLD_MASK := 1
const SNAP_DISTANCE := 6.0
const ACCELERATION := 40.0
const TURN_SPEED := 12.0
const MOVE_DEADZONE := 0.1
const STATE_GROUNDED := 1
const KNOCK_UP_SPEED := 4.0
const SERVER_PEER := 1

var character: int = Characters.Character.BJORN
var move_speed: float = 0.0
var rig: CharacterBuilder
var collision_shape: CollisionShape3D

var _gravity: float
var _sync_interval: float
var _interp_lerp: float
var _sync_elapsed := 0.0
var _target_position := Vector3.ZERO
var _target_rot_y := 0.0
var _target_velocity := Vector3.ZERO
var _remote_state := 0


func _ready() -> void:
	set_multiplayer_authority(Net.peer_for_character(character))
	collision_layer = PLAYER_LAYER
	collision_mask = WORLD_MASK
	_gravity = Data.balance("gravity")
	_sync_interval = 1.0 / float(Data.balance("sync_hz"))
	_interp_lerp = Data.balance("interp_lerp")
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = _collider_radius()
	capsule.height = _collider_height()
	collision_shape.shape = capsule
	collision_shape.position.y = capsule.height * 0.5
	add_child(collision_shape)
	rig = _build_rig()
	add_child(rig)
	_target_position = global_position


func _physics_process(delta: float) -> void:
	var grounded: bool
	if is_multiplayer_authority():
		_local_move(delta)
		grounded = is_on_floor()
		_send_sync(delta)
	else:
		_remote_follow(delta)
		grounded = (_remote_state & STATE_GROUNDED) != 0
	rig.update_wobble(delta, velocity, grounded)


func _local_move(delta: float) -> void:
	var input := _move_input()
	var direction := Vector3(input.x, 0.0, input.y)
	var speed := _current_speed()
	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	_action_input(delta)
	move_and_slide()
	DomeGate.hold_inside(self)
	if direction.length() > MOVE_DEADZONE:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)


func _send_sync(delta: float) -> void:
	_sync_elapsed += delta
	if _sync_elapsed < _sync_interval:
		return
	_sync_elapsed = 0.0
	var state := (STATE_GROUNDED if is_on_floor() else 0) | _extra_state()
	_rpc_sync.rpc(global_position, rotation.y, velocity, state)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync(pos: Vector3, rot_y: float, vel: Vector3, state: int) -> void:
	_on_remote_state(state, _remote_state)
	_target_position = pos
	_target_rot_y = rot_y
	_target_velocity = vel
	_remote_state = state


func _remote_follow(delta: float) -> void:
	if global_position.distance_to(_target_position) > SNAP_DISTANCE:
		global_position = _target_position
		return
	var weight := 1.0 - exp(-_interp_lerp * delta)
	global_position = global_position.lerp(_target_position, weight)
	rotation.y = lerp_angle(rotation.y, _target_rot_y, weight)
	# Smoothed so the wobble does not jerk at every 20 Hz packet.
	velocity = velocity.lerp(_target_velocity, weight)


func _build_rig() -> CharacterBuilder:
	return CharacterBuilder.new()


func _collider_radius() -> float:
	return 0.3


func _collider_height() -> float:
	return 1.0


func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _current_speed() -> float:
	return move_speed


func respawn(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	reset_remote_target()


## Sent by the host to every peer; only the owner of this body applies it.
@rpc("any_peer", "call_local", "reliable")
func knock_back(offset: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER or not is_multiplayer_authority():
		return
	# Speed that the movement deceleration brings to rest after exactly this distance.
	var speed := sqrt(2.0 * ACCELERATION * offset.length())
	velocity = offset.normalized() * speed + Vector3.UP * KNOCK_UP_SPEED


## Remotes stop interpolating toward a stale packet, e.g. after the rider was placed by the mount.
func reset_remote_target() -> void:
	_target_position = global_position
	_target_velocity = velocity


func _action_input(_delta: float) -> void:
	pass


func _extra_state() -> int:
	return 0


func _on_remote_state(_state: int, _previous: int) -> void:
	pass
