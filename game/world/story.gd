class_name Story
extends Node
## Fires each story beat once per match. Every trigger is replicated state, so both peers
## reach the same beats on their own.

const END_DELAY_SECONDS := 6.0

var _seen: Dictionary = {}


func _init(dialogue: DialogueBox) -> void:
	name = "Story"
	dialogue.sequence_finished.connect(_on_sequence_finished)


func _ready() -> void:
	Events.mount_changed.connect(_on_mount_changed)
	Events.tower_activated.connect(func(_index: int) -> void: _beat("tower"))
	Events.boss_state_changed.connect(_on_boss_state_changed)
	_beat.call_deferred("start")


func _on_mount_changed(mount: String) -> void:
	if mount == MountController.MERGED:
		_beat("merge")


func _on_boss_state_changed(state: String) -> void:
	if state != Cockroach.FLEE or _seen.has("boss_done"):
		return
	_beat("boss_done")
	get_tree().create_timer(END_DELAY_SECONDS).timeout.connect(_beat.bind("end"))


func _beat(id: String) -> void:
	if _seen.has(id):
		return
	_seen[id] = true
	Events.dialogue_requested.emit(id)


func _on_sequence_finished(id: String) -> void:
	if id == "end":
		Game.show_end_card()
