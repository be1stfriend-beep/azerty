extends Node
## Match flow: lobby, start on both peers, return to lobby, partner lost.

## Above the 3D view, below the lobby, overlays and meter.
const POST_LAYER := 5
## Above the post layer, below the lobby.
const TOUCH_LAYER := 8
const DEFAULT_NAME := "Player"
const MAX_NAME_LENGTH := 16

## Either side: the partner's name arrived, so both names are known.
signal partner_joined(partner_name: String, character: int)

var world: Node3D
var local_name: String = DEFAULT_NAME
var player_names: Dictionary[int, String] = {}

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


## The argument that follows a flag, e.g. arg_after("--screenshot", 2) for its second value.
func arg_after(flag: String, offset: int = 1) -> String:
	var args := OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	var index := args.find(flag)
	if index == -1 or index + offset >= args.size():
		return ""
	return args[index + offset]


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


## Offline single-process match for the autotest: the same flow as a networked start.
func start_local_match() -> void:
	_rpc_start_match(Data.config().get("start_level", "main"))


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


func clean_name(text: String) -> String:
	var cleaned := text.strip_edges().left(MAX_NAME_LENGTH)
	return DEFAULT_NAME if cleaned.is_empty() else cleaned


func character_name(character: int) -> String:
	return "Bjorn" if character == Characters.Character.BJORN else "Imad"


func _on_connection_established() -> void:
	player_names.clear()
	_rpc_player_name.rpc_id(Net.partner_peer_id(), local_name)


## Each side sends its name once on connect. The host's name follows the character
## assignment on the same reliable channel, so the guest already knows its own role here.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_name(sent_name: String) -> void:
	if multiplayer.get_remote_sender_id() != Net.partner_peer_id():
		return
	var own := Net.own_character()
	var partner := Characters.Character.IMAD if own == Characters.Character.BJORN else Characters.Character.BJORN
	player_names[own] = local_name
	player_names[partner] = clean_name(sent_name)
	partner_joined.emit(player_names[partner], partner)
	if Net.is_host():
		get_tree().create_timer(float(Data.balance("join_notice_seconds"))).timeout.connect(_start_if_partner)


## The partner (or the host itself) may have left during the join notice.
func _start_if_partner() -> void:
	if Net.is_host() and Net.partner_peer_id() != 0 and world == null:
		start_match()


func _on_partner_lost() -> void:
	if world == null:
		_lobby.on_partner_lost()
		return
	# The peer is gone, so any multiplayer call from the world would error every frame.
	world.process_mode = Node.PROCESS_MODE_DISABLED
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
