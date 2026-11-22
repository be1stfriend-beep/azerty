class_name Hud
extends CanvasLayer
## Code-built HUD: air, carried and tool, stash, name tag, tower hold bar, invention card.

const LAYER := 9
const FONT_SIZE := 32
const MARGIN := 24.0
const AIR_BAR_SIZE := Vector2(420, 34)
const AIR_LOW := 0.25
const HOLD_BAR_SIZE := Vector2(520, 28)
const SQUARE_SIZE := Vector2(30, 30)
## Leaves room for the NET meter button in the top-right corner.
const STASH_RIGHT_GAP := 130.0
const CARD_SECONDS := 2.5
const BAR_BACK := Color(0.0, 0.0, 0.0, 0.45)

var _root: Control
var _air_fill: ColorRect
var _carried: Label
var _name_tag: Label
var _stash: HBoxContainer
var _hold_back: ColorRect
var _hold_fill: ColorRect
var _card: PanelContainer
var _card_label: Label
var _card_tween: Tween


func _ready() -> void:
	layer = LAYER
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build(FONT_SIZE)
	add_child(_root)
	_air_fill = _bar(Control.PRESET_TOP_LEFT, Vector2(MARGIN, MARGIN), AIR_BAR_SIZE)
	_hold_fill = _bar(Control.PRESET_CENTER, -HOLD_BAR_SIZE * 0.5 + Vector2(0, 160), HOLD_BAR_SIZE)
	_hold_fill.color = Palette.IMAD_GOGGLES
	_hold_back = _hold_fill.get_parent() as ColorRect
	_name_tag = _label(Control.PRESET_CENTER_TOP, Vector2(0, MARGIN))
	_carried = _label(Control.PRESET_CENTER_BOTTOM, Vector2(0, -MARGIN - FONT_SIZE * 1.5))
	_stash = HBoxContainer.new()
	_stash.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stash.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stash.offset_left = -STASH_RIGHT_GAP
	_stash.offset_right = -STASH_RIGHT_GAP
	_stash.offset_top = MARGIN
	_stash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stash)
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.theme = UiTheme.build()
	_card.visible = false
	_card_label = Label.new()
	_card.add_child(_card_label)
	_root.add_child(_card)
	Events.state_changed.connect(_refresh)
	Events.item_crafted.connect(_show_card)
	_refresh()


func _refresh() -> void:
	var state := TeamState.state
	var ratio := float(state.get("air", 0.0)) / float(Data.balance("air_max"))
	_air_fill.size.x = AIR_BAR_SIZE.x * clampf(ratio, 0.0, 1.0)
	_air_fill.color = Palette.DANGER if ratio < AIR_LOW else Palette.RESTORED_TEAL
	var carried: Array = state.get("carried", [])
	_carried.text = "%d/%d   %s" % [carried.size(), int(Data.balance("carry_capacity")), String(state.get("current_tool", "")).capitalize()]
	var own := "Bjorn" if Net.own_character() == Characters.Character.BJORN else "Imad"
	_name_tag.text = "BJIMAD" if TeamState.mount_state() == MountController.MERGED else own
	var progress := float(state.get("hold_progress", 0.0))
	_hold_back.visible = progress > 0.0
	_hold_fill.size.x = HOLD_BAR_SIZE.x * progress
	_refresh_stash(state.get("stash", {}))


func _refresh_stash(stash: Dictionary) -> void:
	for child in _stash.get_children():
		child.queue_free()
	for material: String in stash:
		var square := ColorRect.new()
		square.custom_minimum_size = SQUARE_SIZE
		square.color = Palette.tint(material)
		square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stash.add_child(square)
		var count := Label.new()
		count.text = "%d " % int(stash[material])
		_stash.add_child(count)


func _show_card(recipe_id: String) -> void:
	_card_label.text = "INVENTED: %s" % Data.recipe(recipe_id).get("invention_name", recipe_id)
	_card.visible = true
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_interval(CARD_SECONDS)
	_card_tween.tween_callback(_card.hide)


func _bar(preset: Control.LayoutPreset, offset: Vector2, bar_size: Vector2) -> ColorRect:
	var back := ColorRect.new()
	back.color = BAR_BACK
	back.set_anchors_preset(preset)
	back.offset_left = offset.x
	back.offset_top = offset.y
	back.offset_right = offset.x + bar_size.x
	back.offset_bottom = offset.y + bar_size.y
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	var fill := ColorRect.new()
	fill.size = bar_size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return fill


func _label(preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var label := Label.new()
	label.set_anchors_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_left = offset.x
	label.offset_right = offset.x
	label.offset_top = offset.y
	label.offset_bottom = offset.y
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Palette.SOOT)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label
