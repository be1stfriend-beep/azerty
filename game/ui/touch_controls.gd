class_name TouchControls
extends Control
## Multi-touch pad: a virtual stick on the left, contextual buttons on the right.
## Touches are handled directly (not through Button) so the stick and a button work together.

const STICK_RADIUS := 120.0
const STICK_CAPTURE := 1.8
const KNOB_RADIUS := 55.0
const BUTTON_RADIUS := 90.0
## Imad's one action button: well over the 150 px minimum so it is easy to hit blind.
const BIG_BUTTON_RADIUS := 115.0
const BIG_FONT_SIZE := 30
const DIM_ALPHA := 0.3
const BUTTON_GAP := 36.0
const MARGIN := 70.0
const FONT_SIZE := 34
const ARC_POINTS := 48
const BUTTON_COLUMNS := 2
const MOVE_ACTIONS := {"x": ["move_left", "move_right"], "y": ["move_up", "move_down"]}
## The rider steers the aim, not the body, with the same stick.
const AIM_ACTIONS := {"x": ["aim_left", "aim_right"], "y": ["aim_up", "aim_down"]}

var _buttons: Array[Dictionary] = []
var _stick_index := -1
var _stick_vector := Vector2.ZERO
var _button_touches: Dictionary = {}
var _stick_actions: Dictionary = MOVE_ACTIONS


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	Events.context_changed.connect(_refresh_buttons)
	_refresh_buttons()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_index:
			_set_stick(drag.position)
			get_viewport().set_input_as_handled()


func _on_touch_down(index: int, pos: Vector2) -> void:
	if _stick_index == -1 and pos.distance_to(_stick_center()) <= STICK_RADIUS * STICK_CAPTURE:
		_stick_index = index
		_set_stick(pos)
		get_viewport().set_input_as_handled()
		return
	for i in _buttons.size():
		if pos.distance_to(_button_center(i)) <= _radius(i):
			_button_touches[index] = _buttons[i]["action"]
			Input.action_press(_buttons[i]["action"])
			get_viewport().set_input_as_handled()
			queue_redraw()
			return


func _on_touch_up(index: int) -> void:
	if index == _stick_index:
		_stick_index = -1
		_stick_vector = Vector2.ZERO
		_apply_stick()
	elif _button_touches.has(index):
		Input.action_release(_button_touches[index])
		_button_touches.erase(index)
	queue_redraw()


func _set_stick(pos: Vector2) -> void:
	_stick_vector = (pos - _stick_center()).limit_length(STICK_RADIUS) / STICK_RADIUS
	_apply_stick()
	queue_redraw()


func _apply_stick() -> void:
	for axis: String in _stick_actions:
		var value := _stick_vector.x if axis == "x" else _stick_vector.y
		var pair: Array = _stick_actions[axis]
		_press_strength(pair[0], maxf(-value, 0.0))
		_press_strength(pair[1], maxf(value, 0.0))


func _press_strength(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## Re-evaluated on every Events.context_changed.
func _context_buttons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if Net.own_character() == Characters.Character.BJORN:
		result = [{"label": "Jump", "action": "jump"}, {"label": "Kick", "action": "kick"}]
		if TeamState.mount_state() == MountController.MERGED:
			result.append({"label": "Dismount", "action": "dismount"})
		return result
	var context: Dictionary = {}
	if Game.world != null:
		var cues := Game.world.get_node_or_null("InteractionCues") as InteractionCues
		if cues != null:
			context = cues.context
	var label: String = context.get("label", Data.hint("label_none"))
	var dim: bool = context.get("action", Interaction.NONE) == Interaction.NONE
	result = [{"label": label, "action": "interact", "big": true, "dim": dim}]
	# The tool buttons only appear once the Broomstick has been crafted.
	if (TeamState.state.get("tools", []) as Array).size() > 1:
		result.append({"label": "Use tool", "action": "use_tool"})
		result.append({"label": "Next tool", "action": "tool_next"})
	return result


func _refresh_buttons() -> void:
	_buttons = _context_buttons()
	# A held Interact must survive unrelated context changes (Bjorn walking past cancelled tower holds).
	var still_shown: Array = _buttons.map(func(button: Dictionary) -> String: return button["action"])
	for index: int in _button_touches.keys():
		if not (_button_touches[index] in still_shown):
			Input.action_release(_button_touches[index])
			_button_touches.erase(index)
	var rider := Net.own_character() == Characters.Character.IMAD and TeamState.mount_state() != MountController.SOLO
	var next_actions: Dictionary = AIM_ACTIONS if rider else MOVE_ACTIONS
	if next_actions != _stick_actions:
		# Hand the held stick over to the new action set without lifting the finger.
		var held := _stick_vector
		_stick_vector = Vector2.ZERO
		_apply_stick()
		_stick_actions = next_actions
		_stick_vector = held
		_apply_stick()
	queue_redraw()


func _stick_center() -> Vector2:
	return Vector2(MARGIN + STICK_RADIUS, size.y - MARGIN - STICK_RADIUS)


## Two columns in the bottom-right corner keep clear of the bottom-centre HUD and dialogue.
func _button_center(i: int) -> Vector2:
	var step := BIG_BUTTON_RADIUS * 2.0 + BUTTON_GAP
	var column := i % BUTTON_COLUMNS
	var row := i / BUTTON_COLUMNS
	return Vector2(size.x - MARGIN - BIG_BUTTON_RADIUS - column * step, size.y - MARGIN - BIG_BUTTON_RADIUS - row * step)


func _radius(i: int) -> float:
	return BIG_BUTTON_RADIUS if _buttons[i].get("big", false) else BUTTON_RADIUS


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var center := _stick_center()
	draw_circle(center, STICK_RADIUS, Color(Palette.BONE, 0.18))
	draw_arc(center, STICK_RADIUS, 0.0, TAU, ARC_POINTS, Color(Palette.BONE, 0.6), 4.0)
	draw_circle(center + _stick_vector * STICK_RADIUS, KNOB_RADIUS, Color(Palette.BONE, 0.7))
	var held := _button_touches.values()
	for i in _buttons.size():
		var c := _button_center(i)
		var radius := _radius(i)
		var alpha := DIM_ALPHA if _buttons[i].get("dim", false) else 1.0
		var fill := Palette.BJORN_POMPOM if _buttons[i]["action"] in held else Palette.RUST
		draw_circle(c, radius, Color(fill, 0.75 * alpha))
		draw_arc(c, radius, 0.0, TAU, ARC_POINTS, Color(Palette.BONE, alpha), 4.0)
		var text: String = _buttons[i]["label"]
		var font_size := BIG_FONT_SIZE if _buttons[i].get("big", false) else FONT_SIZE
		var baseline := c + Vector2(-radius, font_size * 0.35)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color(Palette.BONE, alpha))
