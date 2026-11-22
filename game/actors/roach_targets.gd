class_name RoachTargets
## Who the cockroach may chase or hit. Host only.
## Bjorn is the bait: he is preferred whenever he is a valid target and close enough.


static func is_on_perch(imad: PlayerBase) -> bool:
	return TeamState.state.get("on_perch", false) and TeamState.mount_state() == MountController.SOLO \
		and imad != null and imad.global_position.y > MountController.PERCH_HEIGHT * 0.5


static func players() -> Array[PlayerBase]:
	var result: Array[PlayerBase] = []
	for character: int in [Characters.Character.BJORN, Characters.Character.IMAD]:
		var player := Game.player(character)
		if player != null:
			result.append(player)
	return result


## Not inside the Dome or an active tower, not on the perch, and the rider is not a separate target.
## While Imad holds a tower activation he is left alone, and Bjorn only counts near that tower.
static func valid() -> Array[PlayerBase]:
	var air := Game.world.get_node_or_null("AirSystem") as AirSystem
	var holding: String = TeamState.state.get("holding", "")
	var held_tower: Node3D = null
	if holding != "":
		held_tower = Game.world.get_node_or_null("Entities/%s" % holding) as Node3D
	var guard_range := float(Data.balance("roach_tower_guard_range"))
	var result: Array[PlayerBase] = []
	for player in players():
		if player is Imad and (TeamState.mount_state() != MountController.SOLO or is_on_perch(player) or held_tower != null):
			continue
		if air != null and air.is_safe(player.global_position):
			continue
		if held_tower != null and StationRules.flat_distance(player.global_position, held_tower.global_position) > guard_range:
			continue
		result.append(player)
	return result


static func dome_center() -> Vector3:
	return Game.world.get_meta("dome", Vector3.ZERO)


## The closest point to `pos` that keeps a body of `margin` radius outside the Dome ring.
static func outside_dome(pos: Vector3, margin: float) -> Vector3:
	var center := dome_center()
	var offset := Vector3(pos.x - center.x, 0.0, pos.z - center.z)
	var edge := float(Data.balance("dome_radius")) + margin
	if offset.length() >= edge or offset.length() < 0.01:
		return pos
	var clamped := center + offset.normalized() * edge
	return Vector3(clamped.x, pos.y, clamped.z)


static func nearest(from: Vector3) -> PlayerBase:
	var targets := valid()
	for player in targets:
		if player is Bjorn and StationRules.flat_distance(player.global_position, from) <= float(Data.balance("roach_bait_range")):
			return player
	var best: PlayerBase = null
	var best_distance := INF
	for player in targets:
		var distance := StationRules.flat_distance(player.global_position, from)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best
