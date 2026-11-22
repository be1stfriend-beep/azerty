class_name RoachTargets
## Who the cockroach may chase or hit. Host only.


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
static func valid() -> Array[PlayerBase]:
	var air := Game.world.get_node_or_null("AirSystem") as AirSystem
	var result: Array[PlayerBase] = []
	for player in players():
		if player is Imad and (TeamState.mount_state() != MountController.SOLO or is_on_perch(player)):
			continue
		if air != null and air.is_safe(player.global_position):
			continue
		result.append(player)
	return result


static func nearest(from: Vector3) -> PlayerBase:
	var best: PlayerBase = null
	var best_distance := INF
	for player in valid():
		var distance := StationRules.flat_distance(player.global_position, from)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best
