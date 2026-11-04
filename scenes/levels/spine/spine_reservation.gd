@tool
extends Node2D
## A placement reservation only: no trigger, timer, damage, protocol or progress logic.
@export var size := Vector2(128, 64):
	set(value):
		size = value.max(Vector2.ONE)
		queue_redraw()
@export var kind := "safe":
	set(value):
		kind = value
		queue_redraw()

func _draw() -> void:
	var color: Color = {"safe": Color("7fa89a"), "electric_floor": Color("d1aa68"), "protocol": Color("6f9fca"), "blueprint": Color("b7a5cd"), "checkpoint": Color("8bbda6")}.get(kind, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(color, 0.15))
	draw_rect(Rect2(Vector2.ZERO, size), Color(color, 0.7), false, 2)
	if kind == "electric_floor":
		for x in range(8, int(size.x), 16):
			draw_line(Vector2(x, 8), Vector2(x, size.y - 8), color, 2)
