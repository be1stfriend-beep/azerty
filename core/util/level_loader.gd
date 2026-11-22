class_name LevelLoader
## Builds World > Ground, Entities, Markers from a level JSON.

const GROUND_SIZE := 200.0
const RING_WIDTH := 0.3
const RING_FLATTEN := 0.15
const SUN_ROTATION := Vector3(-50, -30, 0)
const AMBIENT_ENERGY := 0.55
const RING_SEGMENTS := 64


static func load_level(level_name: String, parent: Node) -> Node3D:
	var level := Data.level(level_name)
	var world := Node3D.new()
	world.name = "World"
	parent.add_child(world)
	_add_lighting(world)
	world.add_child(_ground())
	var entities := Node3D.new()
	entities.name = "Entities"
	world.add_child(entities)
	var counters: Dictionary = {}
	for entry: Dictionary in level.get("entities", []):
		var kind: String = entry["kind"]
		var index: int = counters.get(kind, 0)
		counters[kind] = index + 1
		entities.add_child(EntityFactory.spawn(kind, "%s_%d" % [kind, index], entry))
	var markers := Node3D.new()
	markers.name = "Markers"
	world.add_child(markers)
	var marker_data: Dictionary = level.get("markers", {})
	for marker_name: String in marker_data:
		var marker := Marker3D.new()
		marker.name = marker_name
		var pos: Array = marker_data[marker_name]
		marker.position = Vector3(pos[0], pos[1], pos[2])
		markers.add_child(marker)
	if level.has("dome"):
		var center: Array = level["dome"]
		var dome := Vector3(center[0], center[1], center[2])
		world.set_meta("dome", dome)
		world.set_meta("mask_gate", level.get("mask_gate", false))
		var ring := ground_ring(Data.balance("dome_radius"), "bone")
		ring.name = "DomeRing"
		ring.position = dome
		world.add_child(ring)
	return world


static func _ground() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = EntityFactory.WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Style.ground_material()
	body.add_child(visual)
	return body


## A thin flat ring lying on the ground, centred on its parent.
static func ground_ring(radius: float, tint_group: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - RING_WIDTH * 0.5
	mesh.outer_radius = radius + RING_WIDTH * 0.5
	mesh.rings = RING_SEGMENTS
	mesh.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.scale = Vector3(1, RING_FLATTEN, 1)
	ring.set_meta("tint_group", tint_group)
	Style.apply(ring)
	return ring


static func _add_lighting(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.HAZE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.HAZE_SKY
	env.ambient_light_energy = AMBIENT_ENERGY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ROTATION
	sun.light_color = Palette.BONE
	sun.shadow_enabled = false
	world.add_child(sun)
