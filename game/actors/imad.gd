class_name Imad
extends PlayerBase
## Solo: crawls on his arms. Mounted: sits at Bjorn's Saddle and aims the tool.

const SEAT_OFFSET := Vector3(0, -0.5, 0)
const SOLO_RETICLE_DISTANCE := 1.2
const AIM_DEADZONE := 0.2
const RETICLE_HEIGHT := 0.05
const RETICLE_THICKNESS := 0.08
const RETICLE_FLATTEN := 0.2

var aim := Vector2(0, 1)
## The rider is steering the aim with the right stick, so auto-targeting steps aside.
var aim_override := false

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
	Events.trash_picked.connect(_on_trash_picked)


func _physics_process(delta: float) -> void:
	var bjorn := get_parent().get_node_or_null("bjorn") as PlayerBase
	if _riding and bjorn != null:
		_ride(bjorn, delta)
	else:
		super._physics_process(delta)
	if is_multiplayer_authority():
		_read_actions(bjorn, delta)
	_reticle.visible = _riding and aim_override
	_reticle.global_position = reticle_point(bjorn) + Vector3.UP * RETICLE_HEIGHT


func reticle_point(bjorn: PlayerBase) -> Vector3:
	if _riding and bjorn != null:
		return bjorn.global_position + Vector3(aim.x, 0.0, aim.y) * _reach
	return global_position + global_basis.z * SOLO_RETICLE_DISTANCE


## On the perch he stays put until Bjorn collects him; crawling off would drop him into the fight.
func _move_input() -> Vector2:
	if TeamState.state.get("on_perch", false):
		return Vector2.ZERO
	return super._move_input()


func _build_rig() -> CharacterBuilder:
	return CrawlRig.build()


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
	if _riding:
		var input := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		aim_override = input.length() > AIM_DEADZONE
		if aim_override:
			aim = input
		_send_aim(delta)
	if Input.is_action_just_pressed("use_tool"):
		TeamState.request_use_tool(reticle_point(bjorn))
	_read_context()
	if not _riding and Input.is_action_just_pressed("mount") and controller.can_mount(self, bjorn):
		controller.request_mount()
	if TeamState.mount_state() == MountController.MERGED and Input.is_action_just_pressed("dismount"):
		controller.request_dismount()


## One button does everything; a station keeps the press until release (tower holds).
func _read_context() -> void:
	if Input.is_action_just_pressed("interact"):
		var context := Interaction.resolve(self)
		_station = context["target"] as Interactable if context["action"] == Interaction.STATION else null
		Interaction.perform(self, context)
	if Input.is_action_just_released("interact") and _station != null:
		_station.release(self)
		_station = null


func _send_aim(delta: float) -> void:
	_aim_elapsed += delta
	if _aim_elapsed < _sync_interval:
		return
	_aim_elapsed = 0.0
	_rpc_aim.rpc(aim, aim_override)


@rpc("authority", "call_remote", "unreliable")
func _rpc_aim(value: Vector2, overriding: bool) -> void:
	aim = value
	aim_override = overriding


## Every peer sees the tongs reach for the trash the host just accepted.
func _on_trash_picked(id: String) -> void:
	var trash := get_parent().get_node_or_null("Entities/%s" % id) as Node3D
	if trash != null:
		(rig as CrawlRig).reach_tongs(trash.global_position)


func _on_mount_changed(mount: String) -> void:
	var riding := mount != MountController.SOLO
	if riding == _riding:
		return
	_riding = riding
	(rig as CrawlRig).riding = riding
	collision_shape.disabled = riding
	if not riding:
		# Same position on every peer: it comes from the host through TeamState.
		global_position = TeamState.state.get("dismount_pos", global_position)
		velocity = Vector3.ZERO
		reset_remote_target()
		aim_override = false


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
