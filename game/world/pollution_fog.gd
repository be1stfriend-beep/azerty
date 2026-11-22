class_name PollutionFog
extends Node
## Local only: thick smog swallows the wasteland a few metres past the local player, and thins
## out to the old dusty haze inside the Dome. Each peer fogs its own view from its own player.

var _env: Environment
var _outside := 0.0


func _init(env: Environment) -> void:
	name = "PollutionFog"
	_env = env


func _ready() -> void:
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_sun_scatter = 0.0


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var focus := _focus(camera)
	var dome: Vector3 = get_parent().get_meta("dome", Vector3.ZERO)
	var radius := float(Data.balance("dome_radius"))
	var blend := float(Data.balance("fog_blend_distance"))
	var target := smoothstep(radius - blend * 0.5, radius + blend * 0.5, StationRules.flat_distance(focus, dome))
	_outside = lerpf(_outside, target, minf(1.0, float(Data.balance("fog_lerp")) * delta))
	# Fog depth is measured from the camera, so offsets start at the player, not at the lens.
	var depth := camera.global_position.distance_to(focus)
	_env.fog_depth_begin = maxf(0.0, depth + _mix("fog_clear_begin", "fog_smog_begin"))
	_env.fog_depth_end = depth + _mix("fog_clear_end", "fog_smog_end")
	_env.fog_density = _mix("fog_clear_density", "fog_smog_density")
	var color := Palette.HAZE_SKY.lerp(Palette.SMOG, _outside)
	_env.fog_light_color = color
	_env.background_color = color


func _mix(clear_key: String, smog_key: String) -> float:
	return lerpf(float(Data.balance(clear_key)), float(Data.balance(smog_key)), _outside)


## The local player when a match runs; otherwise (dev level) where the camera looks at the ground.
func _focus(camera: Camera3D) -> Vector3:
	var player := Game.player(Net.own_character())
	if player != null:
		return player.global_position
	var forward := -camera.global_basis.z
	if forward.y > -0.01:
		return camera.global_position
	return camera.global_position + forward * (-camera.global_position.y / forward.y)
