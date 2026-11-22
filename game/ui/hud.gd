class_name Hud
extends CanvasLayer
## Code-built HUD: air, carried and tool, stash, name tag, tower hold bar. Recycled material
## blocks fly from the Recycler chute into their stash counter.

const LAYER := 9
const FONT_SIZE := 32
const MARGIN := 24.0
const AIR_BAR_SIZE := Vector2(420, 34)
const AIR_LOW := 0.25
const HOLD_BAR_SIZE := Vector2(520, 28)
const SQUARE_SIZE := Vector2(30, 30)
## Leaves room for the NET meter button in the top-right corner.
const STASH_RIGHT_GAP := 130.0
const BAR_BACK := Color(0.0, 0.0, 0.0, 0.45)
const FLY_SECONDS := 0.5
const COUNTER_POP := 1.4
const COUNTER_POP_SECONDS := 0.1

var _root: Control
var _air_fill: ColorRect
var _carried: Label
var _objective: Label
var _name_tag: Label
var _perch_hint: Label
var _stash: VBoxContainer
var _hold_back: ColorRect
var _hold_fill: ColorRect
## Material id to its square and count, so a flying block knows where to land.
var _squares: Dictionary = {}
var _counts: Dictionary = {}


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
	_objective = _label(Control.PRESET_CENTER_TOP, Vector2(0, MARGIN))
	_objective.add_theme_color_override("font_color", Palette.IMAD_GOGGLES)
	_name_tag = _label(Control.PRESET_CENTER_TOP, Vector2(0, MARGIN + FONT_SIZE * 1.6))
	_perch_hint = _label(Control.PRESET_CENTER_TOP, Vector2(0, MARGIN + FONT_SIZE * 3.2))
	_perch_hint.text = "Climb down: Bjorn stands next to the perch, then press Interact"
	_carried = _label(Control.PRESET_CENTER_BOTTOM, Vector2(0, -MARGIN - FONT_SIZE * 1.5))
	# A column, so the material names never run into the centred objective line.
	_stash = VBoxContainer.new()
	_stash.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stash.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stash.offset_left = -STASH_RIGHT_GAP
	_stash.offset_right = -STASH_RIGHT_GAP
	_stash.offset_top = MARGIN
	_stash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stash)
	_root.add_child(InventionCard.new())
	_root.add_child(DomeArrow.new())
	Events.state_changed.connect(_refresh)
	Events.air_changed.connect(_refresh_air)
	Events.material_produced.connect(_fly_block)
	_refresh()


## Polled because the roach's hunt is not part of TeamState.
func _process(_delta: float) -> void:
	_objective.text = Objective.text()


func _refresh() -> void:
	var state := TeamState.state
	_refresh_air(float(state.get("air", 0.0)))
	var carried: Array = state.get("carried", [])
	_carried.text = "%d/%d   %s" % [carried.size(), int(Data.balance("carry_capacity")), String(state.get("current_tool", "")).capitalize()]
	var own := "Bjorn" if Net.own_character() == Characters.Character.BJORN else "Imad"
	_name_tag.text = "BJIMAD" if TeamState.mount_state() == MountController.MERGED else own
	var own_imad := Net.own_character() == Characters.Character.IMAD
	_perch_hint.visible = own_imad and bool(state.get("on_perch", false)) and TeamState.mount_state() == MountController.SOLO
	var progress := float(state.get("hold_progress", 0.0))
	_hold_back.visible = progress > 0.0
	_hold_fill.size.x = HOLD_BAR_SIZE.x * progress
	_refresh_stash(state.get("stash", {}))


func _refresh_air(value: float) -> void:
	var ratio := value / float(Data.balance("air_max"))
	_air_fill.size.x = AIR_BAR_SIZE.x * clampf(ratio, 0.0, 1.0)
	_air_fill.color = Palette.DANGER if ratio < AIR_LOW else Palette.RESTORED_TEAL


## Entries are kept, not rebuilt, so a block in flight still finds its counter.
func _refresh_stash(stash: Dictionary) -> void:
	for material: String in stash:
		if not _squares.has(material):
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stash.add_child(row)
			var square := ColorRect.new()
			square.custom_minimum_size = SQUARE_SIZE
			square.pivot_offset = SQUARE_SIZE * 0.5
			square.color = Palette.tint(material)
			square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			square.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(square)
			_squares[material] = square
			var count := Label.new()
			row.add_child(count)
			_counts[material] = count
		(_counts[material] as Label).text = "%s %d" % [material, int(stash[material])]


func _fly_block(material: String, world_position: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world_position):
		return
	var block := ColorRect.new()
	block.size = SQUARE_SIZE
	block.color = Palette.tint(material)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.position = camera.unproject_position(world_position) - SQUARE_SIZE * 0.5
	_root.add_child(block)
	var square := _squares.get(material) as Control
	var target: Vector2 = square.global_position if square != null else _stash.global_position
	var tween := block.create_tween()
	tween.tween_property(block, "global_position", target, FLY_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(block.queue_free)
	if square != null:
		var pop := square.create_tween()
		pop.tween_interval(FLY_SECONDS)
		pop.tween_property(square, "scale", Vector2.ONE * COUNTER_POP, COUNTER_POP_SECONDS)
		pop.tween_property(square, "scale", Vector2.ONE, COUNTER_POP_SECONDS)


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
