extends Node3D
## Hazard jet: off, warn (dust rises, red ring) then on. While on, each player in the footprint
## loses vent_air_hit air once per burst and is pushed back. The host runs the clock and sends
## each phase change reliably; peers only animate.

const OFF := "off"
const WARN := "warn"
const ON := "on"
const DUST_IDLE := 0.05
const DUST_WARN := 0.35
const DUST_LERP := 10.0
const WARN_FLICKER_HZ := 8.0

var _phase := OFF
var _clock := 0.0
var _hit: Dictionary = {}
var _push := Vector3.BACK
var _dust: Node3D
var _warn: Node3D


func _ready() -> void:
	var params: Dictionary = get_meta("params", {})
	# A negative start staggers neighbouring vents along the corridor.
	_clock = -float(params.get("phase", 0.0))
	var push: Array = params.get("push", [0.0, -1.0])
	_push = Vector3(push[0], 0.0, push[1]).normalized()
	_dust = get_node_or_null("Visual/Dust") as Node3D
	_warn = get_node_or_null("Visual/Warn") as Node3D


func _process(delta: float) -> void:
	if multiplayer.is_server() and not TeamState.state.is_empty():
		_tick(delta)
	_animate(delta)


func _tick(delta: float) -> void:
	if TeamState.state.get("vents_off", false):
		_set_phase(OFF)
		return
	_clock += delta
	var off := float(Data.balance("vent_off"))
	var t := fposmod(_clock, off + float(Data.balance("vent_on")))
	var phase := OFF
	if t >= off:
		phase = ON
	elif t >= off - float(Data.balance("vent_warn")):
		phase = WARN
	_set_phase(phase)
	if _phase == ON:
		_hit_players()


func _set_phase(phase: String) -> void:
	if phase == _phase:
		return
	_rpc_phase.rpc(phase)


@rpc("authority", "call_local", "reliable")
func _rpc_phase(phase: String) -> void:
	_phase = phase
	if phase == ON:
		_hit.clear()


func _hit_players() -> void:
	var air := get_parent().get_parent().get_node_or_null("AirSystem") as AirSystem
	var radius := float(Data.balance("vent_radius"))
	for player in RoachTargets.players():
		# The rider shares Bjorn's body: one hit for the pair.
		if player is Imad and TeamState.mount_state() != MountController.SOLO:
			continue
		if _hit.has(player.name) or StationRules.flat_distance(player.global_position, global_position) > radius:
			continue
		_hit[player.name] = true
		if air != null:
			air.damage(float(Data.balance("vent_air_hit")))
		player.knock_back.rpc(_push * float(Data.balance("vent_push")))


func _animate(delta: float) -> void:
	if _dust != null:
		var target := DUST_IDLE
		if _phase == ON:
			target = 1.0
		elif _phase == WARN:
			target = DUST_WARN
		_dust.scale.y = lerpf(_dust.scale.y, target, 1.0 - exp(-DUST_LERP * delta))
		_dust.visible = _dust.scale.y > DUST_IDLE * 1.5
	if _warn != null:
		var flicker := sin(Time.get_ticks_msec() * 0.001 * TAU * WARN_FLICKER_HZ) > 0.0
		_warn.visible = _phase == ON or (_phase == WARN and flicker)
