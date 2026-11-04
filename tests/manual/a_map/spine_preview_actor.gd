extends "res://tests/manual/a_map/preview_actor.gd"
## Same circle collider and speed as level one. Body stands above its foot contact point.
func _draw() -> void:
	draw_set_transform(Vector2(3, 6), 0, Vector2(1.0, 0.48))
	draw_circle(Vector2.ZERO, 14, Color(0.02, 0.03, 0.04, 0.55))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-6, -1), Vector2(-6, -9), Color("24313a"), 5)
	draw_line(Vector2(6, -1), Vector2(6, -9), Color("24313a"), 5)
	draw_rect(Rect2(-10, -24, 20, 16), Color("a7babc"))
	draw_rect(Rect2(-10, -24, 20, 16), Color("263a43"), false, 2)
	draw_rect(Rect2(-8, -32, 16, 12), Color("d2dbd9"))
	draw_rect(Rect2(-8, -32, 16, 12), Color("263a43"), false, 2)
	draw_rect(Rect2(-5, -29, 10, 5), Color("e4c985"))
	draw_line(Vector2(-12, -18), Vector2(-13, -9), Color("7f959c"), 4)
	draw_line(Vector2(12, -18), Vector2(13, -9), Color("7f959c"), 4)
	draw_line(Vector2(-5, 1), Vector2(5, 1), Color("eff4e9"), 2)
