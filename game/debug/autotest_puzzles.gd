class_name AutotestPuzzles
## Plate, door and vent checks for the autotest. Positions match data/levels/main.json.

const STEP_TIMEOUT := 3.0
## Settle time for checks that assert something does NOT happen.
const HOLD_SECONDS := 0.5
## Ground beside the puzzle A ledge, and just outside the closed cage door.
const BESIDE_LEDGE := Vector3(17, 0, 29.5)
const OUTSIDE_CAGE_DOOR := Vector3(22.4, 0, 20)


static func run(test: Autotest) -> void:
	var bjorn := Game.player(Characters.Character.BJORN)
	var imad := Game.player(Characters.Character.IMAD)
	var door_a := _node("door_0")
	var plate_a := _node("plate_0")

	imad.respawn(OUTSIDE_CAGE_DOOR)
	var carried_before := (TeamState.state["carried"] as Array).size()
	TeamState._server_use_tool(_node("trash_17").global_position, Net.peer_for_character(Characters.Character.IMAD))
	var carried_after := (TeamState.state["carried"] as Array).size()
	test._check("tongs_blocked_by_closed_door", carried_after == carried_before, "picked through the door (%d -> %d)" % [carried_before, carried_after])

	bjorn.respawn(BESIDE_LEDGE)
	imad.respawn(plate_a.global_position * Vector3(1, 0, 1))
	await test.get_tree().create_timer(HOLD_SECONDS).timeout
	test._check("plate_ignores_ground_level", not plate_a.call("is_active"), "plate on the ledge counted a player on the ground")

	bjorn.respawn(plate_a.global_position)
	var opened := await test._wait_for(func() -> bool: return door_a.call("is_open") and _door_body(door_a).collision_layer == 0, STEP_TIMEOUT)
	test._check("plate_opens_door", opened, "door_0 open=%s" % door_a.call("is_open"))

	bjorn.respawn(BESIDE_LEDGE)
	var closed := await test._wait_for(func() -> bool: return not door_a.call("is_open") and _door_body(door_a).collision_layer != 0, STEP_TIMEOUT)
	test._check("door_closes_when_plate_released", closed, "door_0 stayed open")

	bjorn.respawn(_node("plate_1").global_position)
	var vents_off := await test._wait_for(func() -> bool: return TeamState.state.get("vents_off", false), STEP_TIMEOUT)
	test._check("plate_turns_vents_off", vents_off and _node("door_1").call("is_open"), "vents_off=%s" % TeamState.state.get("vents_off"))
	bjorn.respawn((Game.world.get_node("Markers/bjorn") as Node3D).global_position)


static func _node(id: String) -> Node3D:
	return Game.world.get_node("Entities/%s" % id) as Node3D


static func _door_body(door: Node3D) -> StaticBody3D:
	for child in door.get_node("Visual").get_children():
		if child is StaticBody3D:
			return child
	return null
