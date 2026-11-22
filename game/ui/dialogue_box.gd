class_name DialogueBox
extends CanvasLayer
## Bottom-centre speech panel. Lines advance on tap or after LINE_SECONDS.
## Sized to sit between the touch stick and the touch buttons, above the carried counter.

signal sequence_finished(id: String)

const LAYER := 11
const LINE_SECONDS := 3.5
const PANEL_WIDTH := 960.0
const PANEL_HEIGHT := 190.0
const BOTTOM_GAP := 110.0
const SPEAKER_COLORS := {"Bjorn": Palette.BJORN_PARKA, "Imad": Palette.IMAD_GOGGLES}

var _queue: Array[Dictionary] = []
var _elapsed := 0.0
var _panel: PanelContainer
var _speaker: Label
var _text: Label


func _ready() -> void:
	layer = LAYER
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -PANEL_WIDTH * 0.5
	_panel.offset_right = PANEL_WIDTH * 0.5
	_panel.offset_top = -BOTTOM_GAP - PANEL_HEIGHT
	_panel.offset_bottom = -BOTTOM_GAP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_speaker = Label.new()
	box.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)
	_panel.hide()
	Events.dialogue_requested.connect(_on_requested)


func _process(delta: float) -> void:
	if _queue.is_empty():
		return
	_elapsed += delta
	if _elapsed >= LINE_SECONDS:
		_advance()


func _on_requested(id: String) -> void:
	var was_idle := _queue.is_empty()
	for line: Dictionary in Data.dialogue(id):
		var entry := line.duplicate()
		entry["sequence"] = id
		_queue.append(entry)
	if was_idle:
		_show_current()


func _on_panel_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and not _queue.is_empty():
		_advance()
		_panel.accept_event()


func _advance() -> void:
	var finished: String = _queue.pop_front()["sequence"]
	if _queue.is_empty() or _queue[0]["sequence"] != finished:
		sequence_finished.emit(finished)
	_show_current()


func _show_current() -> void:
	_elapsed = 0.0
	if _queue.is_empty():
		_panel.hide()
		return
	var line := _queue[0]
	var speaker: String = line.get("speaker", "")
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", SPEAKER_COLORS.get(speaker, Palette.BONE))
	_text.text = line.get("text", "")
	_panel.show()
