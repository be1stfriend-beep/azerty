class_name Lobby
extends CanvasLayer
## Login screen: name, server address, host or join, this device's LAN addresses, status.
## Net does the connecting; this screen drives it and says plainly what is happening.

enum Mode { IDLE, HOSTING, JOINING, CONNECTED }

const LAYER := 10
const MARGIN := 32
const LEFT_RATIO := 1.3
const CHOICE_BJORN := "host_bjorn"
const CHOICE_IMAD := "host_imad"
const CHOICE_JOIN := "join"
const IDLE_TEXT := "Host a game, or type the host's address and join."
const NO_ANSWER := "No answer from %s. Check: same Wi-Fi, host game is running, firewall allows UDP %d, mobile data is off."
const PRIVATE_B_FIRST := 16
const PRIVATE_B_LAST := 31
const COLOUR_IDLE := Palette.BONE
const COLOUR_BUSY := Palette.IMAD_GOGGLES
const COLOUR_OK := Palette.RESTORED_GRASS
const COLOUR_ERROR := Palette.DANGER

var _settings := LobbySettings.new()
var _mode: Mode = Mode.IDLE
var _join_address: String = ""
var _name_field: LineEdit
var _address_field: LineEdit
var _recent_row: HFlowContainer
var _choices: Dictionary[String, Button] = {}
var _network_label: Label
var _status: Label
var _cancel: Button
var _join_timer: Timer


func _ready() -> void:
	layer = LAYER
	_settings.load_file()
	Game.local_name = _settings.player_name
	_build()
	_join_timer = Timer.new()
	_join_timer.one_shot = true
	_join_timer.timeout.connect(_on_join_timeout)
	add_child(_join_timer)
	Net.join_failed.connect(_on_join_failed)
	Net.connection_established.connect(_on_connected)
	Net.character_assigned.connect(_on_character_assigned)
	Game.partner_joined.connect(_on_partner_joined)
	_set_mode(Mode.IDLE)


func reset() -> void:
	_join_timer.stop()
	_set_mode(Mode.IDLE)
	set_status(IDLE_TEXT)
	_network_label.text = _network_text()
	show()


func set_status(text: String, colour: Color = COLOUR_IDLE) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", colour)


## The host keeps its server open so the partner can come back; a guest drops to idle.
func on_partner_lost() -> void:
	if Net.is_host():
		_set_mode(Mode.HOSTING)
		set_status("Partner lost. Hosting. Waiting for partner...", COLOUR_ERROR)
		return
	Net.leave()
	_set_mode(Mode.IDLE)
	set_status("Partner lost", COLOUR_ERROR)


static func private_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address: String in IP.get_local_addresses():
		var parts := address.split(".")
		# IPv6 never splits into four parts; loopback and 169.254 match none of the ranges.
		if parts.size() != 4:
			continue
		var second := parts[1].to_int()
		if parts[0] == "10" or (parts[0] == "192" and second == 168) \
				or (parts[0] == "172" and second >= PRIVATE_B_FIRST and second <= PRIVATE_B_LAST):
			result.append(address)
	return result


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build()
	add_child(root)
	var backdrop := LobbyBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	root.add_child(margin)
	var page := UiParts.vbox()
	margin.add_child(page)
	page.add_child(WobbleTitle.new(str(Data.config().get("title", "")).to_upper()))
	var columns := UiParts.hbox()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	columns.add_child(_left_column())
	columns.add_child(_right_column())
	page.add_child(_status_row())


func _left_column() -> PanelContainer:
	var box := UiParts.vbox()
	_name_field = UiParts.field(_settings.player_name, Game.DEFAULT_NAME)
	_name_field.max_length = Game.MAX_NAME_LENGTH
	box.add_child(UiParts.labelled("Name", _name_field))
	_address_field = UiParts.field(_settings.address, LobbySettings.DEFAULT_ADDRESS)
	box.add_child(UiParts.labelled("Server", _address_field))
	_recent_row = HFlowContainer.new()
	_recent_row.add_theme_constant_override("h_separation", UiParts.SPACING)
	_recent_row.add_theme_constant_override("v_separation", UiParts.SPACING)
	box.add_child(_recent_row)
	_rebuild_recent()
	box.add_child(_choice_button("Join", CHOICE_JOIN, _join))
	return UiParts.panel(box, LEFT_RATIO)


func _right_column() -> PanelContainer:
	var box := UiParts.vbox()
	box.add_child(_choice_button("Host as Bjorn", CHOICE_BJORN, _host.bind(Characters.Character.BJORN, CHOICE_BJORN)))
	box.add_child(_choice_button("Host as Imad", CHOICE_IMAD, _host.bind(Characters.Character.IMAD, CHOICE_IMAD)))
	var header := Label.new()
	header.text = "This device (give to partner):"
	header.add_theme_color_override("font_color", Palette.HAZE_SKY)
	box.add_child(header)
	_network_label = Label.new()
	_network_label.text = _network_text()
	box.add_child(_network_label)
	return UiParts.panel(box)


func _status_row() -> PanelContainer:
	var row := UiParts.hbox()
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)
	_cancel = UiParts.button("Cancel", _cancel_pressed)
	row.add_child(_cancel)
	if not OS.has_feature("mobile"):
		row.add_child(UiParts.button("Quit", func() -> void: get_tree().quit()))
	set_status(IDLE_TEXT)
	return UiParts.panel(row)


func _network_text() -> String:
	var lines := PackedStringArray()
	for address in private_addresses():
		lines.append("%s:%d" % [address, Net.PORT])
	if lines.is_empty():
		return "No Wi-Fi address. Join a Wi-Fi or hotspot."
	return "\n".join(lines)


func _rebuild_recent() -> void:
	for child in _recent_row.get_children():
		child.queue_free()
	for address in _settings.recent:
		_recent_row.add_child(UiParts.button(address, func() -> void: _address_field.text = address))


func _choice_button(text: String, choice: String, action: Callable) -> Button:
	var button := UiParts.button(text, action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices[choice] = button
	return button


## Buttons lock while busy; the last choice is tinted so a returning player sees it.
func _set_mode(mode: Mode) -> void:
	_mode = mode
	_cancel.visible = mode == Mode.HOSTING or mode == Mode.JOINING
	for choice: String in _choices:
		var button := _choices[choice]
		button.disabled = mode != Mode.IDLE
		if choice == _settings.choice:
			button.add_theme_stylebox_override("normal", UiParts.tinted_box(Palette.RESTORED_TEAL))
		else:
			button.remove_theme_stylebox_override("normal")


func _commit(choice: String) -> void:
	_name_field.text = Game.clean_name(_name_field.text)
	Game.local_name = _name_field.text
	_settings.player_name = _name_field.text
	_settings.choice = choice
	_settings.save_file()


func _host(character: int, choice: String) -> void:
	_commit(choice)
	Net.host(character)
	if not Net.is_online():
		return
	_set_mode(Mode.HOSTING)
	set_status("Hosting. Waiting for partner...", COLOUR_BUSY)


func _join() -> void:
	var address := _address_field.text.strip_edges()
	if address.is_empty():
		address = LobbySettings.DEFAULT_ADDRESS
	_address_field.text = address
	_settings.remember_address(address)
	_commit(CHOICE_JOIN)
	_rebuild_recent()
	_join_address = address
	_set_mode(Mode.JOINING)
	set_status("Connecting to %s..." % address, COLOUR_BUSY)
	_join_timer.start(float(Data.balance("join_timeout")))
	Net.join(address)


func _cancel_pressed() -> void:
	_join_timer.stop()
	Net.leave()
	_set_mode(Mode.IDLE)
	set_status(IDLE_TEXT)


func _on_join_timeout() -> void:
	if _mode != Mode.JOINING:
		return
	Net.leave()
	_set_mode(Mode.IDLE)
	set_status(NO_ANSWER % [_join_address, Net.PORT], COLOUR_ERROR)


func _on_join_failed(reason: String) -> void:
	_join_timer.stop()
	var text := NO_ANSWER % [_join_address, Net.PORT] if _mode == Mode.JOINING else reason
	Net.leave()
	_set_mode(Mode.IDLE)
	set_status(text, COLOUR_ERROR)
	show()


func _on_connected() -> void:
	_join_timer.stop()
	if not Net.is_host():
		_set_mode(Mode.CONNECTED)
		set_status("Connected. Waiting for the host...", COLOUR_OK)


func _on_character_assigned(character: int) -> void:
	_join_timer.stop()
	_set_mode(Mode.CONNECTED)
	set_status("Connected as %s" % Game.character_name(character), COLOUR_OK)


func _on_partner_joined(partner_name: String, character: int) -> void:
	if Net.is_host():
		_set_mode(Mode.CONNECTED)
		set_status("%s joined as %s" % [partner_name, Game.character_name(character)], COLOUR_OK)
