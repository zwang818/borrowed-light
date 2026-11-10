extends Node2D

const PARTS = preload("res://assets/sprites/environment/abdomen/welding_station_parts.png")
const SOCKET := Vector2(13, -15)
const BRASS := Color("bb874a")
const DARK := Color("211e1b")

var shoulder := Vector2.ZERO
var tip := Vector2.ZERO
var closure := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func pose(contact: Vector2, grip: float) -> void:
	tip = to_local(contact)
	closure = grip
	queue_redraw()

func _draw() -> void:
	var elbow := shoulder.lerp(tip, 0.48) + Vector2(0, -48)
	var wrist := tip + Vector2(16, -6)
	var cell := PARTS.get_size() * 0.5
	draw_texture_rect_region(PARTS, Rect2(shoulder - Vector2(36, 34), Vector2(76, 67)), Rect2(Vector2.ZERO, cell))
	_draw_link(shoulder, elbow)
	_draw_link(elbow, wrist)
	draw_line(wrist, tip + Vector2(7, 0), DARK, 9)
	draw_line(wrist, tip + Vector2(7, 0), BRASS, 5)
	var gap := lerpf(15, 5, closure)
	for side in [-1.0, 1.0]:
		var jaw := PackedVector2Array([tip + Vector2(8, 0), tip + Vector2(5, side * gap), tip + Vector2(-3, side * gap)])
		draw_polyline(jaw, DARK, 6)
		draw_polyline(jaw, BRASS, 3)
	if closure > 0.95:
		draw_rect(Rect2(tip - Vector2(1, 2), Vector2(3, 4)), Color("f7ba52"))

func _draw_link(from: Vector2, to: Vector2) -> void:
	var cell := PARTS.get_size() * 0.5
	var pivot := Vector2(0.1625, 0.6281) * cell
	var axis := Vector2(0.6031, 0.0188) * cell
	var factor := from.distance_to(to) / axis.length()
	draw_set_transform(from, (to - from).angle() - axis.angle(), Vector2(factor, minf(factor, 0.14)))
	draw_texture_rect_region(PARTS, Rect2(-pivot, cell), Rect2(Vector2(cell.x, 0), cell))
	draw_set_transform(Vector2.ZERO)
	draw_circle(from, 8, DARK)
	draw_arc(from, 5, -PI, PI, 12, BRASS, 2)
