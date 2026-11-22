class_name Screenshot
extends Node
## --screenshot <frame> <path>: saves the viewport after <frame> frames, then quits.
## Needs a real window; a headless run renders nothing.

var _frames_left: int
var _path: String


func _init(frames: int, path: String) -> void:
	_frames_left = maxi(frames, 1)
	_path = path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left == 0:
		_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var error := get_viewport().get_texture().get_image().save_png(_path)
	print("screenshot: %s (%s) draws %d triangles %d" % [_path, error_string(error),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
