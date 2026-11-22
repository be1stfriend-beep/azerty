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
	if Game.has_arg("--autotest-slice"):
		add_child(AutotestSlice.new())
	elif Game.has_arg("--autotest-full"):
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
	var rigs: Array[CharacterBuilder] = [CharacterBuilder.build_bjorn(), CrawlRig.build()]
	for i in rigs.size():
		var marker := world.get_node_or_null("Markers/%s" % ["bjorn", "imad"][i]) as Node3D
		if marker != null:
			rigs[i].position = marker.position
		world.add_child(rigs[i])
	if Game.has_arg("--pose"):
		add_child(PosePreview.new(rigs[0], rigs[1] as CrawlRig, Game.arg_after("--pose")))
	var camera := Camera3D.new()
	world.add_child(camera)
	var position_and_target := _cam_arg()
	camera.position = position_and_target[0]
	camera.look_at(position_and_target[1])
	camera.make_current()
	if Game.has_arg("--restore"):
		_restore_dev_tower()


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
	_restore_dev_tower()


## --restore does the same as pressing T, so screenshots can show the restored state.
func _restore_dev_tower() -> void:
	var tower := get_node_or_null("World/Entities/tower_%d" % DEV_TOWER_INDEX) as Tower
	if tower != null:
		tower.restore_colour()
