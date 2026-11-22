class_name MessageOverlay
extends CanvasLayer
## Full-screen blocking message with one button.

signal confirmed

const LAYER := 20
const BUTTON_SIZE := Vector2(480, 120)
const SPACING := 40


func _init(message: String, button_text: String) -> void:
	layer = LAYER
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Palette.SOOT, 0.8)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", SPACING)
	root.add_child(box)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(func() -> void: confirmed.emit())
	box.add_child(button)
