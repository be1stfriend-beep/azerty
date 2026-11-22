class_name Imad
extends PlayerBase
## Solo: crawls on his cart. Mounted: sits at Bjorn's Saddle and aims the tool.

const SEAT_OFFSET := Vector3(0, -0.35, 0)
const SOLO_RETICLE_DISTANCE := 1.2
const AIM_DEADZONE := 0.2
const RETICLE_HEIGHT := 0.05
const RETICLE_THICKNESS := 0.08
const RETICLE_FLATTEN := 0.2

var aim := Vector2(0, 1)
var bjorn_in_range := false

var _riding := false
var _reach: float
var _aim_elapsed := 0.0
var _reticle: MeshInstance3D
var _station: Interactable


func _init() -> void:
	name = "imad"
	character = Characters.Character.IMAD


func _ready() -> void:
	move_speed = Data.balance("imad_crawl")
	_reach = Data.balance("tongs_reach")
	super._ready()
	_reticle = _build_reticle()
	add_child(_reticle)
	Events.mount_changed.connect(_on_mount_changed)


func _physics_process(delta: float) -> void:
	var bjorn := get_parent().get_node_or_null("bjorn") as PlayerBase
	if _riding and bjorn != null:
		_ride(bjorn, delta)
	else:
		super._physics_process(delta)
	if is_multiplayer_authority():
		_read_actions(bjorn, delta)
	_reticle.global_position = reticle_point(bjorn) + Vector3.UP * RETICLE_HEIGHT


func reticle_point(bjorn: PlayerBase) -> Vector3:
	if _riding and bjorn != null:
		return bjorn.global_position + Vector3(aim.x, 0.0, aim.y) * _reach
	return global_position + global_basis.z * SOLO_RETICLE_DISTANCE


func _build_rig() -> CharacterBuilder:
	return CharacterBuilder.build_imad()


func _collider_radius() -> float:
	return 0.45


func _collider_height() -> float:
	return 1.2


## Nobody owns the rider's transform: every peer computes it from the Saddle.
func _ride(bjorn: PlayerBase, delta: float) -> void:
	var saddle := bjorn.rig.body.get_node("Saddle") as Node3D
	global_position = saddle.global_position + SEAT_OFFSET
	rotation.y = bjorn.rotation.y
	velocity = bjorn.velocity
	reset_remote_target()
	rig.update_wobble(delta, velocity, true)


func _read_actions(bjorn: PlayerBase, delta: float) -> void:
	var controller := get_parent().get_node_or_null("MountController") as MountController
	if controller == null or bjorn == null:
		return
	if Input.is_action_just_pressed("tool_next"):
		TeamState.request_tool_next()
	_read_interact(bjorn if _riding else self)
	if _riding:
		var input := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if input.length() > AIM_DEADZONE:
			aim = input
		_send_aim(delta)
		if Input.is_action_just_pressed("use_tool"):
			TeamState.request_use_tool(reticle_point(bjorn))
		if TeamState.mount_state() == MountController.MERGED and Input.is_action_just_pressed("dismount"):
			controller.request_dismount()
		return
	var in_range := controller.can_mount(self, bjorn)
	if in_range != bjorn_in_range:
		bjorn_in_range = in_range
		Events.context_changed.emit()
	var perch_remount: bool = TeamState.state.get("on_perch", false) and Input.is_action_just_pressed("interact")
	if in_range and (Input.is_action_just_pressed("mount") or perch_remount):
		controller.request_mount()
	if Input.is_action_just_pressed("grab") or Input.is_action_just_pressed("use_tool"):
		TeamState.request_use_tool(reticle_point(bjorn))


## Interact counts from the body: Bjorn's when riding, Imad's own when solo.
func _read_interact(body: PlayerBase) -> void:
	if Input.is_action_just_pressed("interact"):
		_station = _nearest_station(body.global_position)
		if _station != null:
			_station.interact(self)
	if Input.is_action_just_released("interact") and _station != null:
		_station.release(self)
		_station = null


func _nearest_station(point: Vector3) -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for node: Node in get_parent().get_node("Entities").get_children():
		var station := node as Interactable
		if station == null or not station.in_range(point):
			continue
		var distance := StationRules.flat_distance(point, station.global_position)
		if distance < best_distance:
			best = station
			best_distance = distance
	return best


func _send_aim(delta: float) -> void:
	_aim_elapsed += delta
	if _aim_elapsed < _sync_interval:
		return
	_aim_elapsed = 0.0
	_rpc_aim.rpc(aim)


@rpc("authority", "call_remote", "unreliable")
func _rpc_aim(value: Vector2) -> void:
	aim = value


func _on_mount_changed(mount: String) -> void:
	var riding := mount != MountController.SOLO
	if riding == _riding:
		return
	_riding = riding
	(rig.body.get_node("Cart") as Node3D).visible = not riding
	collision_shape.disabled = riding
	if not riding:
		# Same position on every peer: it comes from the host through TeamState.
		global_position = TeamState.state.get("dismount_pos", global_position)
		velocity = Vector3.ZERO
		reset_remote_target()
	if bjorn_in_range:
		bjorn_in_range = false
		Events.context_changed.emit()


func _build_reticle() -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = float(Data.balance("tongs_radius")) - RETICLE_THICKNESS
	mesh.outer_radius = float(Data.balance("tongs_radius"))
	mesh.rings = ProcProps.SEGMENTS * 2
	mesh.ring_segments = ProcProps.SPHERE_RINGS
	var ring := MeshInstance3D.new()
	ring.name = "Reticle"
	ring.mesh = mesh
	ring.top_level = true
	ring.scale = Vector3(1, RETICLE_FLATTEN, 1)
	ring.set_meta("tint_group", "char_white")
	Style.apply(ring)
	return ring
