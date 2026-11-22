extends Node

const TOWER_SLOTS := 4
const WORLD_SHADER_PATH := "res://shaders/world_style.gdshader"
const GROUND_SHADER_PATH := "res://shaders/ground.gdshader"
const CHARACTER_RIM := 0.9
const VIGNETTE_SHADER_PATH := "res://shaders/vignette.gdshader"

const MODEL_BLACK_LUMA := 0.03

var _materials: Dictionary = {}
var _model_materials: Dictionary = {}
var _ground: ShaderMaterial
var _tweens: Dictionary = {}


## The tower_N / restore_N shader globals are declared in project.godot [shader_globals]:
## adding them again at runtime errors, and listing them is editor-only.
func material(tint_group: String) -> ShaderMaterial:
	if not _materials.has(tint_group):
		var mat := ShaderMaterial.new()
		mat.shader = load(WORLD_SHADER_PATH)
		mat.set_shader_parameter("tint", Palette.tint(tint_group))
		if tint_group in Palette.CHARACTER_GROUPS:
			mat.set_shader_parameter("character", 1.0)
			mat.set_shader_parameter("rim_strength", CHARACTER_RIM)
		_materials[tint_group] = mat
	return _materials[tint_group]


func ground_material() -> ShaderMaterial:
	if _ground == null:
		_ground = ShaderMaterial.new()
		_ground.shader = load(GROUND_SHADER_PATH)
		_ground.set_shader_parameter("dust_color", Palette.DUST_GROUND)
		_ground.set_shader_parameter("grass_color", Palette.RESTORED_GRASS)
	return _ground


## Meshes without their own tint_group inherit the nearest ancestor's.
func apply(node: Node, inherited_group: String = "concrete") -> void:
	var group: String = node.get_meta("tint_group", inherited_group)
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material(group)
	for child in node.get_children():
		apply(child, group)


## Imported models keep their own colours, textures and vertex colours, but still go through
## the world shader so they dust and restore with everything else. Surfaces painted near-black
## (some garbage exports lose their diffuse colour) take the prefab's tint group instead.
func apply_model(node: Node, tint_group: String) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance := node as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			instance.set_surface_override_material(surface, _model_material(instance.mesh, surface, tint_group))
	for child in node.get_children():
		apply_model(child, tint_group)


func _model_material(mesh: Mesh, surface: int, tint_group: String) -> ShaderMaterial:
	var source := mesh.surface_get_material(surface) as BaseMaterial3D
	var color := Palette.tint(tint_group)
	var texture: Texture2D = null
	if source != null:
		texture = source.albedo_texture
		if source.albedo_color.get_luminance() > MODEL_BLACK_LUMA or texture != null:
			color = source.albedo_color
	var vertex_colors: bool = mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR != 0
	var key := "%s|%s|%s" % [color.to_html(), texture.get_rid() if texture != null else "", vertex_colors]
	if not _model_materials.has(key):
		var mat := material(tint_group).duplicate() as ShaderMaterial
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("albedo_tex", texture)
		mat.set_shader_parameter("use_vertex_color", 1.0 if vertex_colors else 0.0)
		_model_materials[key] = mat
	return _model_materials[key]


func set_tower(index: int, position: Vector3, radius: float) -> void:
	RenderingServer.global_shader_parameter_set("tower_%d" % index, Vector4(position.x, position.y, position.z, radius))


## A new match starts with every tower dusty again.
func reset_towers() -> void:
	for index: int in _tweens:
		var tween: Tween = _tweens[index]
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for i in TOWER_SLOTS:
		set_tower(i, Vector3.ZERO, 0.0)
		_set_restore(0.0, i)


## The single vignette and warm haze over the 3D view.
func add_post_layer(parent: Node, layer_index: int) -> void:
	var layer := CanvasLayer.new()
	layer.name = "PostLayer"
	layer.layer = layer_index
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(VIGNETTE_SHADER_PATH)
	mat.set_shader_parameter("haze_color", Palette.HAZE_SKY)
	rect.material = mat
	layer.add_child(rect)
	parent.add_child(layer)


## Local only: callers run this on every peer.
func restore(index: int, seconds: float = 3.0) -> void:
	var previous: Tween = _tweens.get(index)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := create_tween()
	tween.tween_method(_set_restore.bind(index), 0.0, 1.0, seconds)
	_tweens[index] = tween


func _set_restore(value: float, index: int) -> void:
	RenderingServer.global_shader_parameter_set("restore_%d" % index, value)
