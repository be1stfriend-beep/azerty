class_name ProcPuzzleProps
## Primitive builders for the co-op puzzle pieces. Sizes that matter for play (ledge height,
## plate and vent footprints) come from data so validate_data.py can check them.

const FENCE_LENGTH := 5.0
## Taller than Bjorn's solo jump, so the cages are only entered through their doors.
const FENCE_HEIGHT := 2.2
const FENCE_THICKNESS := 0.3
const FENCE_BARS := 6
const PLATE_THICKNESS := 0.08
const DUST_RADIUS := 0.9
const DUST_HEIGHT := 4.0
const WARN_THICKNESS := 0.15


static func build_into(root: Node3D, prefab_id: String) -> bool:
	match prefab_id:
		"plate":
			var disc := ProcProps.part(root, ProcProps.cyl(_plate_radius(), _plate_radius(), PLATE_THICKNESS), Vector3(0, PLATE_THICKNESS * 0.5, 0))
			disc.name = "Disc"
			ProcProps.part(root, ProcProps.box(Vector3(0.5, PLATE_THICKNESS * 2.0, 0.5)), Vector3(0, PLATE_THICKNESS, 0), "bone")
		"door":
			for x: float in [-FENCE_LENGTH * 0.5, FENCE_LENGTH * 0.5]:
				ProcProps.part(root, ProcProps.box(Vector3(0.4, FENCE_HEIGHT + 0.3, 0.4)), Vector3(x, (FENCE_HEIGHT + 0.3) * 0.5, 0), "rust")
			var slab := ProcProps.part(root, ProcProps.box(Vector3(FENCE_LENGTH - 0.4, FENCE_HEIGHT, FENCE_THICKNESS)), Vector3(0, FENCE_HEIGHT * 0.5, 0), "danger")
			slab.name = "Slab"
			ProcProps.box_collision(root, Vector3(FENCE_LENGTH, FENCE_HEIGHT, FENCE_THICKNESS))
		"prop_fence":
			for y: float in [0.15, FENCE_HEIGHT - 0.1]:
				ProcProps.part(root, ProcProps.box(Vector3(FENCE_LENGTH, 0.2, FENCE_THICKNESS)), Vector3(0, y, 0))
			for i in FENCE_BARS + 1:
				var x := -FENCE_LENGTH * 0.5 + i * FENCE_LENGTH / FENCE_BARS
				ProcProps.part(root, ProcProps.box(Vector3(0.12, FENCE_HEIGHT, 0.12)), Vector3(x, FENCE_HEIGHT * 0.5, 0), "soot")
			ProcProps.box_collision(root, Vector3(FENCE_LENGTH, FENCE_HEIGHT, FENCE_THICKNESS))
		"prop_ledge":
			var height := float(Data.prefab(prefab_id).get("height", 1.0))
			ProcProps.part(root, ProcProps.box(Vector3(2.5, height, 2.5)), Vector3(0, height * 0.5, 0))
			ProcProps.part(root, ProcProps.box(Vector3(2.55, 0.12, 2.55)), Vector3(0, height * 0.5, 0), "rust")
			ProcProps.box_collision(root, Vector3(2.5, height, 2.5))
		"vent":
			var radius := float(Data.balance("vent_radius"))
			ProcProps.part(root, ProcProps.cyl(radius, radius, 0.04), Vector3(0, 0.02, 0))
			ProcProps.part(root, ProcProps.box(Vector3(1.2, 0.25, 1.2)), Vector3(0, 0.12, 0), "rust")
			var dust := Node3D.new()
			dust.name = "Dust"
			root.add_child(dust)
			ProcProps.part(dust, ProcProps.cyl(DUST_RADIUS * 1.3, DUST_RADIUS, DUST_HEIGHT), Vector3(0, DUST_HEIGHT * 0.5, 0), "concrete")
			var warn := ProcProps.part(root, ProcProps.torus(radius - WARN_THICKNESS, radius), Vector3(0, 0.06, 0), "roach_eye_hot")
			warn.name = "Warn"
		_:
			return false
	return true


static func _plate_radius() -> float:
	return float(Data.balance("plate_radius"))
