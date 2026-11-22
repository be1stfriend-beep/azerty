class_name Toast
extends CanvasLayer
## Short centred message that fades out.

const LAYER := 15
const HOLD_SECONDS := 1.8
const FADE_SECONDS := 0.4
const TOP_OFFSET := 200.0

var _label: Label
var _tween: Tween


func _ready() -> void:
	layer = LAYER
	_label = Label.new()
	_label.theme = UiTheme.build()
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.position.y = TOP_OFFSET
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Palette.SOOT)
	_label.add_theme_constant_override("outline_size", 10)
	_label.modulate.a = 0.0
	add_child(_label)


func show_text(text: String) -> void:
	_label.text = text
	_label.modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_SECONDS)
