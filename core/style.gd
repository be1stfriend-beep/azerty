extends Node

const TOWER_SLOTS := 4
const WORLD_SHADER_PATH := "res://shaders/world_style.gdshader"
const GROUND_SHADER_PATH := "res://shaders/ground.gdshader"

var _materials: Dictionary = {}
var _ground: ShaderMaterial
var _tweens: Dictionary = {}


# Shaders are loaded lazily: compiling one before its globals exist is an error.
func _ready() -> void:
	var existing := RenderingServer.global_shader_parameter_get_list()
	for i in TOWER_SLOTS:
		if not existing.has(StringName("tower_%d" % i)):
			RenderingServer.global_shader_parameter_add("tower_%d" % i, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
		if not existing.has(StringName("restore_%d" % i)):
			RenderingServer.global_shader_parameter_add("restore_%d" % i, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


func material(tint_group: String) -> ShaderMaterial:
	if not _materials.has(tint_group):
		var mat := ShaderMaterial.new()
		mat.shader = load(WORLD_SHADER_PATH)
		mat.set_shader_parameter("tint", Palette.tint(tint_group))
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


func set_tower(index: int, position: Vector3, radius: float) -> void:
	RenderingServer.global_shader_parameter_set("tower_%d" % index, Vector4(position.x, position.y, position.z, radius))


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
