extends Node
## Match flow: lobby, start on both peers, return to lobby, partner lost.

const VIGNETTE_SHADER_PATH := "res://shaders/vignette.gdshader"
## Above the 3D view, below the lobby, overlays and meter.
const POST_LAYER := 5
## Above the post layer, below the lobby.
const TOUCH_LAYER := 8

var world: Node3D

var _lobby: Lobby
var _overlay: MessageOverlay
var _toast: Toast


func _ready() -> void:
	InputSetup.register()
	_add_post_layer()
	_lobby = Lobby.new()
	_lobby.hide()
	add_child(_lobby)
	add_child(NetMeter.new())
	_toast = Toast.new()
	add_child(_toast)
	Net.connection_established.connect(_on_connection_established)
	Net.partner_lost.connect(_on_partner_lost)


func _notification(what: int) -> void:
	# Closing the window disconnects cleanly so the partner sees it at once, not after a timeout.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Net.leave()


func has_arg(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args() or flag in OS.get_cmdline_args()


func show_message(text: String) -> void:
	_toast.show_text(text)


func show_lobby() -> void:
	_lobby.reset()


func start_match() -> void:
	if not Net.is_host():
		return
	_rpc_start_match.rpc(Data.config().get("start_level", "main"))


@rpc("authority", "call_local", "reliable")
func _rpc_start_match(level_name: String) -> void:
	_close_overlay()
	_lobby.hide()
	load_world(level_name)
	# Sent after the start RPC on the same reliable channel, so the guest's world exists.
	TeamState.reset()
	_spawn_players()


func load_world(level_name: String) -> Node3D:
	_clear_world()
	world = LevelLoader.load_level(level_name, get_tree().current_scene)
	return world


## Runs identically on both peers; each player node picks its own authority.
func _spawn_players() -> void:
	world.add_child(MountController.new())
	world.add_child(TrashHider.new())
	var own: PlayerBase
	var other: PlayerBase
	for player: PlayerBase in [Bjorn.new(), Imad.new()]:
		var marker := world.get_node_or_null("Markers/%s" % player.name) as Node3D
		if marker != null:
			player.position = marker.position
		world.add_child(player)
		if player.character == Net.own_character():
			own = player
		else:
			other = player
	var camera := FollowCamera.new()
	world.add_child(camera)
	camera.setup(own, other)
	if DisplayServer.is_touchscreen_available() or has_arg("--touch"):
		var layer := CanvasLayer.new()
		layer.layer = TOUCH_LAYER
		layer.add_child(TouchControls.new())
		world.add_child(layer)


func return_to_lobby() -> void:
	_clear_world()
	TeamState.clear()
	_close_overlay()
	Net.leave()
	show_lobby()


func _on_connection_established() -> void:
	if Net.is_host():
		start_match()


func _on_partner_lost() -> void:
	if world == null:
		_lobby.set_status("Partner lost")
		return
	_close_overlay()
	_overlay = MessageOverlay.new("Partner lost", "Back to lobby")
	_overlay.confirmed.connect(return_to_lobby)
	add_child(_overlay)


func _clear_world() -> void:
	if world == null:
		return
	# Detach now so a new World can take the same node name in this frame.
	world.get_parent().remove_child(world)
	world.queue_free()
	world = null


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _add_post_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PostLayer"
	layer.layer = POST_LAYER
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(VIGNETTE_SHADER_PATH)
	mat.set_shader_parameter("haze_color", Palette.HAZE_SKY)
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)
