class_name NetMeter
extends CanvasLayer
## Debug panel (F3 or the corner button). Other systems add lines with NetMeter.set_line().

const LAYER := 30
const REFRESH_SECONDS := 0.5
const FONT_SIZE := 24
const TOGGLE_SIZE := Vector2(90, 56)
const MARGIN := 12.0
const BITS_PER_BYTE := 8.0
const BITS_PER_KILOBIT := 1000.0

static var _lines: Dictionary = {}

var _panel: PanelContainer
var _label: Label
var _elapsed: float = 0.0


static func set_line(key: String, text: String) -> void:
	_lines[key] = text


func _ready() -> void:
	layer = LAYER
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build(FONT_SIZE)
	add_child(root)
	var toggle := Button.new()
	toggle.text = "NET"
	toggle.custom_minimum_size = TOGGLE_SIZE
	toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle.position = Vector2(-TOGGLE_SIZE.x - MARGIN, MARGIN)
	toggle.pressed.connect(_toggle)
	root.add_child(toggle)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -MARGIN
	_panel.offset_right = -MARGIN
	_panel.offset_top = TOGGLE_SIZE.y + MARGIN * 2.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	root.add_child(_panel)
	_label = Label.new()
	_panel.add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_toggle()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	var text := _role_text()
	# A closed peer errors on every statistics query, so only read them while connected.
	if _is_connected():
		text += "\nping %d ms\nloss %.1f %%" % [Net.rtt_ms(), Net.loss_percent()]
		text += _bandwidth_text(_elapsed)
	text += "\nfps %d   draws %d" % [Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	for key: String in _lines:
		text += "\n%s: %s" % [key, _lines[key]]
	_label.text = text
	_elapsed = 0.0


func _toggle() -> void:
	_panel.visible = not _panel.visible


func _is_connected() -> bool:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _role_text() -> String:
	if not Net.is_online():
		return "offline"
	var own := Net.own_character()
	var text := "%s as %s %s" % ["host" if Net.is_host() else "guest", Game.character_name(own), Game.player_names.get(own, Game.local_name)]
	for character: int in Game.player_names:
		if character != own:
			text += "\npartner %s %s" % [Game.character_name(character), Game.player_names[character]]
	return text


## Statistics are popped every refresh, even when hidden, so each reading covers one interval.
func _bandwidth_text(seconds: float) -> String:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or peer.host == null:
		return ""
	var sent := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var received := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	var scale := BITS_PER_BYTE / BITS_PER_KILOBIT / seconds
	return "\nup %.1f kbps\ndown %.1f kbps" % [sent * scale, received * scale]
