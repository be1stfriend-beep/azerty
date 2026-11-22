extends Node

const VIGNETTE_SHADER_PATH := "res://shaders/vignette.gdshader"
## Above the 3D view, below HUD layers added later.
const POST_LAYER := 5


func _ready() -> void:
	InputSetup.register()
	_add_post_layer()


func _add_post_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PostLayer"
	layer.layer = POST_LAYER
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(VIGNETTE_SHADER_PATH)
	mat.set_shader_parameter("haze_color", Palette.HAZE_SKY)
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)
