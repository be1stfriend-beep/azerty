class_name LobbyBackdrop
extends Control
## A calm dusty skyline in flat palette shapes, so the login screen needs no assets.
## Positions are fractions of the screen so the scene fits any landscape aspect.

const SUN_CENTER := Vector2(0.80, 0.24)
const SUN_RADIUS := 0.10
const SUN_ALPHA := 0.55
const DOME_CENTER := Vector2(0.16, 0.86)
const DOME_RADIUS := 0.16
const DOME_ALPHA := 0.45
const DOME_SEGMENTS := 32
const DOME_OUTLINE := 4.0
const FAR_DUNE := Vector3(0.70, 0.05, 2.0)
const NEAR_DUNE := Vector3(0.84, 0.04, 3.5)
const DUNE_STEPS := 24
const JUNK: Array[Rect2] = [
	Rect2(0.42, 0.74, 0.05, 0.09), Rect2(0.47, 0.78, 0.03, 0.05),
	Rect2(0.63, 0.70, 0.02, 0.16), Rect2(0.88, 0.76, 0.06, 0.07),
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.HAZE_SKY)
	draw_circle(size * SUN_CENTER, size.y * SUN_RADIUS, Color(Palette.BONE, SUN_ALPHA))
	_dune(FAR_DUNE, Palette.DUST_GROUND)
	for junk: Rect2 in JUNK:
		draw_rect(Rect2(junk.position * size, junk.size * size), Palette.SOOT)
	_dome()
	_dune(NEAR_DUNE, Palette.RUST)


## shape: x = base height, y = wave height, z = wave count across the screen.
func _dune(shape: Vector3, color: Color) -> void:
	var points := PackedVector2Array()
	for step in DUNE_STEPS + 1:
		var t := float(step) / DUNE_STEPS
		points.append(Vector2(t * size.x, (shape.x + sin(t * TAU * shape.z) * shape.y) * size.y))
	points.append(size)
	points.append(Vector2(0.0, size.y))
	draw_colored_polygon(points, color)


func _dome() -> void:
	var center := size * DOME_CENTER
	var radius := size.y * DOME_RADIUS
	var points := PackedVector2Array()
	for step in DOME_SEGMENTS + 1:
		var angle := PI + PI * float(step) / DOME_SEGMENTS
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(Palette.RESTORED_TEAL, DOME_ALPHA))
	draw_polyline(points, Palette.BONE, DOME_OUTLINE)
