class_name CraftMenu
extends CanvasLayer
## Bench menu on the crafting player's screen. The host re-checks every cost.

const LAYER := 12
const ROW_SPACING := 28
const INVENT_SIZE := Vector2(260, 110)
const CLOSE_SIZE := Vector2(320, 110)

var _rows: VBoxContainer


func _ready() -> void:
	layer = LAYER
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build()
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SPACING)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Bench"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", ROW_SPACING)
	box.add_child(_rows)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = CLOSE_SIZE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide)
	box.add_child(close)
	Events.state_changed.connect(_refresh)
	hide()


func open() -> void:
	show()
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	for child in _rows.get_children():
		child.queue_free()
	var stash: Dictionary = TeamState.state.get("stash", {})
	var recipes := Data.recipes()
	for recipe_id: String in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		var affordable := StationRules.can_afford(stash, recipe)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ROW_SPACING)
		var label := Label.new()
		label.text = "%s   %s" % [recipe.get("name", recipe_id), _cost_text(recipe.get("cost", {}))]
		label.add_theme_color_override("font_color", Palette.RESTORED_GRASS if affordable else Palette.BONE)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var invent := Button.new()
		invent.text = "Invent"
		invent.custom_minimum_size = INVENT_SIZE
		invent.disabled = not affordable
		invent.pressed.connect(TeamState.request_craft.bind(recipe_id))
		row.add_child(invent)
		_rows.add_child(row)


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for material: String in cost:
		parts.append("%s %d" % [material, int(cost[material])])
	return ", ".join(parts)
