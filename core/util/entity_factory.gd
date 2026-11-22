class_name EntityFactory
## Turns a level entry into a styled node. Models are optional; procedural props are the fallback.

const WORLD_LAYER := 1


static func spawn(kind: String, id: String, params: Dictionary) -> Node3D:
	var prefab_id := prefab_for(kind, params)
	var prefab := Data.prefab(prefab_id)
	var node := _from_model(prefab)
	if node == null:
		node = ProcProps.build(prefab_id)
	else:
		node.set_meta("tint_group", prefab.get("tint_group", "concrete"))
		_copy_fallback_collision(node, prefab_id)
	Style.apply(node)
	if node.has_meta("collision"):
		node.add_child(_collider(node.get_meta("collision")))
	var rule := Data.entity(kind)
	if rule.has("script"):
		node = _wrap_station(node, kind, rule, params)
	node.name = id
	node.set_meta("kind", kind)
	node.set_meta("prefab", prefab_id)
	if params.has("item"):
		node.set_meta("item", params["item"])
	var pos: Array = params.get("pos", [0, 0, 0])
	node.position = Vector3(pos[0], pos[1], pos[2])
	node.rotation_degrees.y = params.get("rot", 0.0)
	return node


static func prefab_for(kind: String, params: Dictionary) -> String:
	var rule := Data.entity(kind)
	if rule.has("prefab"):
		return rule["prefab"]
	match rule.get("prefab_from", ""):
		"item":
			return Data.item(params.get("item", "")).get("prefab", "")
		"prefab":
			return params.get("prefab", "")
	push_error("EntityFactory: no prefab rule for kind '%s'" % kind)
	return ""


## Scripted kinds get their behaviour script as the root; the visual becomes its child.
## The level entry is kept as "params" metadata for per-instance settings (links, phases).
static func _wrap_station(visual: Node3D, kind: String, rule: Dictionary, params: Dictionary) -> Node3D:
	var script := load(rule["script"]) as GDScript
	var station := script.new() as Node3D
	if station == null:
		push_error("EntityFactory: %s is not a Node3D script" % rule["script"])
		return visual
	if station is Interactable:
		(station as Interactable).kind = kind
		(station as Interactable).interact_range = rule.get("range", 0.0)
	station.set_meta("params", params)
	visual.name = "Visual"
	station.add_child(visual)
	return station


static func _from_model(prefab: Dictionary) -> Node3D:
	var path: Variant = prefab.get("model")
	if not (path is String) or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	_strip_collision(model)
	model.scale = Vector3.ONE * float(prefab.get("scale", 1.0))
	# Packs disagree on pivots: put every model's bottom centre on the entity origin, like the procedural props.
	var bounds := _mesh_bounds(model, model.transform)
	model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var root := Node3D.new()
	root.add_child(model)
	return root


## Gameplay collision always comes from the procedural fallback's metadata, so a model swap never changes how a prop blocks.
static func _copy_fallback_collision(node: Node3D, prefab_id: String) -> void:
	var fallback := ProcProps.build(prefab_id)
	if fallback.has_meta("collision"):
		node.set_meta("collision", fallback.get_meta("collision"))
	fallback.free()


static func _strip_collision(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionObject3D:
			node.remove_child(child)
			child.free()
		else:
			_strip_collision(child)


static func _mesh_bounds(node: Node, xf: Transform3D) -> AABB:
	var bounds := AABB()
	var found := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		bounds = xf * (node as MeshInstance3D).mesh.get_aabb()
		found = true
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_bounds := _mesh_bounds(child, xf * (child as Node3D).transform)
		if child_bounds.size == Vector3.ZERO:
			continue
		bounds = child_bounds if not found else bounds.merge(child_bounds)
		found = true
	return bounds


static func _collider(info: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.position = info.get("center", Vector3.ZERO)
	if info["shape"] == "box":
		var box := BoxShape3D.new()
		box.size = info["size"]
		shape.shape = box
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = info["radius"]
		cylinder.height = info["height"]
		shape.shape = cylinder
	body.add_child(shape)
	return body
