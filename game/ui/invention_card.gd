class_name InventionCard
extends CenterContainer
## "INVENTED: ..." on both screens for a moment, with the invention spinning in a tiny 3D view
## and a short chime synthesised in code (no audio files).

const SECONDS := 2.5
const VIEW_SIZE := Vector2i(280, 280)
const SPIN_SPEED := 2.5
const CAMERA_POSITION := Vector3(0, 0.05, 0.65)
const LIGHT_ROTATION := Vector3(-30, -30, 0)
const AMBIENT_ENERGY := 0.6
const SEPARATION := 16
const CHIME_RATE := 22050
## A rising arpeggio, in Hz.
const CHIME_NOTES: Array[float] = [784.0, 1046.5, 1568.0]
const CHIME_NOTE_SECONDS := 0.16
const CHIME_DECAY := 9.0
const CHIME_VOLUME := 0.35
const SAMPLE_MAX := 32767.0

var _label: Label
var _view: SubViewportContainer
var _model: Node3D
var _tween: Tween
var _chime: AudioStreamPlayer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.build()
	visible = false
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SEPARATION)
	panel.add_child(box)
	_view = _build_view()
	box.add_child(_view)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Palette.IMAD_GOGGLES)
	box.add_child(_label)
	_chime = AudioStreamPlayer.new()
	_chime.stream = _build_chime()
	add_child(_chime)
	Events.item_crafted.connect(show_invention)


func _process(delta: float) -> void:
	if visible:
		_model.rotate_y(SPIN_SPEED * delta)


func show_invention(recipe_id: String) -> void:
	_label.text = Data.hint("invented") % Data.recipe(recipe_id).get("invention_name", recipe_id)
	_view.visible = recipe_id == Objective.SLICE_RECIPE
	visible = true
	_chime.play()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SECONDS)
	_tween.tween_callback(hide)


func _build_view() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = VIEW_SIZE
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = VIEW_SIZE
	container.add_child(viewport)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.BONE
	env.ambient_light_energy = AMBIENT_ENERGY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = LIGHT_ROTATION
	light.light_color = Palette.BONE
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.position = CAMERA_POSITION
	viewport.add_child(camera)
	_model = MaskModel.build()
	viewport.add_child(_model)
	return container


static func _build_chime() -> AudioStreamWAV:
	var per_note := int(CHIME_RATE * CHIME_NOTE_SECONDS)
	var data := PackedByteArray()
	data.resize(per_note * CHIME_NOTES.size() * 2)
	var index := 0
	for frequency: float in CHIME_NOTES:
		for n in per_note:
			var t := float(n) / CHIME_RATE
			var value := sin(TAU * frequency * t) * exp(-CHIME_DECAY * t) * CHIME_VOLUME
			data.encode_s16(index * 2, int(value * SAMPLE_MAX))
			index += 1
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = CHIME_RATE
	wav.stereo = false
	wav.data = data
	return wav
