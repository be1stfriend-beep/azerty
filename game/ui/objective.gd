class_name Objective
## The one-line goal at the top of the screen, derived only from replicated state so both
## screens always show the same line. The one exception is the bin hint, which only Bjorn
## can act on.

const HUNTING_STATES: Array[String] = [Cockroach.CHASE, Cockroach.WINDUP, Cockroach.CHARGE]
const SLICE_RECIPE := "mask"


static func text() -> String:
	var state := TeamState.state
	if state.get("slice_complete", false):
		return Data.hint("objective_complete")
	if _roach_hunting():
		return Data.hint("objective_flee")
	if _bin_near_own_bjorn():
		return Data.hint("objective_kick_bin")
	if int((state.get("inventory", {}) as Dictionary).get(SLICE_RECIPE, 0)) > 0:
		return Data.hint("objective_outside")
	if StationRules.can_afford(state.get("stash", {}), Data.recipe(SLICE_RECIPE)):
		return Data.hint("objective_craft")
	var carried := (state.get("carried", []) as Array).size()
	if carried >= mini(int(Data.balance("objective_recycle_at")), int(Data.balance("carry_capacity"))):
		return Data.hint("objective_recycle")
	return Data.hint("objective_collect")


static func _bin_near_own_bjorn() -> bool:
	var bjorn := Game.player(Characters.Character.BJORN)
	if Net.own_character() != Characters.Character.BJORN or bjorn == null:
		return false
	return Bin.find(bjorn.get_tree(), bjorn.global_position, float(Data.balance("bin_hint_distance"))) != null


static func _roach_hunting() -> bool:
	if Game.world == null:
		return false
	var roach := Game.world.get_node_or_null("cockroach") as Cockroach
	return roach != null and roach.machine.state in HUNTING_STATES
