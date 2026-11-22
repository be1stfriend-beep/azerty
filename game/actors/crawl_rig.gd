class_name CrawlRig
extends CharacterBuilder
## Imad: no legs, a low stocky torso, and a crawl driven by his arms.
## While riding, the torso stands upright on Bjorn's back with the arms over his shoulders.

const HIP_HEIGHT := 0.3
const TAIL_HEIGHT := 0.26
const CYCLE_PER_SPEED := 2.6
const MOVING_SPEED := 0.15
const IDLE_LEAN_DEG := 10.0
const CRAWL_LEAN_DEG := 35.0
const REACH_DEG := 55.0
const LUNGE := 0.12
const CRAWL_SQUASH := 0.08
const TAIL_STRETCH := 0.18
const BREATH_FREQUENCY := 2.2
const BREATH_SCALE := 0.03
const RIDE_ARM_DEG := -125.0
const RIDE_TAIL_DEG := -75.0
const POSE_SPRING := 12.0

## His own ground shadow would float in mid-air on Bjorn's back.
var riding := false:
	set(value):
		riding = value
		(get_node("Shadow") as Node3D).visible = not value
var torso: Node3D
var tail: Node3D
var hands: Array[Node3D] = []

var _full_speed: float
var _phase := 0.0
var _breath := 0.0


static func build() -> CrawlRig:
	var rig := CrawlRig.new()
	setup(rig, 0.55)
	rig._full_speed = float(Data.balance("imad_crawl"))
	rig.tail = _build_tail()
	rig.body.add_child(rig.tail)
	rig.torso = Node3D.new()
	rig.torso.position = Vector3(0, HIP_HEIGHT, 0)
	rig.body.add_child(rig.torso)
	var t := rig.torso
	ProcProps.part(t, capsule(0.32, 0.66), Vector3(0, 0.25, 0), "imad_vest", Vector3.ZERO, Vector3(1.3, 1, 0.95))
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.42 * side, 0.42, 0.04)
		t.add_child(arm)
		ProcProps.part(arm, capsule(0.11, 0.5), Vector3(0, -0.24, 0), "skin_b")
		ProcProps.part(arm, ProcProps.sphere(0.14), Vector3(0, -0.5, 0), "skin_b")
		rig.hands.append(arm)
	_build_head(t, 0.72)
	t.add_child(_build_tongs())
	Style.apply(rig)
	return rig


## The overalls end in a tapered, tied-off tail so it reads as "no legs" from any angle.
static func _build_tail() -> Node3D:
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, TAIL_HEIGHT, 0)
	ProcProps.part(tail, ProcProps.sphere(0.3), Vector3.ZERO, "imad_overalls", Vector3.ZERO, Vector3(1.2, 0.9, 1))
	ProcProps.part(tail, ProcProps.cyl(0.28, 0.1, 0.55), Vector3(0, 0, -0.3), "imad_overalls", Vector3(90, 0, 0))
	ProcProps.part(tail, ProcProps.cyl(0.08, 0.08, 0.06), Vector3(0, 0, -0.58), "char_dark", Vector3(90, 0, 0))
	ProcProps.part(tail, ProcProps.sphere(0.1), Vector3(0, 0, -0.66), "imad_overalls")
	return tail


static func _build_head(t: Node3D, y: float) -> void:
	ProcProps.part(t, ProcProps.sphere(0.21), Vector3(0, y, 0), "skin_b")
	ProcProps.part(t, ProcProps.sphere(0.22), Vector3(0, y + 0.08, -0.04), "char_dark", Vector3.ZERO, Vector3(1.05, 0.7, 1))
	for i in 5:
		var angle := (i - 2) * 0.55
		ProcProps.part(t, ProcProps.sphere(0.08), Vector3(sin(angle) * 0.17, y + 0.17, -cos(angle) * 0.08), "char_dark")
	for side: float in [-1.0, 1.0]:
		ProcProps.part(t, ProcProps.cyl(0.07, 0.07, 0.05), Vector3(0.08 * side, y + 0.14, 0.14), "imad_goggles", Vector3(-60, 0, 0))
	ProcProps.part(t, ProcProps.box(Vector3(0.36, 0.04, 0.03)), Vector3(0, y + 0.13, 0.12), "imad_goggles")
	eyes(t, 0.075, 0.065, Vector3(0, y, 0.17))


## Stowed diagonally across the back; S3 extends them forward for a grab.
static func _build_tongs() -> Node3D:
	var tongs := Node3D.new()
	tongs.name = "Tongs"
	tongs.position = Vector3(0, 0.35, -0.36)
	tongs.rotation_degrees = Vector3(0, 0, 35)
	for side: float in [-1.0, 1.0]:
		ProcProps.part(tongs, ProcProps.box(Vector3(0.07, 0.95, 0.07)), Vector3(0.05 * side, 0, 0), "char_dark")
		ProcProps.part(tongs, ProcProps.box(Vector3(0.12, 0.14, 0.1)), Vector3(0.07 * side, 0.5, 0), "imad_goggles")
	ProcProps.part(tongs, ProcProps.cyl(0.07, 0.07, 0.2), Vector3(0, -0.45, 0), "char_white", Vector3(0, 0, 90))
	return tongs


func update_wobble(delta: float, velocity: Vector3, grounded: bool) -> void:
	super.update_wobble(delta, velocity, grounded)
	if delta <= 0.0:
		return
	var weight := 1.0 - exp(-POSE_SPRING * delta)
	_breath += delta * BREATH_FREQUENCY
	if riding:
		_pose(weight, 0.0, [RIDE_ARM_DEG, RIDE_ARM_DEG], RIDE_TAIL_DEG, 0.0, 0.0)
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var amount := clampf(speed / _full_speed, 0.0, 1.0) if speed > MOVING_SPEED else 0.0
	_phase += delta * speed * CYCLE_PER_SPEED
	var lean := lerpf(IDLE_LEAN_DEG, CRAWL_LEAN_DEG, amount)
	# Arms alternate; a hand in front is the one planting, so the lunge peaks twice per cycle.
	var reach := sin(_phase) * REACH_DEG * amount
	var arm_angles: Array[float] = [-lean - reach, -lean + reach]
	var lunge := maxf(sin(_phase * 2.0), 0.0) * amount
	_pose(weight, lean, arm_angles, 0.0, lunge, sin(_phase * 2.0) * amount)


func _pose(weight: float, lean_deg: float, arm_deg: Array, tail_deg: float, lunge: float, squash: float) -> void:
	torso.rotation_degrees.x = lerpf(torso.rotation_degrees.x, lean_deg, weight)
	for i in hands.size():
		hands[i].rotation_degrees.x = lerpf(hands[i].rotation_degrees.x, arm_deg[i], weight)
	tail.rotation_degrees.x = lerpf(tail.rotation_degrees.x, tail_deg, weight)
	torso.position.z = lerpf(torso.position.z, lunge * LUNGE, weight)
	tail.scale.z = 1.0 + lunge * TAIL_STRETCH
	var breath := sin(_breath) * BREATH_SCALE if is_zero_approx(squash) else 0.0
	var s := squash * CRAWL_SQUASH
	torso.scale = Vector3(1.0 + s * 0.5, 1.0 - s + breath, 1.0 + s * 0.5)
