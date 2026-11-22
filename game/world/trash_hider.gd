class_name TrashHider
extends Node
## Hides picked trash on every peer with a small pop, driven only by TeamState.picked.

const POP_SCALE := 1.25
const POP_UP_SECONDS := 0.08
const POP_DOWN_SECONDS := 0.15

var _hidden: Dictionary = {}


func _ready() -> void:
	Events.state_changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	var entities := get_parent().get_node_or_null("Entities")
	if entities == null:
		return
	for id: String in TeamState.state.get("picked", []):
		if _hidden.has(id):
			continue
		_hidden[id] = true
		var trash := entities.get_node_or_null(id) as Node3D
		if trash != null:
			_pop(trash)
		Events.trash_picked.emit(id)
	_restore_dropped(entities)


## Trash that left `picked` was dropped on a knockout: it reappears where the host put it.
func _restore_dropped(entities: Node) -> void:
	var picked: Array = TeamState.state.get("picked", [])
	var drops: Dictionary = TeamState.state.get("drops", {})
	for id: String in _hidden.keys():
		if id in picked:
			continue
		_hidden.erase(id)
		var trash := entities.get_node_or_null(id) as Node3D
		if trash == null:
			continue
		trash.position = drops.get(id, trash.position)
		trash.scale = Vector3.ONE
		trash.show()


func _pop(trash: Node3D) -> void:
	var tween := trash.create_tween()
	tween.tween_property(trash, "scale", Vector3.ONE * POP_SCALE, POP_UP_SECONDS)
	tween.tween_property(trash, "scale", Vector3.ZERO, POP_DOWN_SECONDS)
	tween.tween_callback(trash.hide)
