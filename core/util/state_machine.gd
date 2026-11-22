class_name StateMachine
extends RefCounted
## Named states with time-in-state. Owners run the per-state logic themselves.

signal changed(state: String)

var state: String
var elapsed := 0.0


func _init(initial: String) -> void:
	state = initial


func change(next: String) -> void:
	if next == state:
		return
	state = next
	elapsed = 0.0
	changed.emit(next)


func tick(delta: float) -> void:
	elapsed += delta
