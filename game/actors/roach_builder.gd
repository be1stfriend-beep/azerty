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
const FLASH_SECONDS := 0.1
const POP_RADIUS := 0.35
const POP_SECONDS := 0.25
const BAR_SIZE := Vector3(2.4, 0.22, 0.22)
const BAR_HEIGHT := 2.6
## Slightly larger than the backing box so the fill always draws in front of it.
const BAR_FILL_GROW := 1.1

var body: Node3D
var legs: Array[Node3D] = []
var eyes: Array[MeshInstance3D] = []
var bar: Node3D
var bar_fill: MeshInstance3D

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
	rig.bar = Node3D.new()
	rig.bar.position.y = BAR_HEIGHT
	rig.bar.visible = false
	rig.add_child(rig.bar)
	ProcProps.part(rig.bar, ProcProps.box(BAR_SIZE), Vector3.ZERO, "char_dark")
	rig.bar_fill = ProcProps.part(rig.bar, ProcProps.box(BAR_SIZE * BAR_FILL_GROW), Vector3.ZERO, "danger")
	Style.apply(rig)
	return rig


func animate(delta: float, moving: bool) -> void:
	_phase += delta * (LEG_FREQUENCY if moving else LEG_IDLE_FREQUENCY)
	for i in legs.size():
		# Alternate tripods, like a real insect gait.
		legs[i].rotation.y = sin(_phase + (i % 2) * PI) * LEG_SWING
	var target := REAR_ANGLE if _reared else 0.0
	body.rotation.x = lerpf(body.rotation.x, target, 1.0 - exp(-REAR_LERP * delta))
	# The bar stays level and unrotated so it reads the same from any camera angle.
	bar.global_rotation = Vector3.ZERO


## Fill is anchored on the left edge so it shrinks toward it.
func set_health(ratio: float, awake: bool) -> void:
	bar.visible = awake
	var r := clampf(ratio, 0.0, 1.0)
	bar_fill.visible = r > 0.0
	bar_fill.scale.x = maxf(r, 0.01)
	bar_fill.position.x = -BAR_SIZE.x * BAR_FILL_GROW * (1.0 - r) * 0.5


func flash() -> void:
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = Style.material("char_white")
	get_tree().create_timer(FLASH_SECONDS).timeout.connect(_end_flash)


func _end_flash() -> void:
	Style.apply(body, "roach_shell")
	set_windup(_reared)


func pop(world_point: Vector3) -> void:
	var spark := MeshInstance3D.new()
	spark.mesh = ProcProps.sphere(POP_RADIUS)
	spark.top_level = true
	spark.set_meta("tint_group", "bone")
	add_child(spark)
	Style.apply(spark)
	spark.global_position = world_point
	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3.ONE * 2.0, POP_SECONDS * 0.4)
	tween.tween_property(spark, "scale", Vector3.ZERO, POP_SECONDS * 0.6)
	tween.tween_callback(spark.queue_free)


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
