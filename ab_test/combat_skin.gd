extends Node2D
## Presentation only: combat shapes and timings remain in B's original scenes.
@export_enum("gun", "cleaner") var kind := "gun"

func _draw() -> void:
	if kind == "gun":
		draw_style_box(_box(Color("263e4c"), Color("98aaa8")), Rect2(-17, -5, 15, 10))
		draw_rect(Rect2(-7, -3, 7, 6), Color("4e6c7a"))
		draw_rect(Rect2(-12, -3, 3, 6), Color("84efff"))
		draw_rect(Rect2(-1, -4, 2, 8), Color("d9ffff"))
		draw_line(Vector2(-16, 6), Vector2(-12, 6), Color("c38e44"), 2)
	else:
		# Low armored chassis, two treads, amber sensor, paired sweeping claws.
		draw_circle(Vector2(0, 2), 16, Color(0, 0, 0, 0.25))
		for y in [-12, 8]:
			draw_style_box(_box(Color("172d3a"), Color("718995")), Rect2(-12, y, 23, 5))
			for x in [-9, -4, 1, 6]:
				draw_line(Vector2(x, y+1), Vector2(x, y+4), Color("435c6b"), 1)
		draw_style_box(_box(Color("435c6b"), Color("b1c1c0")), Rect2(-12, -8, 23, 16))
		draw_rect(Rect2(-8, -5, 5, 10), Color("263e4c"))
		draw_line(Vector2(-6, -4), Vector2(-6, 4), Color("c38e44"), 2)
		draw_rect(Rect2(5, -5, 5, 10), Color("172d3a"))
		draw_circle(Vector2(8, 0), 2.5, Color("ff9955"))
		for side in [-1, 1]:
			draw_polyline(PackedVector2Array([Vector2(8, side*8), Vector2(16, side*10), Vector2(20, side*5)]), Color("b1c1c0"), 2, true)

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	return box
