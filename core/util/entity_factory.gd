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
	var node := scene.instantiate() as Node3D
	if node != null:
		node.scale = Vector3.ONE * float(prefab.get("scale", 1.0))
	return node


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
