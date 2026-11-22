## Two-peer ENet networking. The host is the server AND plays (listen server).
## Never use peer id 1 to mean a character: use own_character() / guest_character().
##
## Command-line (used by tools/run_two.py):
##   --host                 host on port 7777 (own character Bjorn)
##   --host --char imad     host as Imad
##   --join <host_ip>       join a host (character is assigned by the host)
##
## Ordering guarantee: the host sends the character assignment BEFORE it sends
## the "start match" message, on the same reliable channel, so the guest always
## knows its character when the match starts.

extends Node

const PORT := 7777
const MAX_GUESTS := 1

## Host: the guest connected. Guest: the connection to the host is usable.
signal connection_established
## The other player is gone (either side).
signal partner_lost
## host() or join() failed.
signal join_failed(reason: String)
## Guest side: the host told us which character we play.
signal character_assigned(character: int)

var role: int = Characters.Character.BJORN
var guest_role: int = Characters.Character.IMAD

var _is_host: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_auto_launch()


func _auto_launch() -> void:
	var args := OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	if "--host" in args:
		var ch: int = Characters.Character.BJORN
		var i := args.find("--char")
		if i != -1 and i + 1 < args.size():
			ch = _char_from_name(args[i + 1])
		host(ch)
	elif "--join" in args:
		var j := args.find("--join")
		var ip := "127.0.0.1"
		if j + 1 < args.size():
			ip = args[j + 1]
		join(ip)


func _char_from_name(char_text: String) -> int:
	if char_text.to_lower() == "imad":
		return Characters.Character.IMAD
	return Characters.Character.BJORN


# --- Host ---

func host(character: int) -> void:
	leave()
	role = character
	guest_role = _other(character)
	_is_host = true
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_GUESTS) != OK:
		_is_host = false
		join_failed.emit("could not open port %d (is another game running?)" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	print("net: hosting on port %d as %s" % [PORT, _char_name(role)])


# --- Join ---

func join(host_ip: String) -> void:
	leave()
	_is_host = false
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(host_ip, PORT) != OK:
		join_failed.emit("could not create a client for %s" % host_ip)
		return
	multiplayer.multiplayer_peer = peer
	print("net: joining %s" % host_ip)


func leave() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_is_host = false


@rpc("authority", "call_remote", "reliable")
func _rpc_assign_character(assigned_character: int) -> void:
	role = assigned_character
	guest_role = assigned_character
	print("net: assigned character %s" % _char_name(role))
	character_assigned.emit(role)


# --- Queries ---

func is_host() -> bool:
	return _is_host


func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func own_character() -> int:
	return role


func guest_character() -> int:
	return guest_role


func partner_peer_id() -> int:
	if not is_online():
		return 0
	if _is_host:
		var ids := multiplayer.get_peers()
		return 0 if ids.is_empty() else ids[0]
	return 1


## The peer id that controls the given character.
func peer_for_character(character: int) -> int:
	if character == role:
		return multiplayer.get_unique_id()
	return partner_peer_id()


## First private LAN address of this machine, to show on the host's screen.
func local_ip() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "127.0.0.1"


## Round-trip time to the partner in ms, or -1 when not connected.
func rtt_ms() -> int:
	var partner := _partner_enet()
	if partner == null:
		return -1
	return int(partner.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func loss_percent() -> float:
	var partner := _partner_enet()
	if partner == null:
		return 0.0
	return partner.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE) * 100.0


func _partner_enet() -> ENetPacketPeer:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return null
	var target := partner_peer_id()
	if target == 0:
		return null
	return peer.get_peer(target)


# --- Helpers ---

func _other(character: int) -> int:
	if character == Characters.Character.BJORN:
		return Characters.Character.IMAD
	return Characters.Character.BJORN


func _char_name(character: int) -> String:
	return "Bjorn" if character == Characters.Character.BJORN else "Imad"


# --- Signal handlers ---

func _on_peer_connected(peer_id: int) -> void:
	if not _is_host:
		return
	print("net: guest connected (id %d)" % peer_id)
	_rpc_assign_character.rpc_id(peer_id, guest_role)
	connection_established.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if _is_host:
		print("net: guest disconnected (id %d)" % peer_id)
		partner_lost.emit()


func _on_connected_to_server() -> void:
	print("net: connected to host")
	connection_established.emit()


func _on_connection_failed() -> void:
	join_failed.emit("could not reach the host. Same wifi? Firewall? Right IP?")


func _on_server_disconnected() -> void:
	print("net: host went away")
	partner_lost.emit()
