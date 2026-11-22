class_name UiParts
## Small builders for code-made screens, so every screen spaces and sizes alike.

const SPACING := 20
const BUTTON_HEIGHT := 104
const BUTTON_WIDTH := 240
const LABEL_WIDTH := 220


static func vbox() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	return box


static func hbox() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	return box


static func panel(content: Control, stretch: float = 1.0) -> PanelContainer:
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_stretch_ratio = stretch
	container.add_child(content)
	return container


static func labelled(text: String, field: Control) -> HBoxContainer:
	var row := hbox()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = LABEL_WIDTH
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(field)
	return row


static func field(text: String, placeholder: String) -> LineEdit:
	var line := LineEdit.new()
	line.text = text
	line.placeholder_text = placeholder
	line.custom_minimum_size.y = BUTTON_HEIGHT
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


static func button(text: String, action: Callable) -> Button:
	var made := Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	made.pressed.connect(action)
	return made


## A button background in a highlight colour, matching the theme's shape.
static func tinted_box(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(UiTheme.CORNER)
	box.set_content_margin_all(UiTheme.PADDING)
	return box
