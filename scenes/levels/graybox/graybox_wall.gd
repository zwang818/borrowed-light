@tool
extends Node2D
## Edit Size in the Inspector. Collision and shadow always use the same rectangle.
@export var size := Vector2(32, 128):
	set(value):
		size = value.max(Vector2.ONE)
		if is_node_ready():
			_update_geometry()
@export var wall_color := Color("59646b"):
	set(value):
		wall_color = value
		queue_redraw()

func _ready() -> void:
	_update_geometry()

func _update_geometry() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	$Body/Collision.shape = shape
	$Body/Collision.position = size * 0.5
	var shadow := OccluderPolygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	$Occluder.occluder = shadow
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), wall_color)
	draw_rect(Rect2(Vector2.ZERO, size), wall_color.lightened(0.2), false, 1.5)
	draw_line(Vector2(2, size.y - 3), Vector2(size.x - 2, size.y - 3), Color(0.04, 0.06, 0.07, 0.55), 4)
