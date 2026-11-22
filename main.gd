extends Node

const DEV_TOWER_INDEX := 0
const DEV_CAMERA_POSITION := Vector3(0, 24, 26)
const DEV_CAMERA_TARGET := Vector3(0, 0, 10)


func _ready() -> void:
	if not Data.is_loaded:
		await Data.data_loaded
	print("Data loaded")
	if Game.has_arg("--dev-level"):
		_start_dev_level()
	elif not (Game.has_arg("--host") or Game.has_arg("--join")):
		Game.show_lobby()


func _start_dev_level() -> void:
	var world := Game.load_world(Data.config().get("start_level", "main"))
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = DEV_CAMERA_POSITION
	camera.look_at(DEV_CAMERA_TARGET)
	camera.make_current()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_T:
		return
	var tower := get_node_or_null("World/Entities/tower_%d" % DEV_TOWER_INDEX) as Node3D
	if tower == null:
		return
	Style.set_tower(DEV_TOWER_INDEX, tower.global_position, Data.balance("tower_radius"))
	Style.restore(DEV_TOWER_INDEX)
