extends Node
## Match flow: lobby, start on both peers, return to lobby, partner lost.

## Above the 3D view, below the lobby, overlays and meter.
const POST_LAYER := 5
## Above the post layer, below the lobby.
const TOUCH_LAYER := 8

var world: Node3D

var _lobby: Lobby
var _overlay: MessageOverlay
var _toast: Toast
var _craft_menu: CraftMenu


func _ready() -> void:
	InputSetup.register()
	Style.add_post_layer(self, POST_LAYER)
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


## Host: show a message on one peer's screen.
func tell(peer: int, text: String) -> void:
	if peer == multiplayer.get_unique_id():
		show_message(text)
	else:
		_rpc_message.rpc_id(peer, text)


@rpc("authority", "call_remote", "reliable")
func _rpc_message(text: String) -> void:
	show_message(text)


func show_end_card() -> void:
	_close_overlay()
	if Net.is_host():
		_overlay = MessageOverlay.new("To be continued", "Restart")
		_overlay.confirmed.connect(start_match)
	else:
		_overlay = MessageOverlay.new("To be continued
The host can restart", "Back to lobby")
		_overlay.confirmed.connect(return_to_lobby)
	add_child(_overlay)


func show_craft_menu() -> void:
	if is_instance_valid(_craft_menu):
		_craft_menu.open()


func player(character: int) -> PlayerBase:
	if world == null:
		return null
	var node_name := "bjorn" if character == Characters.Character.BJORN else "imad"
	return world.get_node_or_null(node_name) as PlayerBase


## The body that stands in the world for the team: Bjorn while merged, Imad when solo.
func team_body() -> PlayerBase:
	if TeamState.mount_state() == MountController.SOLO:
		return player(Characters.Character.IMAD)
	return player(Characters.Character.BJORN)


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
	world.add_child(AirSystem.new())
	var roach := Cockroach.new()
	var roach_marker := world.get_node_or_null("Markers/roach") as Node3D
	if roach_marker != null:
		roach.position = roach_marker.position
	world.add_child(roach)
	world.add_child(Hud.new())
	var dialogue := DialogueBox.new()
	world.add_child(dialogue)
	world.add_child(Story.new(dialogue))
	_craft_menu = CraftMenu.new()
	world.add_child(_craft_menu)
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
	# Freed at once (never from inside a world node's callback) so no stale node in it
	# reacts to the next match's first state push, and the new World can take its name.
	world.free()
	world = null
	for action: String in InputSetup.KEYS:
		Input.action_release(action)
	Style.reset_towers()


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
