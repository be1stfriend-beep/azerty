class_name AutotestFull
extends Autotest
## --autotest-full: one offline host plays the whole game for both characters through the
## host-side request handlers, from the first pickup to the end card.

const ROACH_TIMEOUT := 15.0
const END_TIMEOUT := 30.0
## South of the perch at (5,0,36): within its collect range, outside its collision box.
const PERCH_SIDE := Vector3(5, 0, 37.4)
## North of the pillar at (0,0,36), so the roach charging from its nest in the south hits it.
const LURE_SPOT := Vector3(0, 0, 31)

var _controller: MountController


func _run() -> void:
	Game.start_local_match()
	await get_tree().process_frame
	_bjorn_id = Net.peer_for_character(Characters.Character.BJORN)
	_imad_id = Net.peer_for_character(Characters.Character.IMAD)
	_controller = Game.world.get_node("MountController") as MountController
	await _test_watchdog()
	_collect_and_recycle()
	_craft("filter")
	await _test_tower()
	_craft("broomstick")
	TeamState._server_tool_next(_imad_id)
	_check("equip_broomstick", TeamState.state["current_tool"] == "broomstick", "tool %s" % TeamState.state["current_tool"])
	await _mount_and_perch()
	await _roach_fight()
	await _wait_end_card()
	print("autotest-full: %d PASS, %d FAIL" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## A MOUNTING state whose timer never started must still end in MERGED, then dismount normally.
func _test_watchdog() -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	Game.player(Characters.Character.IMAD).respawn(bjorn.global_position + BESIDE_BJORN)
	var fires := _controller.watchdog_fires
	TeamState.set_values({"mount": MountController.MOUNTING})
	var merged := await _wait_for(func() -> bool: return TeamState.mount_state() == MountController.MERGED, STEP_TIMEOUT)
	_check("watchdog_unsticks_mount", merged and _controller.watchdog_fires == fires + 1, "mount %s, fires %d" % [TeamState.mount_state(), _controller.watchdog_fires])
	_controller._server_dismount(_bjorn_id)
	var solo := await _wait_for(func() -> bool: return TeamState.mount_state() == MountController.SOLO, STEP_TIMEOUT)
	_check("dismount_after_watchdog", solo, "mount %s" % TeamState.mount_state())


## Real pickups and recycling until both inventions are affordable; full loads go to the Recycler.
func _collect_and_recycle() -> void:
	var imad := Game.player(Characters.Character.IMAD)
	var picked := 0
	for node: Node in Game.world.get_node("Entities").get_children():
		if _affordable():
			break
		if node.get_meta("kind", "") != "trash" or String(node.name) in TeamState.state["picked"]:
			continue
		var trash := node as Node3D
		imad.respawn(trash.global_position + PICKUP_OFFSET)
		var before := (TeamState.state["carried"] as Array).size()
		TeamState._server_use_tool(trash.global_position, _imad_id)
		var carried := (TeamState.state["carried"] as Array).size()
		picked += carried - before
		if carried >= int(Data.balance("carry_capacity")):
			_recycle()
	_check("collect", picked > 0, "nothing picked")
	_recycle()
	_check("recycle", _affordable(), "stash %s cannot pay for filter and broomstick" % TeamState.state["stash"])


func _recycle() -> void:
	_place_imad_at("recycler_0")
	TeamState._server_recycle("recycler_0", _imad_id)


func _affordable() -> bool:
	var needed: Dictionary = {}
	for recipe_id: String in ["filter", "broomstick"]:
		var cost: Dictionary = Data.recipe(recipe_id)["cost"]
		for material: String in cost:
			needed[material] = int(needed.get(material, 0)) + int(cost[material])
	return StationRules.can_afford(TeamState.state["stash"], {"cost": needed})


func _craft(recipe_id: String) -> void:
	_place_imad_at("bench_0")
	TeamState._server_craft(recipe_id, _imad_id)
	var crafted: bool = recipe_id in TeamState.state["tools"] or int((TeamState.state["inventory"] as Dictionary).get(recipe_id, 0)) > 0
	_check("craft_%s" % recipe_id, crafted, "stash %s" % TeamState.state["stash"])


func _mount_and_perch() -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	var imad := Game.player(Characters.Character.IMAD)
	bjorn.respawn((Game.world.get_node("Markers/bjorn") as Node3D).global_position)
	imad.respawn(bjorn.global_position + BESIDE_BJORN)
	_controller._server_mount(_imad_id)
	var merged := await _wait_for(func() -> bool: return TeamState.mount_state() == MountController.MERGED, STEP_TIMEOUT)
	_check("mount", merged, "mount %s" % TeamState.mount_state())
	bjorn.respawn(PERCH_SIDE)
	await get_tree().physics_frame
	_controller._server_dismount(_bjorn_id)
	var perched := await _wait_for(func() -> bool: return RoachTargets.is_on_perch(imad), STEP_TIMEOUT)
	_check("reach_perch", perched, "mount %s, imad at %s" % [TeamState.mount_state(), imad.global_position])


func _roach_fight() -> void:
	var roach := Game.world.get_node("cockroach") as Cockroach
	var imad := Game.player(Characters.Character.IMAD)
	Game.player(Characters.Character.BJORN).respawn(LURE_SPOT)
	var stunned := await _wait_for(func() -> bool: return roach.machine.state == Cockroach.STUNNED, ROACH_TIMEOUT)
	_check("roach_charges_pillar", stunned, "roach %s at %s" % [roach.machine.state, roach.global_position])
	await _kick(roach)
	var reach := float(Data.balance("tongs_reach")) + float(Data.balance("broom_radius"))
	var swings := ceili(float(roach.hp) / float(Data.balance("broom_damage")))
	for i in swings:
		var to_roach := roach.global_position - imad.global_position
		to_roach.y = 0.0
		TeamState._server_use_tool(imad.global_position + to_roach.limit_length(reach), _imad_id)
	_check("broom_hits_until_flee", roach.machine.state == Cockroach.FLEE and roach.hp == 0, "roach %s, hp %d after %d swings" % [roach.machine.state, roach.hp, swings])
	var gone := await _wait_for(func() -> bool: return roach.machine.state == Cockroach.GONE, ROACH_TIMEOUT)
	await get_tree().physics_frame
	_check("gate_opens", gone and _gate_open(), "roach %s" % roach.machine.state)


## Bjorn stands beside the stunned roach facing it; one kick takes the stunned amount off.
func _kick(roach: Cockroach) -> void:
	var bjorn := Game.player(Characters.Character.BJORN) as Bjorn
	var side := Vector3.RIGHT * (Cockroach.BODY_RADIUS + float(Data.balance("kick_range")) * 0.5)
	bjorn.respawn(roach.global_position + side)
	bjorn.rotation.y = atan2(-side.x, -side.z)
	await get_tree().physics_frame
	var before := roach.hp
	bjorn.server_kick(_bjorn_id)
	var expected := before - int(Data.balance("kick_damage_stunned"))
	_check("kick_hit", roach.hp == expected, "hp %d, expected %d" % [roach.hp, expected])


func _gate_open() -> bool:
	for child in Game.world.get_node("Entities/gate_0").get_children():
		if child is StaticBody3D:
			return (child as StaticBody3D).collision_layer == 0
	return false


## Dialogue lines are skipped as they appear; the story's own delay before the end still runs.
func _wait_end_card() -> void:
	var shown := await _wait_for(_skip_line_until_end_card, END_TIMEOUT)
	_check("end_card", shown, "no end card after %.0f s" % END_TIMEOUT)


func _skip_line_until_end_card() -> bool:
	if Game.world != null:
		for child in Game.world.get_children():
			var dialogue := child as DialogueBox
			if dialogue != null and not dialogue._queue.is_empty():
				dialogue._advance()
	return Game._overlay != null
