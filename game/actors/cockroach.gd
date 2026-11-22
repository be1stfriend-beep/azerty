class_name Cockroach
extends Node3D
## Boss logic runs on the host only. Clients render the replicated transform and play the tells.

const IDLE := "Idle"
const CHASE := "Chase"
const WINDUP := "WindUp"
const CHARGE := "Charge"
const STUNNED := "Stunned"
const FLEE := "Flee"
const GONE := "Gone"

const WINDUP_DISTANCE := 7.0
const BODY_RADIUS := 1.4
const PLAYER_HIT_RADIUS := 1.8
const PILLAR_HALF_SIZE := 1.0
const KNOCKBACK_DISTANCE := 4.0
## Safety net only: fleeing normally ends on arrival at the spawn marker.
const FLEE_SECONDS := 10.0
const FLEE_ARRIVE_DISTANCE := 1.0
const FLEE_SPEED_MULT := 2.0
const TURN_SPEED := 8.0
const SNAP_DISTANCE := 6.0

var machine := StateMachine.new(IDLE)
var hits := 0

var _spawn := Vector3.ZERO
var _charge_dir := Vector3.FORWARD
var _rig: RoachBuilder
var _sync_elapsed := 0.0
var _target_position := Vector3.ZERO
var _target_rot_y := 0.0


func _init() -> void:
	name = "cockroach"


func _ready() -> void:
	_spawn = position
	_target_position = position
	_rig = RoachBuilder.build()
	add_child(_rig)
	machine.changed.connect(_on_local_state_changed)


func _process(delta: float) -> void:
	if multiplayer.is_server():
		_think(delta)
		_send_sync(delta)
	elif position.distance_to(_target_position) > SNAP_DISTANCE:
		position = _target_position
	else:
		var weight := 1.0 - exp(-float(Data.balance("interp_lerp")) * delta)
		position = position.lerp(_target_position, weight)
		rotation.y = lerp_angle(rotation.y, _target_rot_y, weight)
	_rig.animate(delta, machine.state in [CHASE, CHARGE, FLEE])


## Host: both players ran out of air, so the fight starts over.
func reset() -> void:
	if machine.state == GONE:
		return
	hits = 0
	position = _spawn
	_set_state(IDLE)


## Host: a broom swing from Imad. Only counts while stunned.
func server_broom_hit(point: Vector3, imad: PlayerBase) -> void:
	if machine.state != STUNNED:
		return
	var near_aim := StationRules.flat_distance(point, position) <= float(Data.balance("broom_radius"))
	var from_perch := RoachTargets.is_on_perch(imad) and StationRules.flat_distance(imad.global_position, position) <= float(Data.balance("roach_perch_hit_range"))
	if not (near_aim or from_perch):
		return
	hits += 1
	_rpc_shake.rpc()
	if hits >= int(Data.balance("roach_hits_to_flee")):
		_set_state(FLEE)


func _think(delta: float) -> void:
	machine.tick(delta)
	var target := RoachTargets.nearest(position)
	match machine.state:
		IDLE:
			for player in RoachTargets.players():
				if player.global_position.distance_to(position) <= float(Data.balance("roach_wake_distance")):
					_set_state(CHASE)
		CHASE:
			if target == null:
				return
			_face(target.global_position, delta)
			var to_target := _flat(target.global_position - position)
			position += to_target.normalized() * float(Data.balance("roach_chase_speed")) * delta
			if to_target.length() <= WINDUP_DISTANCE:
				_set_state(WINDUP)
		WINDUP:
			if target != null:
				_face(target.global_position, delta)
			if machine.elapsed >= float(Data.balance("roach_windup")):
				_charge_dir = global_basis.z
				_set_state(CHARGE)
		CHARGE:
			position += _charge_dir * float(Data.balance("roach_charge_speed")) * delta
			_check_charge_hits()
		STUNNED:
			if machine.elapsed >= float(Data.balance("roach_stun")):
				_set_state(CHASE)
		FLEE:
			# Back to the nest in the south: the Dome is north, so it never crosses it.
			_face(_spawn, delta)
			var to_spawn := _flat(_spawn - position)
			position += to_spawn.normalized() * float(Data.balance("roach_chase_speed")) * FLEE_SPEED_MULT * delta
			if to_spawn.length() <= FLEE_ARRIVE_DISTANCE or machine.elapsed >= FLEE_SECONDS:
				_set_state(GONE)


func _check_charge_hits() -> void:
	if _hits_pillar():
		_set_state(STUNNED)
		return
	for player in RoachTargets.valid():
		if StationRules.flat_distance(player.global_position, position + _charge_dir * BODY_RADIUS) <= PLAYER_HIT_RADIUS:
			_hit_player(player)
			_set_state(CHASE)
			return
	if machine.elapsed >= float(Data.balance("roach_charge_max")):
		_set_state(CHASE)


func _hit_player(player: PlayerBase) -> void:
	var air := Game.world.get_node_or_null("AirSystem") as AirSystem
	if air != null:
		air.damage(float(Data.balance("roach_hit_air")))
	player.knock_back.rpc(_charge_dir * KNOCKBACK_DISTANCE)


func _hits_pillar() -> bool:
	var pillar := Game.world.get_node_or_null("Entities/pillar_0") as Node3D
	if pillar == null:
		return false
	var head := position + _charge_dir * BODY_RADIUS
	var local := head - pillar.global_position
	var closest := Vector2(clampf(local.x, -PILLAR_HALF_SIZE, PILLAR_HALF_SIZE), clampf(local.z, -PILLAR_HALF_SIZE, PILLAR_HALF_SIZE))
	return Vector2(local.x, local.z).distance_to(closest) <= BODY_RADIUS * 0.5


func _face(point: Vector3, delta: float) -> void:
	var dir := _flat(point - position)
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-TURN_SPEED * delta))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _set_state(next: String) -> void:
	if next != machine.state:
		_rpc_state.rpc(next, hits)
		machine.change(next)


func _send_sync(delta: float) -> void:
	_sync_elapsed += delta
	if _sync_elapsed < 1.0 / float(Data.balance("sync_hz")):
		return
	_sync_elapsed = 0.0
	_rpc_sync.rpc(position, rotation.y, machine.state, machine.state == GONE)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync(pos: Vector3, rot_y: float, state: String, gate_open: bool) -> void:
	_target_position = pos
	_target_rot_y = rot_y
	# Redundant with the reliable state RPC; it only corrects a client that drifted.
	if gate_open and machine.state != GONE:
		machine.change(GONE)
	elif state != machine.state and machine.state != GONE:
		machine.change(state)


@rpc("authority", "call_remote", "reliable")
func _rpc_state(state: String, hit_count: int) -> void:
	hits = hit_count
	machine.change(state)


@rpc("authority", "call_local", "reliable")
func _rpc_shake() -> void:
	_rig.shake()


func _on_local_state_changed(state: String) -> void:
	_rig.set_windup(state == WINDUP)
	if state == IDLE:
		position = _spawn
		_target_position = _spawn
	if state == GONE:
		hide()
		Gate.open(Game.world)
	Events.boss_state_changed.emit(state)
