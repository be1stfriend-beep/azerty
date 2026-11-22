class_name RoachBuilder
extends Node3D
## The cockroach's look and tells: six sine-driven legs, rearing, red eyes, hit shake. Faces +Z.

const LEG_FREQUENCY := 14.0
const LEG_IDLE_FREQUENCY := 2.0
const LEG_SWING := 0.45
const REAR_ANGLE := -0.5
const REAR_LERP := 8.0
const SHAKE_DISTANCE := 0.25
const SHAKE_STEP := 0.04
const SHAKE_STEPS := 4

var body: Node3D
var legs: Array[Node3D] = []
var eyes: Array[MeshInstance3D] = []

var _phase := 0.0
var _reared := false


static func build() -> RoachBuilder:
	var rig := RoachBuilder.new()
	rig.body = Node3D.new()
	rig.body.name = "Body"
	rig.add_child(rig.body)
	var b := rig.body
	ProcProps.part(b, ProcProps.sphere(1.0), Vector3(0, 0.8, 0), "roach_shell", Vector3.ZERO, Vector3(1.1, 0.5, 1.6))
	ProcProps.part(b, ProcProps.sphere(1.0), Vector3(0, 0.6, 0.05), "roach_belly", Vector3.ZERO, Vector3(0.95, 0.35, 1.45))
	ProcProps.part(b, ProcProps.sphere(0.5), Vector3(0, 0.75, 1.65), "roach_shell", Vector3.ZERO, Vector3(1.1, 0.8, 0.9))
	for side: float in [-1.0, 1.0]:
		rig.eyes.append(ProcProps.part(b, ProcProps.sphere(0.13), Vector3(0.24 * side, 0.92, 2.04), "roach_eye"))
		ProcProps.part(b, ProcProps.cyl(0.03, 0.03, 1.6), Vector3(0.25 * side, 1.35, 2.5), "roach_shell", Vector3(55, 0, -15 * side))
		for i in 3:
			var leg := Node3D.new()
			leg.position = Vector3(0.9 * side, 0.6, (i - 1) * 0.8)
			b.add_child(leg)
			ProcProps.part(leg, ProcProps.box(Vector3(1.2, 0.12, 0.12)), Vector3(0.55 * side, -0.25, 0), "roach_shell", Vector3(0, 0, -25 * side))
			rig.legs.append(leg)
	var shadow := ProcProps.part(rig, ProcProps.cyl(1.5, 1.5, 0.01), Vector3(0, 0.02, 0), "char_shadow")
	shadow.scale = Vector3(1, 1, 1.4)
	Style.apply(rig)
	return rig


func animate(delta: float, moving: bool) -> void:
	_phase += delta * (LEG_FREQUENCY if moving else LEG_IDLE_FREQUENCY)
	for i in legs.size():
		# Alternate tripods, like a real insect gait.
		legs[i].rotation.y = sin(_phase + (i % 2) * PI) * LEG_SWING
	var target := REAR_ANGLE if _reared else 0.0
	body.rotation.x = lerpf(body.rotation.x, target, 1.0 - exp(-REAR_LERP * delta))


func set_windup(on: bool) -> void:
	_reared = on
	for eye in eyes:
		eye.material_override = Style.material("roach_eye_hot" if on else "roach_eye")


func shake() -> void:
	var tween := create_tween()
	for i in SHAKE_STEPS:
		var side := SHAKE_DISTANCE if i % 2 == 0 else -SHAKE_DISTANCE
		tween.tween_property(body, "position:x", side, SHAKE_STEP)
	tween.tween_property(body, "position:x", 0.0, SHAKE_STEP)
