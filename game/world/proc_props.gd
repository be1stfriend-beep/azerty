class_name ProcProps
## Builds every prefab id from primitives. Low segment counts keep the chunky look and the phone budget.

const SEGMENTS := 12
const SPHERE_RINGS := 6


static func build(prefab_id: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("tint_group", Data.prefab(prefab_id).get("tint_group", "concrete"))
	match prefab_id:
		"trash_bottle":
			part(root, cyl(0.18, 0.18, 0.6), Vector3(0, 0.3, 0))
			part(root, cyl(0.08, 0.15, 0.15), Vector3(0, 0.675, 0))
			part(root, cyl(0.09, 0.09, 0.05), Vector3(0, 0.775, 0), "bone")
		"trash_can":
			part(root, cyl(0.2, 0.2, 0.5), Vector3(0, 0.25, 0))
			part(root, cyl(0.205, 0.205, 0.16), Vector3(0, 0.25, 0), "danger")
		"trash_cardboard":
			part(root, box(Vector3(0.9, 0.9, 0.9)), Vector3(0, 0.45, 0))
			part(root, box(Vector3(0.92, 0.03, 0.16)), Vector3(0, 0.9, 0), "bone")
			part(root, box(Vector3(0.9, 0.03, 0.4)), Vector3(0, 0.95, 0.5), "", Vector3(-35, 0, 0))
		"trash_apple_core":
			part(root, sphere(0.2), Vector3(0, 0.12, 0), "", Vector3.ZERO, Vector3(1, 0.6, 1))
			part(root, cyl(0.1, 0.1, 0.3), Vector3(0, 0.27, 0), "bone")
			part(root, sphere(0.2), Vector3(0, 0.4, 0), "", Vector3.ZERO, Vector3(1, 0.6, 1))
			part(root, cyl(0.025, 0.025, 0.12), Vector3(0, 0.55, 0), "soot")
		"trash_plank":
			part(root, box(Vector3(1.6, 0.12, 0.3)), Vector3(0, 0.06, 0))
			part(root, box(Vector3(0.4, 0.1, 0.12)), Vector3(0.9, 0.05, 0.12), "", Vector3(0, 25, 0))
		"prop_barrel":
			part(root, cyl(0.45, 0.45, 1.1), Vector3(0, 0.55, 0))
			for y: float in [0.3, 0.8]:
				part(root, cyl(0.47, 0.47, 0.08), Vector3(0, y, 0), "soot")
			_cylinder_collision(root, 0.45, 1.1)
		"prop_crate":
			part(root, box(Vector3.ONE), Vector3(0, 0.5, 0))
			part(root, box(Vector3(1.02, 0.14, 1.02)), Vector3(0, 0.5, 0), "rust")
			_box_collision(root, Vector3.ONE)
		"prop_tyre":
			for y: float in [0.125, 0.375]:
				part(root, torus(0.25, 0.5), Vector3(0, y, 0))
			_cylinder_collision(root, 0.5, 0.5)
		"prop_pipe":
			part(root, cyl(0.4, 0.4, 3.0), Vector3(0, 0.4, 0), "", Vector3(0, 0, 90))
			for x: float in [-1.45, 1.45]:
				part(root, cyl(0.5, 0.5, 0.15), Vector3(x, 0.4, 0), "soot", Vector3(0, 0, 90))
			_box_collision(root, Vector3(3.0, 0.8, 0.8))
		"prop_scrap_tower":
			var top := 0.0
			var groups: Array[String] = ["rust", "soot", "concrete", "rust", "soot"]
			for i in groups.size():
				var side := 3.0 - i * 0.4
				var height := 2.2 - i * 0.2
				part(root, box(Vector3(side, height, side)), Vector3(0.15 * (i % 2), top + height * 0.5, 0), groups[i], Vector3(0, i * 17.0, 0))
				top += height
			_box_collision(root, Vector3(3.0, top, 3.0))
		"pillar":
			for i in 5:
				part(root, box(Vector3(2, 1, 2)), Vector3(0, 0.5 + i, 0), "concrete" if i % 2 == 0 else "bone")
			_box_collision(root, Vector3(2, 5, 2))
		"perch":
			for row in 2:
				for x: float in [-0.75, 0.75]:
					part(root, box(Vector3(1.45, 1.22, 1.5)), Vector3(x, 0.625 + row * 1.25, 0))
					part(root, box(Vector3(1.47, 0.12, 1.52)), Vector3(x, 0.625 + row * 1.25, 0), "rust")
			_box_collision(root, Vector3(3, 2.5, 1.5))
		"gate":
			for x: float in [-2.7, 2.7]:
				part(root, box(Vector3(0.6, 4, 0.6)), Vector3(x, 2, 0))
			var slab := part(root, box(Vector3(4.8, 3, 0.3)), Vector3(0, 1.5, 0), "concrete")
			slab.name = "Slab"
			_box_collision(root, Vector3(6, 4, 0.6))
		"recycler":
			part(root, box(Vector3(2, 1.6, 1.6)), Vector3(0, 0.8, 0))
			var hopper := CylinderMesh.new()
			hopper.top_radius = 0.95
			hopper.bottom_radius = 0.55
			hopper.height = 0.7
			hopper.radial_segments = 4
			part(root, hopper, Vector3(0, 1.95, 0), "bone", Vector3(0, 45, 0))
			part(root, box(Vector3(0.6, 0.25, 1.0)), Vector3(0, 0.45, 1.0), "soot", Vector3(-20, 0, 0))
			_box_collision(root, Vector3(2, 2.3, 1.6))
		"bench":
			part(root, box(Vector3(2.4, 0.15, 1.2)), Vector3(0, 0.95, 0))
			for x: float in [-1.05, 1.05]:
				for z: float in [-0.45, 0.45]:
					part(root, box(Vector3(0.15, 0.9, 0.15)), Vector3(x, 0.45, z), "soot")
			part(root, box(Vector3(0.35, 0.3, 0.4)), Vector3(0.85, 1.17, 0), "bone")
			part(root, box(Vector3(0.1, 0.25, 0.4)), Vector3(0.6, 1.15, 0), "rust")
			_box_collision(root, Vector3(2.4, 1.1, 1.2))
		"tower":
			part(root, cyl(0.7, 1.2, 6.0), Vector3(0, 3, 0))
			part(root, box(Vector3(1.8, 0.4, 1.8)), Vector3(0, 6.2, 0), "rust")
			var fan := Node3D.new()
			fan.name = "Fan"
			fan.position = Vector3(0, 7.2, 0.4)
			root.add_child(fan)
			part(fan, cyl(0.3, 0.3, 0.3), Vector3.ZERO, "teal", Vector3(90, 0, 0))
			for i in 3:
				part(fan, box(Vector3(0.35, 1.4, 0.08)), Vector3(0, 0.7, 0).rotated(Vector3.BACK, i * TAU / 3.0), "bone", Vector3(0, 0, rad_to_deg(i * TAU / 3.0)))
			_cylinder_collision(root, 1.2, 6.0)
		_:
			push_error("ProcProps: no builder for '%s'" % prefab_id)
			part(root, box(Vector3.ONE), Vector3(0, 0.5, 0))
	return root


static func part(parent: Node3D, mesh: Mesh, pos: Vector3, group: String = "", rot_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rot_deg
	part.scale = scale
	if group != "":
		part.set_meta("tint_group", group)
	parent.add_child(part)
	return part


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = SEGMENTS
	mesh.rings = 1
	return mesh


static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = SEGMENTS
	mesh.rings = SPHERE_RINGS
	return mesh


static func torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = SEGMENTS
	mesh.ring_segments = 8
	return mesh


static func _box_collision(root: Node3D, size: Vector3) -> void:
	root.set_meta("collision", {"shape": "box", "size": size, "center": Vector3(0, size.y * 0.5, 0)})


static func _cylinder_collision(root: Node3D, radius: float, height: float) -> void:
	root.set_meta("collision", {"shape": "cylinder", "radius": radius, "height": height, "center": Vector3(0, height * 0.5, 0)})
