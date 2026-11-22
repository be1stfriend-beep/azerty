class_name DomeArrow
extends Control
## Sits on the screen edge and points toward the Dome whenever the local player is outside it.

const EDGE_INSET := 80.0
const ARROW_LENGTH := 56.0
const ARROW_WIDTH := 44.0
const OUTLINE_WIDTH := 5.0

var _tip := Vector2.ZERO
var _dir := Vector2.UP


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var own := Game.player(Net.own_character())
	var camera := get_viewport().get_camera_3d()
	visible = own != null and camera != null and _is_outside(own)
	if not visible:
		return
	var half := size * 0.5
	var dome := RoachTargets.dome_center()
	var towards := camera.unproject_position(dome) - half
	if camera.is_position_behind(dome):
		towards = -towards
	if towards.length() > 0.01:
		_dir = towards.normalized()
	var reach_x := (half.x - EDGE_INSET) / maxf(absf(_dir.x), 0.001)
	var reach_y := (half.y - EDGE_INSET) / maxf(absf(_dir.y), 0.001)
	_tip = half + _dir * minf(reach_x, reach_y)
	queue_redraw()


func _draw() -> void:
	var side := _dir.orthogonal() * ARROW_WIDTH * 0.5
	var base := _tip - _dir * ARROW_LENGTH
	var points := PackedVector2Array([_tip, base + side, base - side, _tip])
	draw_colored_polygon(points.slice(0, 3), Palette.RESTORED_TEAL)
	draw_polyline(points, Palette.SOOT, OUTLINE_WIDTH)


func _is_outside(own: PlayerBase) -> bool:
	return StationRules.flat_distance(own.global_position, RoachTargets.dome_center()) > float(Data.balance("dome_radius"))
