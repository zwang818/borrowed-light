@tool
extends Marker2D
## A places data only. C creates real objects. No pickup/door/enemy behavior here.
@export var object_id := "":
	set(value):
		object_id = value
		queue_redraw()
@export_enum("spawn", "weapon", "sentry", "cleaner", "log", "terminal", "door", "light", "exit") var object_type: String = "spawn":
	set(value):
		object_type = value
		queue_redraw()
@export var room_id := ""
@export var content_id := ""
@export var linked_ids: Array[String] = []
@export var target_room_id := ""
@export var target_entry_id := ""
@export var footprint := Vector2(24, 24):
	set(value):
		footprint = value
		queue_redraw()
@export var show_guide := true:
	set(value):
		show_guide = value
		queue_redraw()

func _draw() -> void:
	if not show_guide:
		return
	var color := Color("d2ad6b")
	if object_type == "spawn" or object_type == "exit":
		color = Color("7fc7bb")
	elif object_type == "sentry" or object_type == "cleaner":
		color = Color("d28378")
	elif object_type == "log":
		color = Color("b5a2cb")
	draw_rect(Rect2(-footprint * 0.5, footprint), Color(color, 0.14))
	draw_rect(Rect2(-footprint * 0.5, footprint), color, false, 1.5)
	draw_line(Vector2(-7, 0), Vector2(7, 0), color, 2)
	draw_line(Vector2(0, -7), Vector2(0, 7), color, 2)
	if object_type == "light":
		draw_arc(Vector2.ZERO, 18, 0, TAU, 32, color, 1.5)
