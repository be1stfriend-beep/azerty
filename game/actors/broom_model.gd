class_name BroomModel
extends Node3D
## Imad's broomstick: stowed across his back, swung forward in an overhead arc on every use.

const STOW_POSITION := Vector3(0, 0.45, -0.38)
const STOW_ROTATION := Vector3(0, 0, -40)
const SWING_START := Vector3(-150, 0, 0)
const SWING_END := Vector3(-20, 0, 0)
const SWING_GRIP := Vector3(0, 0.45, 0.2)
const RAISE_SECONDS := 0.1
const STRIKE_SECONDS := 0.12
const RETURN_SECONDS := 0.25
const HANDLE_LENGTH := 1.3

var _tween: Tween


static func build() -> BroomModel:
	var broom := BroomModel.new()
	broom.name = "Broom"
	broom.position = STOW_POSITION
	broom.rotation_degrees = STOW_ROTATION
	ProcProps.part(broom, ProcProps.cyl(0.035, 0.035, HANDLE_LENGTH), Vector3(0, HANDLE_LENGTH * 0.5, 0), "wood")
	ProcProps.part(broom, ProcProps.cyl(0.07, 0.07, 0.08), Vector3(0, HANDLE_LENGTH, 0), "rust")
	# Straw head: a flared cone of bristles so it reads as a broom, not a stick, from afar.
	ProcProps.part(broom, ProcProps.cyl(0.08, 0.2, 0.38), Vector3(0, HANDLE_LENGTH + 0.22, 0), "paper")
	broom.set_meta("tint_group", "wood")
	broom.visible = false
	Style.apply(broom)
	return broom


func swing() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = SWING_GRIP
	rotation_degrees = SWING_START
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees", SWING_START, RAISE_SECONDS)
	_tween.tween_property(self, "rotation_degrees", SWING_END, STRIKE_SECONDS).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "rotation_degrees", STOW_ROTATION, RETURN_SECONDS)
	_tween.parallel().tween_property(self, "position", STOW_POSITION, RETURN_SECONDS)
