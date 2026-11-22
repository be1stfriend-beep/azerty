class_name InteractionCues
extends Node3D
## Tells the players what to do in the world: a bouncing ring on Imad's grab target and a
## floating prompt above the nearest station. Also owns the current context for the touch button.

const RING_RADIUS := 0.7
const RING_THICKNESS := 0.1
const RING_FLATTEN := 0.25
const RING_BOUNCE_HEIGHT := 0.25
const RING_BOUNCE_SPEED := 7.0
const RING_BASE_HEIGHT := 0.08
const PROMPT_HEIGHT := 2.6
const FULL_PROMPT_HEIGHT := 1.6
const PROMPT_FONT_SIZE := 72
const PROMPT_OUTLINE := 14
const PROMPT_PIXEL_SIZE := 0.005
const STATION_PROMPTS: Dictionary = {"recycler": "prompt_recycler", "bench": "prompt_bench"}

## The latest Interaction.resolve() result for Imad, as seen on this peer.
var context: Dictionary = {}

var _ring: MeshInstance3D
var _prompt: Label3D
var _time := 0.0


func _init() -> void:
	name = "InteractionCues"


func _ready() -> void:
	_ring = _build_ring()
	add_child(_ring)
	_prompt = _build_prompt()
	add_child(_prompt)


func _process(delta: float) -> void:
	_time += delta
	var imad := Game.player(Characters.Character.IMAD) as Imad
	var next := Interaction.resolve(imad)
	var changed: bool = next["label"] != context.get("label") or next["action"] != context.get("action")
	context = next
	if changed:
		Events.context_changed.emit()
	var target := next["target"] as Node3D
	_ring.visible = next["action"] == Interaction.GRAB
	if _ring.visible:
		var bounce := absf(sin(_time * RING_BOUNCE_SPEED)) * RING_BOUNCE_HEIGHT
		_ring.global_position = target.global_position + Vector3.UP * (RING_BASE_HEIGHT + bounce)
	_update_prompt(imad, next)


func _update_prompt(imad: Imad, current: Dictionary) -> void:
	_prompt.visible = false
	var body: Node3D = Game.team_body()
	if imad == null or body == null:
		return
	if current["full"]:
		_show_prompt(Data.hint("prompt_full"), body.global_position + Vector3.UP * FULL_PROMPT_HEIGHT)
		return
	var station := Interaction.nearest_station(body.global_position)
	if station == null or not STATION_PROMPTS.has(station.kind):
		return
	var key: String = STATION_PROMPTS[station.kind]
	if station.kind == "recycler" and (TeamState.state.get("carried", []) as Array).is_empty():
		key = "prompt_recycler_empty"
	_show_prompt(Data.hint(key), station.global_position + Vector3.UP * PROMPT_HEIGHT)


func _show_prompt(text: String, at: Vector3) -> void:
	_prompt.text = text
	_prompt.global_position = at
	_prompt.visible = true


func _build_ring() -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = RING_RADIUS - RING_THICKNESS
	mesh.outer_radius = RING_RADIUS
	mesh.rings = ProcProps.SEGMENTS * 2
	mesh.ring_segments = ProcProps.SPHERE_RINGS
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.scale = Vector3(1, RING_FLATTEN, 1)
	ring.visible = false
	ring.set_meta("tint_group", "imad_goggles")
	Style.apply(ring)
	return ring


func _build_prompt() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = PROMPT_FONT_SIZE
	label.outline_size = PROMPT_OUTLINE
	label.pixel_size = PROMPT_PIXEL_SIZE
	label.modulate = Palette.BONE
	label.outline_modulate = Palette.SOOT
	label.visible = false
	return label
