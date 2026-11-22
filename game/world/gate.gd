class_name Gate
## Opens the north gate on the local peer: the slab slides into the ground and stops blocking.

const SINK_DEPTH := 3.0
const SINK_SECONDS := 1.5


static func open(world: Node) -> void:
	if world == null:
		return
	var gate := world.get_node_or_null("Entities/gate_0") as Node3D
	if gate == null:
		return
	var slab := gate.get_node_or_null("Slab") as Node3D
	if slab != null:
		slab.create_tween().tween_property(slab, "position:y", slab.position.y - SINK_DEPTH, SINK_SECONDS)
	for child in gate.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).set_deferred("collision_layer", 0)
	Game.show_message("The roach fled. The gate is open.")
