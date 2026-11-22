class_name SliceHunt
extends Node
## Slice only. The host starts the roach hunt once and closes it when the roach is back at
## its lair. The team then scavenges for a Filter and lights the purification tower; once
## its colour has spread, the slice is complete. Both peers read the outcome from
## TeamState, so the card appears on both screens together.

const HUNT_NONE := ""
const HUNTING := "on"
const HUNT_DONE := "done"
const SHAKE_STRENGTH := 0.35
const SHAKE_SECONDS := 0.8
const GROWL_RATE := 22050
const GROWL_SECONDS := 1.1
const GROWL_START_HZ := 95.0
const GROWL_END_HZ := 55.0
const GROWL_NOISE := 0.35
const GROWL_VOLUME := 0.6
const SAMPLE_MAX := 32767.0

var _outside_picks := 0
var _lit_for := 0.0
var _growl: AudioStreamPlayer
var _card: MessageOverlay


func _init() -> void:
	name = "SliceHunt"


func _ready() -> void:
	_growl = AudioStreamPlayer.new()
	_growl.stream = _build_growl()
	add_child(_growl)
	Events.trash_picked.connect(_on_trash_picked)
	Events.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	var roach := get_parent().get_node_or_null("cockroach") as Cockroach
	if not multiplayer.is_server() or TeamState.state.is_empty() or roach == null:
		return
	match String(TeamState.state.get("hunt", HUNT_NONE)):
		HUNT_NONE:
			if _anyone_beyond(float(Data.balance("hunt_trigger_distance"))):
				_start_hunt()
		HUNTING:
			# A knockout puts the roach back to sleep, so the hunt can start over.
			if roach.machine.state == Cockroach.IDLE:
				_outside_picks = 0
				TeamState.set_values({"hunt": HUNT_NONE})
			elif roach.machine.state in [Cockroach.GUARD, Cockroach.GONE]:
				TeamState.set_values({"hunt": HUNT_DONE})
		HUNT_DONE:
			if TeamState.state.get("slice_complete", false) or not tower_lit():
				return
			# The card waits a moment so both players see the colour come back first.
			_lit_for += delta
			if _lit_for >= float(Data.balance("slice_end_delay")):
				TeamState.set_values({"slice_complete": true})


## Read on both peers: the slice tower has been activated with a Filter.
static func tower_lit() -> bool:
	return not (TeamState.state.get("towers", []) as Array).is_empty()


func _on_trash_picked(id: String) -> void:
	if not multiplayer.is_server() or TeamState.state.get("hunt", HUNT_NONE) != HUNT_NONE:
		return
	var trash := get_parent().get_node_or_null("Entities/%s" % id) as Node3D
	if trash == null or StationRules.flat_distance(trash.global_position, RoachTargets.dome_center()) <= float(Data.balance("dome_radius")):
		return
	_outside_picks += 1
	if _outside_picks >= int(Data.balance("slice_outside_trash_needed")):
		# Deferred: this runs inside a state push, and starting the hunt pushes again.
		_start_hunt.call_deferred()


## Host: the roach appears behind the team, on the side away from the Dome.
func _start_hunt() -> void:
	var roach := get_parent().get_node_or_null("cockroach") as Cockroach
	var players := RoachTargets.players()
	if roach == null or players.is_empty() or TeamState.state.get("hunt", HUNT_NONE) != HUNT_NONE:
		return
	var team := Vector3.ZERO
	for player in players:
		team += player.global_position / players.size()
	var center := RoachTargets.dome_center()
	var away := Vector3(team.x - center.x, 0.0, team.z - center.z)
	if away.length() < 0.01:
		away = Vector3.BACK
	var spawn := team + away.normalized() * float(Data.balance("roach_hunt_spawn_distance"))
	roach.server_hunt(Vector3(spawn.x, 0.0, spawn.z))
	TeamState.set_values({"hunt": HUNTING})
	_rpc_warn.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_warn() -> void:
	var camera := get_viewport().get_camera_3d() as FollowCamera
	if camera != null:
		camera.shake(SHAKE_STRENGTH, SHAKE_SECONDS)
	_growl.play()
	Game.show_message(Data.hint("hunt_warning"))


func _anyone_beyond(distance: float) -> bool:
	for player in RoachTargets.players():
		if StationRules.flat_distance(player.global_position, RoachTargets.dome_center()) > distance:
			return true
	return false


func _on_state_changed() -> void:
	if _card != null or not TeamState.state.get("slice_complete", false):
		return
	_card = MessageOverlay.new(Data.hint("slice_card"), Data.hint("slice_restart"))
	# Below the partner-lost overlay, which must always win.
	_card.layer = MessageOverlay.LAYER - 1
	_card.confirmed.connect(_on_restart_pressed)
	add_child(_card)


func _on_restart_pressed() -> void:
	if multiplayer.is_server():
		# Deferred: restarting frees the world, and this button lives inside it.
		Game.start_match.call_deferred()
	else:
		_rpc_request_restart.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_restart() -> void:
	if multiplayer.get_remote_sender_id() == Net.partner_peer_id() and TeamState.state.get("slice_complete", false):
		Game.start_match.call_deferred()


static func _build_growl() -> AudioStreamWAV:
	var count := int(GROWL_RATE * GROWL_SECONDS)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for n in count:
		var t := float(n) / count
		phase += lerpf(GROWL_START_HZ, GROWL_END_HZ, t) / GROWL_RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var value := (saw + randf_range(-1.0, 1.0) * GROWL_NOISE) * sin(PI * t) * GROWL_VOLUME
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * SAMPLE_MAX))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = GROWL_RATE
	wav.stereo = false
	wav.data = data
	return wav
