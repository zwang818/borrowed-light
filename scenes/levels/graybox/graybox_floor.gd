@tool
extends Node2D
const Metrics = preload("res://scenes/levels/graybox/graybox_metrics.gd")
@export var size := Vector2(320, 320):
	set(value):
		size = value
		queue_redraw()
@export var floor_color := Color("222e35"):
	set(value):
		floor_color = value
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), floor_color)
	for x in range(0, int(size.x) + 1, int(Metrics.UNIT)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.65, 0.75, 0.8, 0.07))
	for y in range(0, int(size.y) + 1, int(Metrics.UNIT)):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.65, 0.75, 0.8, 0.07))
