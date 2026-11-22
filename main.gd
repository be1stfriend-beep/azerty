extends Node

const DEV_LEVEL := "main"
const DEV_CAMERA_POSITION := Vector3(0, 24, 26)
const DEV_CAMERA_TARGET := Vector3(0, 0, 10)
const DEV_TOWER_INDEX := 0


func _ready() -> void:
	if not Data.is_loaded:
		await Data.data_loaded
	print("Data loaded")
	if "--dev-level" in OS.get_cmdline_user_args() or "--dev-level" in OS.get_cmdline_args():
		_start_dev_level()


func _start_dev_level() -> void:
	LevelLoader.load_level(DEV_LEVEL, self)
	var camera := Camera3D.new()
	add_child(camera)
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
