class_name CraftMenu
extends CanvasLayer
## Bench menu on the crafting player's screen: one big card per bench recipe, plus a greyed
## card for the next goal. The host re-checks every cost.

const LAYER := 12
const SPACING := 28
const CARD_SIZE := Vector2(560, 400)
const BUTTON_SIZE := Vector2(320, 110)
const SQUARE_SIZE := Vector2(40, 40)
const SQUARE_GAP := 14
const CARD_BORDER := 6
const LATER_ALPHA := 0.4

var _cards: HBoxContainer


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
	box.add_theme_constant_override("separation", SPACING)
	panel.add_child(box)
	box.add_child(_label(Data.hint("craft_title"), Palette.BONE))
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", SPACING)
	box.add_child(_cards)
	var close := Button.new()
	close.text = Data.hint("craft_close")
	close.custom_minimum_size = BUTTON_SIZE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide)
	box.add_child(close)
	Events.state_changed.connect(_refresh)
	Events.item_crafted.connect(func(_id: String) -> void: hide())
	hide()


func open() -> void:
	show()
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	for child in _cards.get_children():
		child.queue_free()
	var stash: Dictionary = TeamState.state.get("stash", {})
	for recipe_id: String in Data.config().get("bench_recipes", []):
		_recipe_card(recipe_id, stash)
	for recipe_id: String in Data.config().get("bench_later", []):
		var recipe := Data.recipe(recipe_id)
		var card := _new_card(Data.hint("craft_later") % recipe.get("name", recipe_id), Palette.CONCRETE)
		card.add_child(_cost_row(recipe.get("cost", {}), stash))
		card.get_parent().modulate.a = LATER_ALPHA


func _recipe_card(recipe_id: String, stash: Dictionary) -> void:
	var recipe := Data.recipe(recipe_id)
	var cost: Dictionary = recipe.get("cost", {})
	var affordable := StationRules.can_afford(stash, recipe)
	var done := int((TeamState.state.get("inventory", {}) as Dictionary).get(recipe_id, 0)) > 0
	var card := _new_card(recipe.get("name", recipe_id), Palette.RESTORED_GRASS if affordable else Palette.CONCRETE)
	card.add_child(_cost_row(cost, stash))
	var status := Data.hint("craft_done") if done else Data.hint("craft_ready") if affordable else _need_text(cost, stash)
	card.add_child(_label(status, Palette.RESTORED_GRASS if affordable or done else Palette.BONE))
	var invent := Button.new()
	invent.text = Data.hint("craft_invent")
	invent.custom_minimum_size = BUTTON_SIZE
	invent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	invent.disabled = done or not affordable
	invent.pressed.connect(TeamState.request_craft.bind(recipe_id))
	card.add_child(invent)


## A bordered card in the row; returns its content box.
func _new_card(title: String, border: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SOOT
	style.border_color = border
	style.set_border_width_all(CARD_BORDER)
	style.set_corner_radius_all(UiTheme.CORNER)
	style.set_content_margin_all(UiTheme.PADDING * 2)
	panel.add_theme_stylebox_override("panel", style)
	_cards.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", SPACING)
	panel.add_child(box)
	box.add_child(_label(title, Palette.BONE))
	return box


## Coloured squares with counts; a count turns green once the stash covers it.
func _cost_row(cost: Dictionary, stash: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SQUARE_GAP)
	for material: String in cost:
		var square := ColorRect.new()
		square.custom_minimum_size = SQUARE_SIZE
		square.color = Palette.tint(material)
		square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(square)
		var enough := int(stash.get(material, 0)) >= int(cost[material])
		row.add_child(_label("%d %s" % [int(cost[material]), material], Palette.RESTORED_GRASS if enough else Palette.BONE))
	return row


func _need_text(cost: Dictionary, stash: Dictionary) -> String:
	var parts: PackedStringArray = []
	for material: String in cost:
		var missing := int(cost[material]) - int(stash.get(material, 0))
		if missing > 0:
			parts.append(Data.hint("craft_need_part") % [missing, material])
	return Data.hint("craft_need") % ", ".join(parts)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label
