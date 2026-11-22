class_name MountController
extends Node
## Host-side mount state machine (SPEC 6.3). State lives in TeamState.mount.

const SOLO := "SOLO"
const MOUNTING := "MOUNTING"
const MERGED := "MERGED"
const DISMOUNTING := "DISMOUNTING"
const DROP_DISTANCE := 1.4
## Behind first (the rider sits on the back), then sides, then front.
const DROP_ANGLES: Array[float] = [180.0, 90.0, -90.0, 135.0, -135.0, 45.0, -45.0, 0.0]
const DROP_PROBE_RADIUS := 0.45
const DROP_PROBE_HEIGHT := 0.6
const WORLD_MASK := 1
const PERCH_HEIGHT := 2.5
## How close Bjorn's body must be to the perch to drop or collect the rider there.
const PERCH_RANGE := 3.0
## A transition lasting this many times its configured duration is treated as stuck.
const WATCHDOG_FACTOR := 2.0

var watchdog_fires := 0

var _phase_left := 0.0
var _stuck_for := 0.0
var _cycles := 0


func _init() -> void:
	# Fixed name: RPCs resolve by node path, which must match on both peers.
	name = "MountController"


func _ready() -> void:
	Events.mount_changed.connect(_on_mount_changed)
	Net.partner_lost.connect(_on_partner_lost)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_watch(delta)
	if _phase_left <= 0.0:
		return
	_phase_left -= delta
	if _phase_left <= 0.0:
		_finish_phase()


func _finish_phase() -> void:
	match TeamState.mount_state():
		MOUNTING:
			TeamState.set_values({"mount": MERGED})
		DISMOUNTING:
			TeamState.set_values({"mount": SOLO})


## Host safety net: a transition whose timer was lost (knockout, restart, missed request) would
## lock Bjorn's input forever, so it is pushed to its next state.
func _watch(delta: float) -> void:
	var mount := TeamState.mount_state()
	var limit := _phase_time(mount) * WATCHDOG_FACTOR
	if limit <= 0.0:
		_stuck_for = 0.0
		return
	_stuck_for += delta
	if _stuck_for <= limit:
		return
	watchdog_fires += 1
	var message := "forced %s on after %.1f s (%d)" % [mount, _stuck_for, watchdog_fires]
	print("mount watchdog: %s" % message)
	NetMeter.set_line("mount watchdog", message)
	_stuck_for = 0.0
	_phase_left = 0.0
	_finish_phase()


func _phase_time(mount: String) -> float:
	match mount:
		MOUNTING:
			return float(Data.balance("mount_time"))
		DISMOUNTING:
			return float(Data.balance("dismount_time"))
	return 0.0


func can_mount(imad: Node3D, bjorn: Node3D) -> bool:
	if TeamState.mount_state() != SOLO:
		return false
	if TeamState.state.get("on_perch", false):
		return _near_perch(bjorn)
	return imad.global_position.distance_to(bjorn.global_position) <= float(Data.balance("mount_range"))


func request_mount() -> void:
	if multiplayer.is_server():
		_server_mount(multiplayer.get_unique_id())
	else:
		_rpc_request_mount.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_mount() -> void:
	if multiplayer.is_server():
		_server_mount(multiplayer.get_remote_sender_id())


func request_dismount() -> void:
	if multiplayer.is_server():
		_server_dismount(multiplayer.get_unique_id())
	else:
		_rpc_request_dismount.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_dismount() -> void:
	if multiplayer.is_server():
		_server_dismount(multiplayer.get_remote_sender_id())


func _server_mount(sender: int) -> void:
	var imad := _player("imad")
	var bjorn := _player("bjorn")
	if sender != Net.peer_for_character(Characters.Character.IMAD) or imad == null or bjorn == null:
		return
	if not can_mount(imad, bjorn):
		return
	_phase_left = Data.balance("mount_time")
	TeamState.set_values({"mount": MOUNTING, "on_perch": false})


func _server_dismount(sender: int) -> void:
	var bjorn := _player("bjorn")
	var players := [Net.peer_for_character(Characters.Character.BJORN), Net.peer_for_character(Characters.Character.IMAD)]
	if not (sender in players) or bjorn == null or TeamState.mount_state() != MERGED:
		return
	if _near_perch(bjorn):
		_phase_left = Data.balance("dismount_time")
		var perch_top := _perch().global_position + Vector3.UP * PERCH_HEIGHT
		TeamState.set_values({"mount": DISMOUNTING, "dismount_pos": perch_top, "on_perch": true})
		return
	var drop: Variant = _free_drop(bjorn)
	if drop == null:
		# Refusing here could keep the pair merged forever in a tight spot; overlap is recoverable.
		drop = bjorn.global_position - _flat_forward(bjorn) * DROP_DISTANCE
		print("mount: no free drop spot, placing the rider behind Bjorn at %s" % drop)
		NetMeter.set_line("mount fallback drop", str(drop))
	_phase_left = Data.balance("dismount_time")
	TeamState.set_values({"mount": DISMOUNTING, "dismount_pos": drop})


func _free_drop(bjorn: Node3D) -> Variant:
	var space := bjorn.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = DROP_PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = WORLD_MASK
	var forward := _flat_forward(bjorn)
	for angle in DROP_ANGLES:
		var spot := bjorn.global_position + forward.rotated(Vector3.UP, deg_to_rad(angle)) * DROP_DISTANCE
		query.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * DROP_PROBE_HEIGHT)
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return null


func _flat_forward(bjorn: Node3D) -> Vector3:
	var forward := bjorn.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _perch() -> Node3D:
	return get_parent().get_node_or_null("Entities/perch_0") as Node3D


func _near_perch(bjorn: Node3D) -> bool:
	var perch := _perch()
	return perch != null and StationRules.flat_distance(bjorn.global_position, perch.global_position) <= PERCH_RANGE


func _player(player_name: String) -> Node3D:
	return get_parent().get_node_or_null(player_name) as Node3D


func _on_mount_changed(mount: String) -> void:
	_stuck_for = 0.0
	if mount == SOLO:
		_cycles += 1
		NetMeter.set_line("mount cycles", str(_cycles))


func _on_partner_lost() -> void:
	var imad := _player("imad")
	if imad != null:
		_phase_left = 0.0
		TeamState.force_solo(imad.global_position)
