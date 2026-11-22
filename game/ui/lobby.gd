class_name Lobby
extends CanvasLayer
## Host or join screen. Net does the work; this only shows buttons and status.

const LAYER := 10
const LAST_IP_PATH := "user://last_ip.cfg"
const DEFAULT_IP := "127.0.0.1"
const BUTTON_SIZE := Vector2(640, 110)
const IP_FIELD_SIZE := Vector2(420, 110)
const JOIN_SIZE := Vector2(200, 110)
const SPACING := 24

var _ip_field: LineEdit
var _ip_label: Label
var _status: Label


func _ready() -> void:
	layer = LAYER
	_build()
	Net.join_failed.connect(_on_join_failed)
	Net.connection_established.connect(func() -> void: set_status("Connected"))


func reset() -> void:
	_ip_label.text = ""
	set_status("")
	show()


func set_status(text: String) -> void:
	_status.text = text


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build()
	add_child(root)
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Palette.SOOT
	root.add_child(background)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", SPACING)
	root.add_child(box)
	var title := Label.new()
	title.text = Data.config().get("title", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_button("Host as Bjorn", BUTTON_SIZE, _host.bind(Characters.Character.BJORN)))
	box.add_child(_button("Host as Imad", BUTTON_SIZE, _host.bind(Characters.Character.IMAD)))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", SPACING)
	box.add_child(join_row)
	_ip_field = LineEdit.new()
	_ip_field.custom_minimum_size = IP_FIELD_SIZE
	_ip_field.text = _load_last_ip()
	join_row.add_child(_ip_field)
	join_row.add_child(_button("Join", JOIN_SIZE, _join))
	_ip_label = Label.new()
	_ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_ip_label)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	if not OS.has_feature("mobile"):
		box.add_child(_button("Quit", BUTTON_SIZE, func() -> void: get_tree().quit()))


func _button(text: String, min_size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.pressed.connect(action)
	return button


func _host(character: int) -> void:
	Net.host(character)
	if not Net.is_online():
		return
	_ip_label.text = "This device: %s" % Net.local_ip()
	set_status("Waiting for partner...")


func _join() -> void:
	var ip := _ip_field.text.strip_edges()
	if ip.is_empty():
		ip = DEFAULT_IP
	_save_last_ip(ip)
	_ip_label.text = ""
	set_status("Joining %s..." % ip)
	Net.join(ip)


func _on_join_failed(reason: String) -> void:
	_ip_label.text = ""
	set_status(reason)
	show()


func _load_last_ip() -> String:
	var config := ConfigFile.new()
	if config.load(LAST_IP_PATH) != OK:
		return DEFAULT_IP
	return config.get_value("net", "ip", DEFAULT_IP)


func _save_last_ip(ip: String) -> void:
	var config := ConfigFile.new()
	config.set_value("net", "ip", ip)
	config.save(LAST_IP_PATH)
