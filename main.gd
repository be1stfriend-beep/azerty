extends Node

const DEV_TOWER_INDEX := 0
const DEV_CAMERA_POSITION := Vector3(0, 24, 26)
const DEV_CAMERA_TARGET := Vector3(0, 0, 10)
const CAM_VALUES := 6


func _ready() -> void:
	if not Data.is_loaded:
		await Data.data_loaded
	if Game.has_arg("--screenshot"):
		add_child(Screenshot.new(int(Game.arg_after("--screenshot")), Game.arg_after("--screenshot", 2)))
	if Game.has_arg("--autotest-full"):
		add_child(AutotestFull.new())
	elif Game.has_arg("--autotest"):
		add_child(Autotest.new())
	elif Game.has_arg("--dev-level"):
		_start_dev_level()
	elif not (Game.has_arg("--host") or Game.has_arg("--join")):
		Game.show_lobby()


func _start_dev_level() -> void:
	var world := Game.load_world(Data.config().get("start_level", "main"))
	# Static rigs only: lets screenshots judge character contrast without a network match.
	for character_name: String in ["bjorn", "imad"]:
		var marker := world.get_node_or_null("Markers/%s" % character_name) as Node3D
		if marker != null:
			var rig := CharacterBuilder.build_bjorn() if character_name == "bjorn" else CharacterBuilder.build_imad()
			rig.position = marker.position
			world.add_child(rig)
	var camera := Camera3D.new()
	world.add_child(camera)
	var position_and_target := _cam_arg()
	camera.position = position_and_target[0]
	camera.look_at(position_and_target[1])
	camera.make_current()


## --cam x,y,z,tx,ty,tz places the dev camera; anything malformed keeps the default view.
func _cam_arg() -> Array[Vector3]:
	var result: Array[Vector3] = [DEV_CAMERA_POSITION, DEV_CAMERA_TARGET]
	var values := Game.arg_after("--cam").split_floats(",")
	if values.size() == CAM_VALUES:
		result = [Vector3(values[0], values[1], values[2]), Vector3(values[3], values[4], values[5])]
	return result


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_T:
		return
	var tower := get_node_or_null("World/Entities/tower_%d" % DEV_TOWER_INDEX) as Node3D
	if tower == null:
		return
	Style.set_tower(DEV_TOWER_INDEX, tower.global_position, Data.balance("tower_radius"))
	Style.restore(DEV_TOWER_INDEX)
