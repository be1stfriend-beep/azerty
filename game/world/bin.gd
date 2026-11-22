class_name Bin
extends Node3D
## An overflowing bin only Bjorn's kick can open. Its spill trash exists from the start, hidden
## and sealed, with ids derived from the bin's id so every peer agrees on them; the host's
## TeamState.spilled list is what releases it, so both screens spill together.

const GROUP := "kickable"
const BODY_RADIUS := 0.55
const SPILL_HOP := 1.2
const SPILL_SECONDS := 0.35

var _spill: Array[Node3D] = []
var _spilled := false


func _ready() -> void:
	add_to_group(GROUP)
	# Deferred: the Entities parent is still adding its children during level load.
	_spawn_spill.call_deferred()


func is_spilled() -> bool:
	return String(name) in TeamState.state.get("spilled", [])


## The first unspilled bin whose shell is within reach (and in front, when facing is given).
static func find(tree: SceneTree, from: Vector3, reach: float, facing: Vector3 = Vector3.ZERO) -> Bin:
	for node in tree.get_nodes_in_group(GROUP):
		var bin := node as Bin
		if bin == null or bin.is_spilled():
			continue
		var to_bin := bin.global_position - from
		to_bin.y = 0.0
		if to_bin.length() - BODY_RADIUS > reach:
			continue
		if facing == Vector3.ZERO or facing.dot(to_bin.normalized()) >= float(Data.balance("kick_facing_dot")):
			return bin
	return null


## Host: Bjorn's kick landed on a bin.
static func server_kick(tree: SceneTree, from: Vector3, facing: Vector3) -> void:
	var bin := find(tree, from, float(Data.balance("kick_range")), facing)
	if bin != null:
		TeamState.set_values({"spilled": (TeamState.state.get("spilled", []) as Array) + [String(bin.name)]})


func _spawn_spill() -> void:
	var items: Array = (get_meta("params", {}) as Dictionary).get("items", [])
	var radius := float(Data.balance("bin_spill_radius"))
	for i in items.size():
		var angle := TAU * i / items.size()
		var spot := position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var trash := EntityFactory.spawn("trash", "%s_spill_%d" % [name, i], {"item": items[i], "pos": [spot.x, spot.y, spot.z], "rot": rad_to_deg(angle)})
		trash.set_meta("bin", String(name))
		trash.hide()
		get_parent().add_child(trash)
		_spill.append(trash)
	Events.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _spilled or not is_spilled():
		return
	_spilled = true
	var heap := get_node_or_null("Visual/Heap") as Node3D
	if heap != null:
		heap.hide()
	var picked: Array = TeamState.state.get("picked", [])
	for trash in _spill:
		if String(trash.name) in picked:
			continue
		var target := trash.position
		trash.position = position + Vector3.UP * SPILL_HOP
		trash.show()
		trash.create_tween().tween_property(trash, "position", target, SPILL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
