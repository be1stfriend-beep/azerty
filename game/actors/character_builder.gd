class_name CharacterBuilder
extends Node3D
## Builds Bjorn and Imad from primitives and drives their procedural wobble.
## Characters face +Z (toward the camera) at rotation zero.

const LEAN_PER_ACCEL := 0.025
const LEAN_MAX := 0.35
const LEAN_SPRING := 10.0
const SWAY_FREQUENCY := 11.0
const SWAY_PER_SPEED := 0.018
const SQUASH_PER_FALL_SPEED := 0.035
const SQUASH_MAX := 0.3
const SQUASH_RECOVER := 6.0
const KICK_ANGLE := -75.0
const KICK_SECONDS := 0.12
const SHADOW_HEIGHT := 0.02
const ARM_SWING_PER_SPEED := 0.12
const ARM_SWING_MAX := 0.7
const ARM_TILT_DEG := 8.0

var body: Node3D
var kick_leg: Node3D
## Shoulder pivots that swing opposite each other while running.
var arms: Array[Node3D] = []

var _previous_velocity := Vector3.ZERO
var _was_grounded := true
var _squash := 0.0
var _sway_time := 0.0


static func build_bjorn() -> CharacterBuilder:
	var rig := CharacterBuilder.new()
	setup(rig, 0.45)
	var b := rig.body
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.13 * side, 0.75, 0)
		b.add_child(leg)
		ProcProps.part(leg, ProcProps.cyl(0.09, 0.08, 0.62), Vector3(0, -0.31, 0), "char_dark")
		ProcProps.part(leg, ProcProps.box(Vector3(0.24, 0.16, 0.38)), Vector3(0, -0.67, 0.05), "char_dark")
		if side > 0.0:
			rig.kick_leg = leg
		# No hands: the sleeve just closes in a rounded cuff of the same parka cloth.
		var arm := Node3D.new()
		arm.position = Vector3(0.34 * side, 1.32, 0)
		arm.rotation_degrees.z = ARM_TILT_DEG * side
		b.add_child(arm)
		ProcProps.part(arm, capsule(0.09, 0.6), Vector3(0, -0.3, 0), "bjorn_parka")
		ProcProps.part(arm, ProcProps.sphere(0.11), Vector3(0, -0.58, 0), "bjorn_parka", Vector3.ZERO, Vector3(1, 0.75, 1))
		rig.arms.append(arm)
	ProcProps.part(b, capsule(0.27, 0.68), Vector3(0, 1.05, 0), "bjorn_parka")
	ProcProps.part(b, ProcProps.sphere(0.28), Vector3(0, 1.55, 0), "skin_a")
	ProcProps.part(b, ProcProps.sphere(0.3), Vector3(0, 1.66, -0.02), "char_white", Vector3.ZERO, Vector3(1, 0.62, 1))
	ProcProps.part(b, ProcProps.sphere(0.09), Vector3(0, 1.88, -0.02), "bjorn_pompom")
	eyes(b, 0.11, 0.09, Vector3(0, 1.55, 0.22))
	var saddle := Marker3D.new()
	saddle.name = "Saddle"
	saddle.position = Vector3(0, 1.3, -0.32)
	b.add_child(saddle)
	Style.apply(rig)
	return rig


func update_wobble(delta: float, velocity: Vector3, grounded: bool) -> void:
	if delta <= 0.0:
		return
	var accel := global_basis.inverse() * ((velocity - _previous_velocity) / delta)
	var speed := Vector2(velocity.x, velocity.z).length()
	_sway_time += delta * SWAY_FREQUENCY
	var sway := sin(_sway_time) * speed * SWAY_PER_SPEED
	var target := Vector3(
		clampf(-accel.z * LEAN_PER_ACCEL, -LEAN_MAX, LEAN_MAX),
		0.0,
		clampf(accel.x * LEAN_PER_ACCEL, -LEAN_MAX, LEAN_MAX) + sway)
	body.rotation = body.rotation.lerp(target, 1.0 - exp(-LEAN_SPRING * delta))
	if grounded and not _was_grounded:
		_squash = minf(absf(_previous_velocity.y) * SQUASH_PER_FALL_SPEED, SQUASH_MAX)
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-SQUASH_RECOVER * delta))
	body.scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5)
	var swing := sin(_sway_time) * minf(speed * ARM_SWING_PER_SPEED, ARM_SWING_MAX)
	for i in arms.size():
		arms[i].rotation.x = swing if i % 2 == 0 else -swing
	_previous_velocity = velocity
	_was_grounded = grounded


func kick() -> void:
	if kick_leg == null:
		return
	var tween := create_tween()
	tween.tween_property(kick_leg, "rotation_degrees:x", KICK_ANGLE, KICK_SECONDS)
	tween.tween_property(kick_leg, "rotation_degrees:x", 0.0, KICK_SECONDS * 2.0)


static func setup(rig: CharacterBuilder, shadow_radius: float) -> void:
	rig.body = Node3D.new()
	rig.body.name = "Body"
	rig.add_child(rig.body)
	var shadow := ProcProps.part(rig, ProcProps.cyl(shadow_radius, shadow_radius, 0.01), Vector3(0, SHADOW_HEIGHT, 0), "char_shadow")
	shadow.name = "Shadow"


static func eyes(parent: Node3D, spacing: float, radius: float, center: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		var eye := center + Vector3(spacing * side, 0, 0)
		ProcProps.part(parent, ProcProps.sphere(radius), eye, "char_white")
		ProcProps.part(parent, ProcProps.sphere(radius * 0.5), eye + Vector3(0, 0, radius * 0.75), "char_dark")


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = ProcProps.SEGMENTS
	mesh.rings = ProcProps.SPHERE_RINGS
	return mesh
