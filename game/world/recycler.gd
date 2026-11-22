extends Interactable
## Turns everything carried into stash materials. The host decides; the pop plays on all peers.

const POP_SCALE := Vector3(1.12, 0.88, 1.12)
const POP_SECONDS := 0.12
const CHUTE_START := Vector3(0, 0.45, 1.3)
const CHUTE_END := Vector3(0, 0.1, 2.4)
const CHUNK_SIZE := 0.22
const CHUNK_COUNT := 3
const CHUNK_SECONDS := 0.35
const CHUNK_GAP := 0.1


func interact(_player: PlayerBase) -> void:
	TeamState.request_recycle(name)


@rpc("authority", "call_local", "reliable")
func play_effect() -> void:
	var visual := get_node("Visual") as Node3D
	var tween := create_tween()
	tween.tween_property(visual, "scale", POP_SCALE, POP_SECONDS)
	tween.tween_property(visual, "scale", Vector3.ONE, POP_SECONDS)
	for i in CHUNK_COUNT:
		_chunk(i * CHUNK_GAP)


func _chunk(delay: float) -> void:
	var chunk := ProcProps.part(self, ProcProps.box(Vector3.ONE * CHUNK_SIZE), CHUTE_START, "teal")
	Style.apply(chunk, "teal")
	var tween := chunk.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(chunk, "position", CHUTE_END, CHUNK_SECONDS)
	tween.parallel().tween_property(chunk, "scale", Vector3.ZERO, CHUNK_SECONDS)
	tween.tween_callback(chunk.queue_free)
