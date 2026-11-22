class_name WobbleTitle
extends Control
## Drawn letter by letter so each letter can bob on its own phase.

const FONT_SIZE := 96
const HEIGHT := 124
const AMPLITUDE := 7.0
const SPEED := 2.2
const PHASE_STEP := 0.45
const SHADOW_OFFSET := Vector2(5, 5)

var _text: String
var _time: float = 0.0


func _init(text: String) -> void:
	_text = text
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var x := (size.x - width) * 0.5
	var baseline := (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
	for i in _text.length():
		var letter := _text[i]
		var at := Vector2(x, baseline + sin(_time * SPEED + i * PHASE_STEP) * AMPLITUDE)
		draw_string(font, at + SHADOW_OFFSET, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.RUST)
		draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.BONE)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
