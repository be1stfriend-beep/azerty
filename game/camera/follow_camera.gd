class_name FollowCamera
extends Camera3D
## Fixed-yaw camera south of the action. Frames both players until they split past the leash.

const PITCH_DEGREES := -55.0
const FOV_DEGREES := 50.0
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 34.0
const FRAME_MARGIN := 1.6
const LEASH := 30.0
const FOLLOW_LERP := 5.0

var local_player: Node3D
var partner: Node3D

var _focus := Vector3.ZERO
var _distance := MIN_DISTANCE
var _shake_left := 0.0
var _shake_strength := 0.0


func shake(strength: float, seconds: float) -> void:
	_shake_strength = strength
	_shake_left = seconds


func setup(local_node: Node3D, partner_node: Node3D) -> void:
	local_player = local_node
	partner = partner_node
	fov = FOV_DEGREES
	rotation_degrees = Vector3(PITCH_DEGREES, 0, 0)
	_focus = local_player.global_position
	_place()
	make_current()


func _process(delta: float) -> void:
	if not is_instance_valid(local_player):
		return
	var target_focus := local_player.global_position
	var target_distance := MIN_DISTANCE
	if is_instance_valid(partner):
		var separation := local_player.global_position.distance_to(partner.global_position)
		if separation <= LEASH:
			target_focus = (local_player.global_position + partner.global_position) * 0.5
			var needed := separation * FRAME_MARGIN / (2.0 * tan(deg_to_rad(FOV_DEGREES) * 0.5))
			target_distance = clampf(needed, MIN_DISTANCE, MAX_DISTANCE)
	var weight := 1.0 - exp(-FOLLOW_LERP * delta)
	_focus = _focus.lerp(target_focus, weight)
	_distance = lerpf(_distance, target_distance, weight)
	_shake_left = maxf(_shake_left - delta, 0.0)
	_place()


func _place() -> void:
	# The view direction is fixed, so the camera simply backs away from the focus along it.
	global_position = _focus + global_basis.z * _distance
	if _shake_left > 0.0:
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_strength
