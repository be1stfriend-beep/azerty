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

var _phase_left := 0.0
var _cycles := 0


func _init() -> void:
	# Fixed name: RPCs resolve by node path, which must match on both peers.
	name = "MountController"


func _ready() -> void:
	Events.mount_changed.connect(_on_mount_changed)
	Net.partner_lost.connect(_on_partner_lost)


func _process(delta: float) -> void:
	if not multiplayer.is_server() or _phase_left <= 0.0:
		return
	_phase_left -= delta
	if _phase_left > 0.0:
		return
	match TeamState.mount_state():
		MOUNTING:
			TeamState.set_mount(MERGED)
		DISMOUNTING:
			TeamState.set_mount(SOLO)


func can_mount(imad: Node3D, bjorn: Node3D) -> bool:
	return TeamState.mount_state() == SOLO \
		and imad.global_position.distance_to(bjorn.global_position) <= float(Data.balance("mount_range"))


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


@rpc("authority", "call_remote", "reliable")
func _rpc_message(text: String) -> void:
	Game.show_message(text)


func _server_mount(sender: int) -> void:
	var imad := _player("imad")
	var bjorn := _player("bjorn")
	if sender != Net.peer_for_character(Characters.Character.IMAD) or imad == null or bjorn == null:
		return
	if not can_mount(imad, bjorn):
		return
	_phase_left = Data.balance("mount_time")
	TeamState.set_mount(MOUNTING)


func _server_dismount(sender: int) -> void:
	var bjorn := _player("bjorn")
	var players := [Net.peer_for_character(Characters.Character.BJORN), Net.peer_for_character(Characters.Character.IMAD)]
	if not (sender in players) or bjorn == null or TeamState.mount_state() != MERGED:
		return
	var drop: Variant = _free_drop(bjorn)
	if drop == null:
		_tell(sender, "No room to climb down here")
		return
	_phase_left = Data.balance("dismount_time")
	TeamState.set_mount(DISMOUNTING, drop)


func _free_drop(bjorn: Node3D) -> Variant:
	var space := bjorn.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = DROP_PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = WORLD_MASK
	var forward := bjorn.global_basis.z
	forward.y = 0.0
	for angle in DROP_ANGLES:
		var spot := bjorn.global_position + forward.normalized().rotated(Vector3.UP, deg_to_rad(angle)) * DROP_DISTANCE
		query.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * DROP_PROBE_HEIGHT)
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return null


func _tell(peer: int, text: String) -> void:
	if peer == multiplayer.get_unique_id():
		Game.show_message(text)
	else:
		_rpc_message.rpc_id(peer, text)


func _player(player_name: String) -> Node3D:
	return get_parent().get_node_or_null(player_name) as Node3D


func _on_mount_changed(mount: String) -> void:
	if mount == SOLO:
		_cycles += 1
		NetMeter.set_line("mount cycles", str(_cycles))
	var own := "Bjorn" if Net.own_character() == Characters.Character.BJORN else "Imad"
	NetMeter.set_line("name", "BJIMAD" if mount == MERGED else own)


func _on_partner_lost() -> void:
	var imad := _player("imad")
	if imad != null:
		_phase_left = 0.0
		TeamState.force_solo(imad.global_position)
