extends Node2D
## C owns IDs and availability; D can replace the small presentation marker.
var interaction_id: StringName
var available := true
var completed := false
var nearby := false
var focused := false:
	set(value):
		if focused == value:
			return
		focused = value
		queue_redraw()

func set_status(is_nearby: bool, is_available: bool, is_completed: bool) -> void:
	if nearby == is_nearby and available == is_available and completed == is_completed:
		return
	nearby = is_nearby
	available = is_available
	completed = is_completed
	queue_redraw()

func _ready() -> void:
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	# The marker stays visible; proximity only enables the focused E prompt.
	var tint := Color("b5d6ca") if completed else (Color("f0ce8a") if available else Color("82979a"))
	var r := 10.0 if focused else 7.0
	draw_rect(Rect2(-r, -r, r * 2, r * 2), Color("16282e"))
	draw_rect(Rect2(-r, -r, r * 2, r * 2), tint, false, 1)
	if completed:
		draw_polyline(PackedVector2Array([Vector2(-4, 0), Vector2(-1, 3), Vector2(4, -3)]), tint, 1)
	elif focused:
		# Pixel E key, using geometry so it remains legible at world scale.
		draw_line(Vector2(-3, -4), Vector2(-3, 4), tint, 1)
		for y in [-4, 0, 4]:
			draw_line(Vector2(-3, y), Vector2(3, y), tint, 1)
	else:
		draw_circle(Vector2.ZERO, 2, tint)
