extends Interactable
## Feeds the carried trash into the hopper one piece at a time. The host commits each piece
## through TeamState; every peer plays the same arc, pop, chute block and floating label.

const HOPPER_POINT := Vector3(0, 2.1, 0)
const CHUTE_START := Vector3(0, 0.45, 1.3)
const CHUTE_END := Vector3(0, 0.2, 2.3)
const SOURCE_HEIGHT := 1.0
const ARC_HEIGHT := 1.2
const ARC_SECONDS := 0.25
const PIECE_SCALE := 0.6
const POP_SCALE := Vector3(1.12, 0.88, 1.12)
const POP_SECONDS := 0.08
const BLOCK_SIZE := 0.32
const BLOCK_SECONDS := 0.25
const SHAKE_AMOUNT := 0.05
const SHAKE_SECONDS := 0.45
const LABEL_HEIGHT := 2.8
const LABEL_RISE := 1.2
const LABEL_SECONDS := 1.0
const LABEL_FONT_SIZE := 64
const LABEL_OUTLINE := 12
const LABEL_PIXEL_SIZE := 0.005

var _working := false
var _tick_left := 0.0
var _shake_left := 0.0
var _visual: Node3D


func _ready() -> void:
	_visual = get_node("Visual") as Node3D


func interact(_player: PlayerBase) -> void:
	TeamState.request_recycle(name)


## Host only. Presses while it is already working are ignored; it empties the whole sack anyway.
func server_start() -> void:
	if _working:
		return
	_working = true
	_tick_left = 0.0


func _process(delta: float) -> void:
	_shake(delta)
	if not _working or not multiplayer.is_server():
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = float(Data.balance("recycle_seconds_per_item"))
	var carried: Array = TeamState.state.get("carried", [])
	if carried.is_empty():
		_working = false
		return
	var item_id: String = carried[0]
	TeamState.commit(StationRules.recycle_one(TeamState.state))
	play_item.rpc(item_id)


@rpc("authority", "call_local", "reliable")
func play_item(item_id: String) -> void:
	var item := Data.item(item_id)
	var piece := ProcProps.build(String(item.get("prefab", "")))
	Style.apply(piece)
	piece.top_level = true
	piece.scale = Vector3.ONE * PIECE_SCALE
	add_child(piece)
	var from := _source_point()
	var to := to_global(HOPPER_POINT)
	piece.global_position = from
	_shake_left = SHAKE_SECONDS
	var arc := func(t: float) -> void:
		piece.global_position = from.lerp(to, t) + Vector3.UP * ARC_HEIGHT * 4.0 * t * (1.0 - t)
	var tween := piece.create_tween()
	tween.tween_method(arc, 0.0, 1.0, ARC_SECONDS)
	tween.tween_callback(_produce.bind(String(item.get("material", "")), int(item.get("yield", 0))))
	tween.tween_callback(piece.queue_free)


## The piece leaves from Imad's sack, wherever he is (riding or crawling).
func _source_point() -> Vector3:
	var imad := Game.player(Characters.Character.IMAD)
	if imad != null and imad.rig is CrawlRig:
		return (imad.rig as CrawlRig).sack_point()
	return global_position + Vector3.UP * SOURCE_HEIGHT


func _produce(material: String, amount: int) -> void:
	var pop := _visual.create_tween()
	pop.tween_property(_visual, "scale", POP_SCALE, POP_SECONDS)
	pop.tween_property(_visual, "scale", Vector3.ONE, POP_SECONDS)
	var block := ProcProps.part(self, ProcProps.box(Vector3.ONE * BLOCK_SIZE), CHUTE_START, material)
	Style.apply(block, material)
	var slide := block.create_tween()
	slide.tween_property(block, "position", CHUTE_END, BLOCK_SECONDS)
	slide.tween_callback(func() -> void: Events.material_produced.emit(material, block.global_position))
	slide.tween_callback(block.queue_free)
	_float_label("+%d %s" % [amount, material], Palette.tint(material))


func _float_label(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = LABEL_FONT_SIZE
	label.outline_size = LABEL_OUTLINE
	label.pixel_size = LABEL_PIXEL_SIZE
	label.modulate = color
	label.outline_modulate = Palette.SOOT
	label.position = Vector3.UP * LABEL_HEIGHT
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", LABEL_HEIGHT + LABEL_RISE, LABEL_SECONDS)
	tween.parallel().tween_property(label, "modulate:a", 0.0, LABEL_SECONDS)
	tween.tween_callback(label.queue_free)


func _shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		_visual.position = Vector3.ZERO
	else:
		_visual.position = Vector3(randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT), 0.0, randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT))
