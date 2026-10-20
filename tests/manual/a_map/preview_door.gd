extends Node2D
## Geometry-only test blocker. P toggles this from anywhere; no terminal logic.
const Metrics = preload("res://scenes/levels/graybox/graybox_metrics.gd")
@export var size := Vector2(Metrics.WALL_THICKNESS, Metrics.DOOR_WIDTH):
	set(value):
		size = value.max(Vector2.ONE)
		if is_node_ready():
			_update_geometry()
var is_open := false

func _ready() -> void:
	_update_geometry()

func _update_geometry() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	$Body/Collision.shape = shape
	var shadow := OccluderPolygon2D.new()
	var half := size * 0.5
	shadow.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	$Occluder.occluder = shadow
	queue_redraw()

func set_open(value: bool) -> void:
	is_open = value
	$Body/Collision.set_deferred("disabled", value)
	$Occluder.visible = not value
	queue_redraw()

func _draw() -> void:
	var color := Color("c5a369")
	var half := size * 0.5
	if is_open:
		draw_rect(Rect2(-half, Vector2(size.x, 5)), color)
		draw_rect(Rect2(Vector2(-half.x, half.y - 5), Vector2(size.x, 5)), color)
	else:
		draw_rect(Rect2(-half, size), Color("716246"))
		draw_rect(Rect2(-half, size), color, false, 2)
		draw_line(Vector2(-10, 0), Vector2(10, 0), color, 2)
