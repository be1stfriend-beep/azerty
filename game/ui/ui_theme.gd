class_name UiTheme
## One theme for every code-built UI: one font size, palette colours only.

const FONT_SIZE := 40
const CORNER := 12
const PADDING := 16


static func build(font_size: int = FONT_SIZE) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = font_size
	theme.set_stylebox("normal", "Button", _box(Palette.RUST))
	theme.set_stylebox("hover", "Button", _box(Palette.BJORN_POMPOM))
	theme.set_stylebox("pressed", "Button", _box(Palette.SOOT))
	theme.set_stylebox("disabled", "Button", _box(Palette.CONCRETE))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "LineEdit", _box(Palette.BONE))
	theme.set_stylebox("focus", "LineEdit", _box(Palette.BONE))
	theme.set_stylebox("panel", "PanelContainer", _box(Color(Palette.SOOT, 0.85)))
	for type_name: String in ["Button", "Label"]:
		theme.set_color("font_color", type_name, Palette.BONE)
	theme.set_color("font_hover_color", "Button", Palette.BONE)
	theme.set_color("font_pressed_color", "Button", Palette.BONE)
	theme.set_color("font_color", "LineEdit", Palette.SOOT)
	theme.set_color("caret_color", "LineEdit", Palette.SOOT)
	return theme


static func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(CORNER)
	box.set_content_margin_all(PADDING)
	return box
