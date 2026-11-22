extends Node3D
## A slab that opens while all of its linked plates are active. Derived from replicated
## TeamState.plates, so it opens and closes on every peer without its own RPC.

const SLIDE_SECONDS := 0.6
const SINK_DEPTH := 2.4

var links: Array = []

var _open := false
var _slab: Node3D
var _body: StaticBody3D
var _closed_y := 0.0
var _tween: Tween


func _ready() -> void:
	links = (get_meta("params", {}) as Dictionary).get("links", [])
	_slab = get_node_or_null("Visual/Slab") as Node3D
	if _slab != null:
		_closed_y = _slab.position.y
	for child in get_node("Visual").get_children():
		if child is StaticBody3D:
			_body = child
	Events.state_changed.connect(_refresh)


func is_open() -> bool:
	if links.is_empty():
		return false
	var plates: Dictionary = TeamState.state.get("plates", {})
	for plate_id: String in links:
		if not plates.get(plate_id, false):
			return false
	return true


func _refresh() -> void:
	var open := is_open()
	if open == _open:
		return
	_open = open
	if _body != null:
		_body.set_deferred("collision_layer", 0 if open else EntityFactory.WORLD_LAYER)
	if _slab == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_slab, "position:y", _closed_y - SINK_DEPTH if open else _closed_y, SLIDE_SECONDS)
