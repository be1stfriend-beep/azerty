class_name Autotest
extends Node
## --autotest: one offline process plays host for both characters by calling the host-side
## request handlers directly with each character's peer id. No input is simulated.

const MOUNT_CYCLES := 20
const PICKUPS := 3
const STEP_TIMEOUT := 3.0
const TOWER_TIMEOUT := 8.0
const STATION_OFFSET := Vector3(0, 0, 2.0)
const PICKUP_OFFSET := Vector3(0.8, 0, 0)
const BESIDE_BJORN := Vector3(1.0, 0, 0)
## Outside the Dome and the tower radius, and beyond the roach's wake distance.
const OUTSIDE := Vector3(30, 0, 40)
const RESPAWN_TOLERANCE := 1.0
## Roach at its spawn (0,0,52): Imad 8 m away, Bjorn 21 m (inside bait range) then 51 m (outside).
const BAIT_IMAD := Vector3(8, 0, 50)
const BAIT_BJORN_NEAR := Vector3(20, 0, 45)
const BAIT_BJORN_FAR := Vector3(30, 0, 10)
## Where a charge from the south stops against the pillar at (0,0,36).
const STUN_SPOT := Vector3(0, 0, 39.1)
const FLEE_TIMEOUT := 12.0

var _failures := 0
var _passes := 0
var _bjorn_id: int
var _imad_id: int


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.start_local_match()
	await get_tree().process_frame
	_bjorn_id = Net.peer_for_character(Characters.Character.BJORN)
	_imad_id = Net.peer_for_character(Characters.Character.IMAD)
	print("autotest: fake peer ids bjorn=%d imad=%d" % [_bjorn_id, _imad_id])
	await _test_mount()
	_test_pickup()
	_test_recycle()
	_test_craft()
	await _test_tower()
	await _test_air()
	_test_roach_bait()
	await _test_roach_flee()
	print("autotest: %d PASS, %d FAIL" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_mount() -> void:
	var controller := Game.world.get_node("MountController") as MountController
	var bjorn := Game.player(Characters.Character.BJORN)
	var imad := Game.player(Characters.Character.IMAD)
	for i in MOUNT_CYCLES:
		imad.respawn(bjorn.global_position + BESIDE_BJORN)
		controller._server_mount(_imad_id)
		if not await _wait_for(func() -> bool: return TeamState.mount_state() == MountController.MERGED, STEP_TIMEOUT):
			_fail("mount_dismount_x20", "cycle %d never reached MERGED (%s)" % [i, TeamState.mount_state()])
			return
		controller._server_dismount(_bjorn_id)
		if not await _wait_for(func() -> bool: return TeamState.mount_state() == MountController.SOLO, STEP_TIMEOUT):
			_fail("mount_dismount_x20", "cycle %d never returned to SOLO (%s)" % [i, TeamState.mount_state()])
			return
	_pass("mount_dismount_x20")


func _test_pickup() -> void:
	var imad := Game.player(Characters.Character.IMAD)
	var before := (TeamState.state["carried"] as Array).size()
	var picked := 0
	for node: Node in Game.world.get_node("Entities").get_children():
		if picked == PICKUPS:
			break
		if node.get_meta("kind", "") != "trash":
			continue
		var trash := node as Node3D
		imad.respawn(trash.global_position + PICKUP_OFFSET)
		TeamState._server_use_tool(trash.global_position, _imad_id)
		picked += 1
	var carried := (TeamState.state["carried"] as Array).size()
	_check("pickup_x3", carried == before + PICKUPS, "carried %d, expected %d" % [carried, before + PICKUPS])


func _test_recycle() -> void:
	_place_imad_at("recycler_0")
	TeamState._server_recycle("recycler_0", _imad_id)
	var carried := (TeamState.state["carried"] as Array).size()
	var stash: Dictionary = TeamState.state["stash"]
	_check("recycle", carried == 0 and not stash.is_empty(), "carried %d, stash %s" % [carried, stash])


func _test_craft() -> void:
	var stash: Dictionary = (TeamState.state["stash"] as Dictionary).duplicate()
	var cost: Dictionary = Data.recipe("filter")["cost"]
	for material: String in cost:
		stash[material] = maxi(int(stash.get(material, 0)), int(cost[material]))
	TeamState.set_values({"stash": stash})
	print("autotest: gave stash %s through TeamState so the filter is affordable" % stash)
	_place_imad_at("bench_0")
	TeamState._server_craft("filter", _imad_id)
	var filters := int((TeamState.state["inventory"] as Dictionary).get("filter", 0))
	_check("craft_filter", filters == 1, "inventory filter = %d" % filters)


func _test_tower() -> void:
	_place_imad_at("tower_0")
	TeamState._server_hold("tower_0", true, _imad_id)
	var activated := await _wait_for(func() -> bool: return 0 in TeamState.state["towers"], TOWER_TIMEOUT)
	_check("tower_activation", activated, "towers %s, hold %s" % [TeamState.state["towers"], TeamState.state["hold_progress"]])


func _test_air() -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	var imad := Game.player(Characters.Character.IMAD)
	var dropped_id := _pick_one_trash(imad)
	bjorn.respawn(OUTSIDE)
	imad.respawn(OUTSIDE + BESIDE_BJORN)
	var start := float(TeamState.state["air"])
	var drained := await _wait_for(func() -> bool: return float(TeamState.state["air"]) < start - 1.0, STEP_TIMEOUT)
	_check("air_drain", drained, "air stayed at %.1f" % float(TeamState.state["air"]))
	var air := Game.world.get_node("AirSystem") as AirSystem
	air.damage(float(Data.balance("air_max")))
	var respawned := await _wait_for(func() -> bool: return _at_marker(bjorn) and _at_marker(imad), STEP_TIMEOUT)
	_check("knockout_respawn", respawned and TeamState.mount_state() == MountController.SOLO, "bjorn at %s, imad at %s" % [bjorn.global_position, imad.global_position])
	var trash := Game.world.get_node_or_null("Entities/%s" % dropped_id) as Node3D
	var fall_point := OUTSIDE + BESIDE_BJORN
	var ring_ok := trash != null and trash.visible \
		and absf(StationRules.flat_distance(trash.global_position, fall_point) - float(Data.balance("knockout_drop_radius"))) < RESPAWN_TOLERANCE
	var released: bool = not (dropped_id in TeamState.state["picked"]) and (TeamState.state["carried"] as Array).is_empty()
	_check("knockout_trash_drop", dropped_id != "" and ring_ok and released, "id '%s' at %s" % [dropped_id, trash.global_position if trash != null else Vector3.ZERO])


## Bjorn is the bait within roach_bait_range even when Imad is closer; beyond it, the nearest wins.
func _test_roach_bait() -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	var imad := Game.player(Characters.Character.IMAD)
	var roach := Game.world.get_node("cockroach") as Cockroach
	imad.respawn(BAIT_IMAD)
	bjorn.respawn(BAIT_BJORN_NEAR)
	var near_pick := RoachTargets.nearest(roach.global_position)
	bjorn.respawn(BAIT_BJORN_FAR)
	var far_pick := RoachTargets.nearest(roach.global_position)
	_check("roach_prefers_bjorn", near_pick == bjorn and far_pick == imad, "near pick %s, far pick %s" % [near_pick, far_pick])
	bjorn.respawn((Game.world.get_node("Markers/bjorn") as Node3D).global_position)
	imad.respawn((Game.world.get_node("Markers/imad") as Node3D).global_position)


## A roach stunned at the pillar flees home to the south and never enters the Dome; the gate opens.
func _test_roach_flee() -> void:
	var roach := Game.world.get_node("cockroach") as Cockroach
	var dome: Vector3 = Game.world.get_meta("dome", Vector3.ZERO)
	roach.position = STUN_SPOT
	roach._set_state(Cockroach.FLEE)
	var closest := INF
	var left := FLEE_TIMEOUT
	while left > 0.0 and roach.machine.state != Cockroach.GONE:
		closest = minf(closest, StationRules.flat_distance(roach.global_position, dome))
		await get_tree().process_frame
		left -= get_process_delta_time()
	var outside_dome := closest > float(Data.balance("dome_radius"))
	_check("roach_flee_avoids_dome", roach.machine.state == Cockroach.GONE and outside_dome, "state %s, closest to Dome %.1f m" % [roach.machine.state, closest])
	var gate_body: StaticBody3D = null
	for child in Game.world.get_node("Entities/gate_0").get_children():
		if child is StaticBody3D:
			gate_body = child
	await get_tree().physics_frame
	_check("gate_opens", gate_body != null and gate_body.collision_layer == 0, "gate collision layer still set")


func _pick_one_trash(imad: PlayerBase) -> String:
	for node: Node in Game.world.get_node("Entities").get_children():
		if node.get_meta("kind", "") != "trash" or String(node.name) in TeamState.state["picked"]:
			continue
		var trash := node as Node3D
		imad.respawn(trash.global_position + PICKUP_OFFSET)
		TeamState._server_use_tool(trash.global_position, _imad_id)
		return String(node.name)
	return ""


func _at_marker(player: PlayerBase) -> bool:
	var marker := Game.world.get_node("Markers/%s" % player.name) as Node3D
	return player.global_position.distance_to(marker.global_position) < RESPAWN_TOLERANCE


func _place_imad_at(station_id: String) -> void:
	var station := Game.world.get_node("Entities/%s" % station_id) as Node3D
	Game.player(Characters.Character.IMAD).respawn(station.global_position + STATION_OFFSET)


func _wait_for(condition: Callable, timeout: float) -> bool:
	var left := timeout
	while left > 0.0:
		if condition.call():
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return condition.call()


func _check(step: String, ok: bool, reason: String) -> void:
	if ok:
		_pass(step)
	else:
		_fail(step, reason)


func _pass(step: String) -> void:
	_passes += 1
	print("PASS %s" % step)


func _fail(step: String, reason: String) -> void:
	_failures += 1
	print("FAIL %s %s" % [step, reason])
