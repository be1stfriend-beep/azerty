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

var body: Node3D
var kick_leg: Node3D

var _previous_velocity := Vector3.ZERO
var _was_grounded := true
var _squash := 0.0
var _sway_time := 0.0


static func build_bjorn() -> CharacterBuilder:
	var rig := _rig(0.45)
	var b := rig.body
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.13 * side, 0.75, 0)
		b.add_child(leg)
		ProcProps.part(leg, ProcProps.cyl(0.09, 0.08, 0.62), Vector3(0, -0.31, 0), "char_dark")
		ProcProps.part(leg, ProcProps.box(Vector3(0.24, 0.16, 0.38)), Vector3(0, -0.67, 0.05), "char_dark")
		ProcProps.part(b, _capsule(0.09, 0.6), Vector3(0.34 * side, 1.02, 0), "bjorn_parka", Vector3(0, 0, 8 * side))
		if side > 0.0:
			rig.kick_leg = leg
	ProcProps.part(b, _capsule(0.27, 0.68), Vector3(0, 1.05, 0), "bjorn_parka")
	ProcProps.part(b, ProcProps.sphere(0.28), Vector3(0, 1.55, 0), "skin_a")
	ProcProps.part(b, ProcProps.sphere(0.3), Vector3(0, 1.66, -0.02), "char_white", Vector3.ZERO, Vector3(1, 0.62, 1))
	ProcProps.part(b, ProcProps.sphere(0.09), Vector3(0, 1.88, -0.02), "bjorn_pompom")
	_eyes(b, 0.11, 0.09, Vector3(0, 1.55, 0.22))
	var saddle := Marker3D.new()
	saddle.name = "Saddle"
	saddle.position = Vector3(0, 1.3, -0.32)
	b.add_child(saddle)
	Style.apply(rig)
	return rig


static func build_imad() -> CharacterBuilder:
	var rig := _rig(0.6)
	var b := rig.body
	var cart := Node3D.new()
	cart.name = "Cart"
	b.add_child(cart)
	ProcProps.part(cart, ProcProps.box(Vector3(0.9, 0.22, 1.0)), Vector3(0, 0.25, 0), "char_cart")
	for x: float in [-0.42, 0.42]:
		for z: float in [-0.34, 0.34]:
			ProcProps.part(cart, ProcProps.cyl(0.12, 0.12, 0.1), Vector3(x, 0.12, z), "char_dark", Vector3(0, 0, 90))
	ProcProps.part(b, _capsule(0.3, 0.55), Vector3(0, 0.62, 0), "imad_vest", Vector3.ZERO, Vector3(1.15, 1, 0.9))
	for side: float in [-1.0, 1.0]:
		ProcProps.part(b, _capsule(0.09, 0.42), Vector3(0.38 * side, 0.62, 0.04), "skin_b", Vector3(0, 0, 12 * side))
		ProcProps.part(b, ProcProps.sphere(0.1), Vector3(0.42 * side, 0.4, 0.06), "skin_b")
	ProcProps.part(b, ProcProps.sphere(0.21), Vector3(0, 0.98, 0), "skin_b")
	ProcProps.part(b, ProcProps.sphere(0.22), Vector3(0, 1.06, -0.04), "char_dark", Vector3.ZERO, Vector3(1.05, 0.7, 1))
	for i in 5:
		var angle := (i - 2) * 0.55
		ProcProps.part(b, ProcProps.sphere(0.08), Vector3(sin(angle) * 0.17, 1.15, -cos(angle) * 0.08), "char_dark")
	for side: float in [-1.0, 1.0]:
		ProcProps.part(b, ProcProps.cyl(0.07, 0.07, 0.05), Vector3(0.08 * side, 1.12, 0.14), "imad_goggles", Vector3(-60, 0, 0))
	ProcProps.part(b, ProcProps.box(Vector3(0.36, 0.04, 0.03)), Vector3(0, 1.11, 0.12), "imad_goggles")
	_eyes(b, 0.075, 0.065, Vector3(0, 0.98, 0.17))
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
	_previous_velocity = velocity
	_was_grounded = grounded


func kick() -> void:
	if kick_leg == null:
		return
	var tween := create_tween()
	tween.tween_property(kick_leg, "rotation_degrees:x", KICK_ANGLE, KICK_SECONDS)
	tween.tween_property(kick_leg, "rotation_degrees:x", 0.0, KICK_SECONDS * 2.0)


static func _rig(shadow_radius: float) -> CharacterBuilder:
	var rig := CharacterBuilder.new()
	rig.body = Node3D.new()
	rig.body.name = "Body"
	rig.add_child(rig.body)
	var shadow := ProcProps.part(rig, ProcProps.cyl(shadow_radius, shadow_radius, 0.01), Vector3(0, SHADOW_HEIGHT, 0), "char_shadow")
	shadow.name = "Shadow"
	return rig


static func _eyes(parent: Node3D, spacing: float, radius: float, center: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		var eye := center + Vector3(spacing * side, 0, 0)
		ProcProps.part(parent, ProcProps.sphere(radius), eye, "char_white")
		ProcProps.part(parent, ProcProps.sphere(radius * 0.5), eye + Vector3(0, 0, radius * 0.75), "char_dark")


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = ProcProps.SEGMENTS
	mesh.rings = ProcProps.SPHERE_RINGS
	return mesh
