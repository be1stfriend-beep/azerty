class_name AutotestSlice
extends Autotest
## --autotest-slice: one offline host plays the slice loop for both characters through the
## host-side request handlers: Dome trash, recycle, Mask, barrier, outside trash, hunt, home.

## Just past the Dome ring on the south side, where the way out is.
const GATE_PROBE := Vector3(0, 0, 16)
## Outside trash nearer than the hunt trigger distance, so only the pickups can start the hunt.
const OUTSIDE_PICK_MAX := 26.0
const HUNT_TIMEOUT := 3.0
const RETURN_TIMEOUT := 30.0
## Where Bjorn stands to kick a bin: just outside its shell, facing it.
const BIN_KICK_OFFSET := Vector3(0, 0, 1.5)


func _run() -> void:
	Game.start_local_match()
	await get_tree().process_frame
	_bjorn_id = Net.peer_for_character(Characters.Character.BJORN)
	_imad_id = Net.peer_for_character(Characters.Character.IMAD)
	print("autotest-slice: fake peer ids bjorn=%d imad=%d" % [_bjorn_id, _imad_id])
	_kick_bin()
	await _collect_dome_trash()
	await _recycle_all()
	_check_barrier("barrier_holds_without_mask", true)
	_craft_mask()
	_check_barrier("barrier_lifts_with_mask", false)
	await _collect_outside_trash()
	await _return_to_dome()
	print("autotest-slice: %d PASS, %d FAIL" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Only Bjorn's kick, facing the bin, may spill it; the spill must then be grabbable trash.
func _kick_bin() -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	var bin := Game.world.get_node("Entities/bin_0") as Bin
	var spill := Game.world.get_node("Entities/bin_0_spill_0")
	var sealed := not StationRules.is_loose(spill, TeamState.state)
	bjorn.respawn(bin.global_position + BIN_KICK_OFFSET)
	bjorn.rotation.y = atan2(-BIN_KICK_OFFSET.x, -BIN_KICK_OFFSET.z)
	bjorn.server_kick(_imad_id)
	var refused := not bin.is_spilled()
	bjorn.server_kick(_bjorn_id)
	_check("kick_bin", sealed and refused and bin.is_spilled() and StationRules.is_loose(spill, TeamState.state), "sealed %s, refused imad %s, spilled %s" % [sealed, refused, TeamState.state["spilled"]])
	bjorn.respawn((Game.world.get_node("Markers/bjorn") as Node3D).global_position)


## Real pickups inside the Dome until the carried load can pay for the Mask once recycled.
func _collect_dome_trash() -> void:
	var imad := Game.player(Characters.Character.IMAD)
	for trash in _free_trash(0.0, float(Data.balance("dome_radius"))):
		if (TeamState.state["carried"] as Array).size() >= int(Data.balance("carry_capacity")):
			break
		imad.respawn(trash.global_position + PICKUP_OFFSET)
		TeamState._server_use_tool(trash.global_position, _imad_id)
	await get_tree().process_frame
	var carried := (TeamState.state["carried"] as Array).size()
	_check("grab_dome_trash", carried == int(Data.balance("carry_capacity")), "carried %d" % carried)


func _recycle_all() -> void:
	_place_imad_at("recycler_0")
	TeamState._server_recycle("recycler_0", _imad_id)
	var emptied := await _wait_for(func() -> bool: return (TeamState.state["carried"] as Array).is_empty(), STEP_TIMEOUT * 2.0)
	var affordable := StationRules.can_afford(TeamState.state["stash"], Data.recipe(Objective.SLICE_RECIPE))
	_check("recycle", emptied and affordable, "carried %d, stash %s" % [(TeamState.state["carried"] as Array).size(), TeamState.state["stash"]])


func _craft_mask() -> void:
	_place_imad_at("bench_0")
	TeamState._server_craft(Objective.SLICE_RECIPE, _imad_id)
	_check("craft_mask", DomeGate.has_mask(), "inventory %s, stash %s" % [TeamState.state["inventory"], TeamState.state["stash"]])


## Puts Bjorn just outside the ring and runs the same clamp his controller runs after moving.
func _check_barrier(step: String, expect_held: bool) -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	bjorn.respawn(GATE_PROBE)
	DomeGate.hold_inside(bjorn)
	var inside := StationRules.flat_distance(bjorn.global_position, RoachTargets.dome_center()) <= float(Data.balance("dome_radius"))
	_check(step, inside == expect_held, "bjorn at %s" % bjorn.global_position)
	bjorn.respawn((Game.world.get_node("Markers/bjorn") as Node3D).global_position)


## Both walk out together; picking slice_outside_trash_needed pieces must start the hunt.
func _collect_outside_trash() -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	var imad := Game.player(Characters.Character.IMAD)
	var needed := int(Data.balance("slice_outside_trash_needed"))
	var picked := 0
	for trash in _free_trash(float(Data.balance("dome_radius")), OUTSIDE_PICK_MAX):
		if picked == needed:
			break
		var before := (TeamState.state["picked"] as Array).size()
		imad.respawn(trash.global_position + PICKUP_OFFSET)
		bjorn.respawn(imad.global_position + BESIDE_BJORN)
		TeamState._server_use_tool(trash.global_position, _imad_id)
		picked += (TeamState.state["picked"] as Array).size() - before
	_check("grab_outside_trash", picked == needed, "picked %d of %d outside" % [picked, needed])
	var hunting := await _wait_for(func() -> bool: return TeamState.state.get("hunt", "") == SliceHunt.HUNTING, HUNT_TIMEOUT)
	var roach := Game.world.get_node("cockroach") as Cockroach
	var behind := StationRules.flat_distance(roach.global_position, RoachTargets.dome_center()) > StationRules.flat_distance(imad.global_position, RoachTargets.dome_center())
	_check("hunt_triggers", hunting and roach.visible and roach.machine.state == Cockroach.CHASE and behind, "hunt '%s', roach %s at %s" % [TeamState.state.get("hunt", ""), roach.machine.state, roach.global_position])


## Back inside, the roach must stop at the ring, give up and walk back to guard its lair. The
## card waits until the team has crafted a Filter and lit the tower with it.
func _return_to_dome() -> void:
	_respawn_home()
	var roach := Game.world.get_node("cockroach") as Cockroach
	var closest := INF
	var left := RETURN_TIMEOUT
	while left > 0.0 and roach.machine.state != Cockroach.GUARD:
		closest = minf(closest, StationRules.flat_distance(roach.global_position, RoachTargets.dome_center()))
		await get_tree().process_frame
		left -= get_process_delta_time()
	var kept_out := closest > float(Data.balance("dome_radius"))
	_check("roach_guards_lair", roach.machine.state == Cockroach.GUARD and roach.visible and kept_out, "roach %s, closest to Dome %.1f m" % [roach.machine.state, closest])
	await _wait_for(func() -> bool: return TeamState.state.get("hunt", "") == SliceHunt.HUNT_DONE, STEP_TIMEOUT)
	_check("slice_waits_for_tower", not TeamState.state.get("slice_complete", false), "completed before the tower")
	var filter := Data.recipe(Objective.TOWER_RECIPE)
	var imad := Game.player(Characters.Character.IMAD)
	await _empty_bag()
	for trash in _free_trash(float(Data.balance("dome_radius")), OUTSIDE_PICK_MAX * 3.0):
		if StationRules.can_afford(TeamState.state["stash"], filter):
			break
		imad.respawn(trash.global_position + PICKUP_OFFSET)
		TeamState._server_use_tool(trash.global_position, _imad_id)
		await get_tree().process_frame
		if (TeamState.state["carried"] as Array).size() >= int(Data.balance("carry_capacity")):
			await _empty_bag()
	await _empty_bag()
	_place_imad_at("bench_0")
	TeamState._server_craft(Objective.TOWER_RECIPE, _imad_id)
	_check("craft_filter", int((TeamState.state["inventory"] as Dictionary).get(Objective.TOWER_RECIPE, 0)) > 0, "stash %s" % TeamState.state["stash"])
	_place_imad_at("tower_0")
	TeamState._server_hold("tower_0", true, _imad_id)
	var lit := await _wait_for(SliceHunt.tower_lit, float(Data.balance("tower_hold_seconds")) + STEP_TIMEOUT)
	_check("tower_lit", lit, "towers %s, hold %s" % [TeamState.state.get("towers", []), TeamState.state.get("hold_progress", 0.0)])
	var done := await _wait_for(func() -> bool: return TeamState.state.get("slice_complete", false), float(Data.balance("slice_end_delay")) + STEP_TIMEOUT)
	var hunt := Game.world.get_node("SliceHunt") as SliceHunt
	_check("slice_complete", done and hunt._card != null, "hunt '%s', complete %s" % [TeamState.state.get("hunt", ""), TeamState.state.get("slice_complete", false)])


func _empty_bag() -> void:
	_place_imad_at("recycler_0")
	TeamState._server_recycle("recycler_0", _imad_id)
	await _wait_for(func() -> bool: return (TeamState.state["carried"] as Array).is_empty(), STEP_TIMEOUT * 2.0)


func _respawn_home() -> void:
	for player in RoachTargets.players():
		player.respawn((Game.world.get_node("Markers/%s" % player.name) as Node3D).global_position)


## Unpicked trash whose flat distance from the Dome centre lies in (min_distance, max_distance].
func _free_trash(min_distance: float, max_distance: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in Game.world.get_node("Entities").get_children():
		if not StationRules.is_loose(node, TeamState.state):
			continue
		var distance := StationRules.flat_distance((node as Node3D).global_position, RoachTargets.dome_center())
		if distance > min_distance and distance <= max_distance:
			result.append(node as Node3D)
	return result
