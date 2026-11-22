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
## Slice: after giving up it sits at its lair and only wakes for players who come close.
const GUARD := "Guard"

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
const AWAKE_STATES: Array[String] = [CHASE, WINDUP, CHARGE, STUNNED]
## How close to the Dome ring counts as "at the edge" for the give-up roar.
const EDGE_TOLERANCE := 0.5
## How far past the ring the way home starts bending around the Dome.
const DOME_STEER_GAP := 3.0

var machine := StateMachine.new(IDLE)
var hp := 0
## Slice: hidden and asleep until SliceHunt sends it; gives up at the Dome edge, then guards its lair.
var hunt_only := false

var _spawn := Vector3.ZERO
var _lair := Vector3.ZERO
## Host: set once the first hunt ends; from then on every flee and knockout ends at the lair.
var _guarding := false
var _charge_dir := Vector3.FORWARD
var _rig: RoachBuilder
var _sync_elapsed := 0.0
var _target_position := Vector3.ZERO
var _target_rot_y := 0.0


func _init() -> void:
	name = "cockroach"
	add_to_group("vermin")


func _ready() -> void:
	_spawn = position
	_lair = position
	_target_position = position
	hp = int(Data.balance("roach_hp"))
	_rig = RoachBuilder.build()
	add_child(_rig)
	machine.changed.connect(_on_local_state_changed)
	visible = not hunt_only


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
	hp = int(Data.balance("roach_hp"))
	# Once it has given up a hunt, a knockout sends it home instead of restarting the hunt.
	if _guarding:
		position = _lair
		_set_state(GUARD)
	else:
		position = _spawn
		_set_state(IDLE)
	_refresh_bar()


## Host: the slice hunt starts here, wherever SliceHunt put the roach.
func server_hunt(spawn: Vector3) -> void:
	_rpc_hunt.rpc(spawn)
	_set_state(CHASE)


## Sent before the CHASE state on the same reliable channel, so it arrives first.
@rpc("authority", "call_local", "reliable")
func _rpc_hunt(spawn: Vector3) -> void:
	_spawn = spawn
	position = spawn
	_target_position = spawn
	show()


## Host: a broom swing from Imad. Only counts while stunned.
func server_broom_hit(point: Vector3, imad: PlayerBase) -> void:
	if machine.state != STUNNED:
		return
	var near_aim := StationRules.flat_distance(point, position) <= float(Data.balance("broom_radius"))
	var from_perch := RoachTargets.is_on_perch(imad) and StationRules.flat_distance(imad.global_position, position) <= float(Data.balance("roach_perch_hit_range"))
	if not (near_aim or from_perch):
		return
	take_damage(int(Data.balance("broom_damage")), Characters.Character.IMAD)


## Host: the shared vermin damage entry point. Damage never stuns, and a Charge always runs
## to its end; a roach emptied mid-charge flees as soon as the charge is over.
func take_damage(amount: int, source_character: int) -> void:
	if not multiplayer.is_server() or not (machine.state in AWAKE_STATES) or hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	var source := Game.player(source_character)
	var impact := position + Vector3.UP * BODY_RADIUS * 0.5
	if source != null:
		impact += _flat(source.global_position - position).limit_length(BODY_RADIUS)
	_rpc_hit.rpc(hp, impact)
	if hp == 0 and machine.state != CHARGE:
		_set_state(FLEE)


## Host: Bjorn's kick shoves the roach back a little, except mid-charge.
func push(offset: Vector3) -> void:
	if machine.state in AWAKE_STATES and machine.state != CHARGE:
		position += _flat(offset)


func _think(delta: float) -> void:
	machine.tick(delta)
	if hp == 0 and machine.state in AWAKE_STATES and machine.state != CHARGE:
		_set_state(FLEE)
		return
	var target := RoachTargets.nearest(position)
	match machine.state:
		IDLE:
			if hunt_only:
				return
			for player in RoachTargets.players():
				if player.global_position.distance_to(position) <= float(Data.balance("roach_wake_distance")):
					_set_state(CHASE)
		CHASE:
			if target == null:
				if hunt_only:
					_approach_dome_edge(delta)
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
				# Everyone made it inside: the windup was the give-up roar.
				if target == null and hunt_only:
					_set_state(FLEE)
					return
				_charge_dir = global_basis.z
				_set_state(CHARGE)
		CHARGE:
			position += _charge_dir * float(Data.balance("roach_charge_speed")) * delta
			_check_charge_hits()
		STUNNED:
			if machine.elapsed >= float(Data.balance("roach_stun")):
				_set_state(CHASE)
		FLEE:
			# Level: the nest is south of the Dome. Slice: the lair may lie behind it, so it walks around.
			var home := _lair if hunt_only else _spawn
			var to_home := _flat(home - position)
			var heading := _around_dome(to_home.normalized()) if hunt_only else to_home.normalized()
			_face(position + heading, delta)
			position += heading * float(Data.balance("roach_chase_speed")) * FLEE_SPEED_MULT * delta
			if hunt_only:
				if to_home.length() <= FLEE_ARRIVE_DISTANCE:
					_guarding = true
					hp = int(Data.balance("roach_hp"))
					_set_state(GUARD)
			elif to_home.length() <= FLEE_ARRIVE_DISTANCE or machine.elapsed >= FLEE_SECONDS:
				_set_state(GONE)
		GUARD:
			if target != null and StationRules.flat_distance(target.global_position, _lair) <= float(Data.balance("roach_guard_wake_distance")):
				_set_state(CHASE)
	position = RoachTargets.outside_dome(position, BODY_RADIUS)


## Slice: nobody left to chase, so it runs up to the Dome ring and roars there.
func _approach_dome_edge(delta: float) -> void:
	var center := RoachTargets.dome_center()
	_face(center, delta)
	var to_center := _flat(center - position)
	position += to_center.normalized() * float(Data.balance("roach_chase_speed")) * delta
	if to_center.length() <= float(Data.balance("dome_radius")) + BODY_RADIUS + EDGE_TOLERANCE:
		_set_state(WINDUP)


## The way home may lie across the Dome: near the ring it walks along the edge instead.
func _around_dome(dir: Vector3) -> Vector3:
	var out := _flat(position - RoachTargets.dome_center())
	if out.length() > float(Data.balance("dome_radius")) + BODY_RADIUS + DOME_STEER_GAP or dir.dot(out) >= 0.0:
		return dir
	out = out.normalized()
	var tangent := dir - out * dir.dot(out)
	if tangent.length() < 0.01:
		tangent = out.cross(Vector3.UP)
	return tangent.normalized()


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
		_rpc_state.rpc(next, hp)
		machine.change(next)


func _send_sync(delta: float) -> void:
	_sync_elapsed += delta
	if _sync_elapsed < 1.0 / float(Data.balance("sync_hz")):
		return
	_sync_elapsed = 0.0
	_rpc_sync.rpc(position, rotation.y, machine.state, machine.state == GONE, hp)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync(pos: Vector3, rot_y: float, state: String, gate_open: bool, health: int) -> void:
	_target_position = pos
	if health != hp:
		hp = health
		_refresh_bar()
	_target_rot_y = rot_y
	# Redundant with the reliable state RPC; it only corrects a client that drifted.
	if gate_open and machine.state != GONE:
		machine.change(GONE)
	elif state != machine.state and machine.state != GONE:
		machine.change(state)


@rpc("authority", "call_remote", "reliable")
func _rpc_state(state: String, health: int) -> void:
	hp = health
	machine.change(state)


@rpc("authority", "call_local", "reliable")
func _rpc_hit(health: int, impact: Vector3) -> void:
	hp = health
	_rig.shake()
	_rig.flash()
	_rig.pop(impact)
	_refresh_bar()


func _refresh_bar() -> void:
	_rig.set_health(float(hp) / float(Data.balance("roach_hp")), machine.state in AWAKE_STATES)


func _on_local_state_changed(state: String) -> void:
	_rig.set_windup(state == WINDUP)
	_refresh_bar()
	if state == IDLE:
		position = _spawn
		_target_position = _spawn
		visible = not hunt_only
	if state == GUARD:
		show()
	if state == GONE:
		hide()
		Gate.open(Game.world)
	Events.boss_state_changed.emit(state)
