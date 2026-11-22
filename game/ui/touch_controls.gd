class_name TouchControls
extends Control
## Multi-touch pad: a virtual stick on the left, contextual buttons on the right.
## Touches are handled directly (not through Button) so the stick and a button work together.

const STICK_RADIUS := 120.0
const STICK_CAPTURE := 1.8
const KNOB_RADIUS := 55.0
const BUTTON_RADIUS := 90.0
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
		if pos.distance_to(_button_center(i)) <= BUTTON_RADIUS:
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
	var merged := TeamState.mount_state() != MountController.SOLO
	if Net.own_character() == Characters.Character.BJORN:
		result = [{"label": "Jump", "action": "jump"}]
		result.append({"label": "Dismount", "action": "dismount"} if merged else {"label": "Kick", "action": "kick"})
	elif merged:
		result = [
			{"label": "Use tool", "action": "use_tool"}, {"label": "Interact", "action": "interact"},
			{"label": "Next tool", "action": "tool_next"}, {"label": "Dismount", "action": "dismount"},
		]
	else:
		result = [{"label": "Grab", "action": "grab"}, {"label": "Interact", "action": "interact"}]
		var imad: Imad = null
		if Game.world != null:
			imad = Game.world.get_node_or_null("imad") as Imad
		if imad != null and imad.bjorn_in_range:
			var label := "Climb down" if TeamState.state.get("on_perch", false) else "Mount"
			result.append({"label": label, "action": "mount"})
	return result


func _refresh_buttons() -> void:
	for index: int in _button_touches:
		Input.action_release(_button_touches[index])
	_button_touches.clear()
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
	_buttons = _context_buttons()
	queue_redraw()


func _stick_center() -> Vector2:
	return Vector2(MARGIN + STICK_RADIUS, size.y - MARGIN - STICK_RADIUS)


## Two columns in the bottom-right corner keep clear of the bottom-centre HUD and dialogue.
func _button_center(i: int) -> Vector2:
	var step := BUTTON_RADIUS * 2.0 + BUTTON_GAP
	var column := i % BUTTON_COLUMNS
	var row := i / BUTTON_COLUMNS
	return Vector2(size.x - MARGIN - BUTTON_RADIUS - column * step, size.y - MARGIN - BUTTON_RADIUS - row * step)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var center := _stick_center()
	draw_circle(center, STICK_RADIUS, Color(Palette.BONE, 0.18))
	draw_arc(center, STICK_RADIUS, 0.0, TAU, ARC_POINTS, Color(Palette.BONE, 0.6), 4.0)
	draw_circle(center + _stick_vector * STICK_RADIUS, KNOB_RADIUS, Color(Palette.BONE, 0.7))
	var held := _button_touches.values()
	for i in _buttons.size():
		var c := _button_center(i)
		var fill := Palette.BJORN_POMPOM if _buttons[i]["action"] in held else Palette.RUST
		draw_circle(c, BUTTON_RADIUS, Color(fill, 0.75))
		draw_arc(c, BUTTON_RADIUS, 0.0, TAU, ARC_POINTS, Palette.BONE, 4.0)
		var text: String = _buttons[i]["label"]
		var baseline := c + Vector2(-BUTTON_RADIUS, FONT_SIZE * 0.35)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, BUTTON_RADIUS * 2.0, FONT_SIZE, Palette.BONE)
