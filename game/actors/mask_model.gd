class_name MaskModel
## The Breathe-Easy 3000 from primitives: a face plate, two filter cans, a grille and a strap.
## Built at head scale; the face looks along +Z like the characters.


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Mask"
	root.set_meta("tint_group", "mask")
	ProcProps.part(root, ProcProps.sphere(0.16), Vector3.ZERO, "", Vector3.ZERO, Vector3(1.2, 0.85, 0.55))
	for side: float in [-1.0, 1.0]:
		ProcProps.part(root, ProcProps.cyl(0.07, 0.07, 0.1), Vector3(0.14 * side, -0.04, 0.06), "char_white", Vector3(90, 25 * side, 0))
	ProcProps.part(root, ProcProps.box(Vector3(0.12, 0.05, 0.04)), Vector3(0, -0.03, 0.09), "char_dark")
	ProcProps.part(root, ProcProps.torus(0.2, 0.23), Vector3(0, 0.02, -0.17), "char_dark")
	Style.apply(root)
	return root
