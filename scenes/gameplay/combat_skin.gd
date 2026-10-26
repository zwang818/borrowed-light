extends Node2D
## Presentation copied from AB; no combat or audio behavior.
@export_enum("gun", "cleaner") var kind := "gun"

func _draw() -> void:
	if kind == "gun":
		# Layered casing, recessed energy cell and compact muzzle; faces +X.
		draw_style_box(_box(Color("152630"), Color("243c48")), Rect2(-19, -5, 18, 12))
		draw_colored_polygon(PackedVector2Array([Vector2(-19,-4), Vector2(-15,-7), Vector2(-6,-7), Vector2(-2,-3), Vector2(-3,4), Vector2(-16,4), Vector2(-19,2)]), Color("8babb4"))
		draw_style_box(_box(Color("294554"), Color("bfd2cf")), Rect2(-16, -4, 10, 8))
		draw_rect(Rect2(-14, -2, 6, 4), Color("102d39"))
		for x in [-13, -11, -9]:
			draw_line(Vector2(x,-1.5), Vector2(x,1.5), Color("72ebf5"), 1)
		draw_style_box(_box(Color("476572"), Color("a5bfbe")), Rect2(-6, -3, 6, 6))
		draw_rect(Rect2(-1, -2, 2, 4), Color("caffff"))
		draw_line(Vector2(-15,-5), Vector2(-8,-5), Color("e1e5cc"), 1)
		draw_line(Vector2(-17,5), Vector2(-14,5), Color("d3a65b"), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(-11,4), Vector2(-7,4), Vector2(-9,9), Vector2(-12,8)]), Color("20323b"))
		draw_circle(Vector2(-17,0), 0.8, Color("d3a65b"))
	else:
		_draw_cleaner()

func _draw_cleaner() -> void:
	# Compact maintenance chassis. Front is +X, matching the existing attack zone.
	draw_circle(Vector2(0, 2), 15, Color(0.02, 0.04, 0.05, 0.28))
	for side in [-1, 1]:
		var tread := Rect2(-10, side * 10 - 3, 19, 6)
		var rubber := _box(Color("172932"), Color("48606a"))
		rubber.set_corner_radius_all(3)
		draw_style_box(rubber, tread)
		for x in [-7, -3, 1, 5]:
			draw_line(Vector2(x, side * 10 - 1.5), Vector2(x, side * 10 + 1.5), Color("769091"), 1)
		# Short articulated arm and a round industrial brush, rather than a claw.
		draw_line(Vector2(6, side * 7), Vector2(13, side * 10), Color("20363e"), 4, true)
		draw_line(Vector2(6, side * 7), Vector2(13, side * 10), Color("a2b6ac"), 2, true)
		var brush := Vector2(14, side * 10)
		draw_circle(brush, 4.5, Color("273c42"))
		for spoke in range(8):
			var direction := Vector2.from_angle(spoke * TAU / 8)
			draw_line(brush + direction * 2, brush + direction * 4.5, Color("9b9a77"), 1, true)
		draw_circle(brush, 2, Color("e1b85f"))
	draw_circle(Vector2.ZERO, 12.5, Color("20363f"))
	draw_circle(Vector2(-1, -0.5), 11.5, Color("859d9c"))
	draw_circle(Vector2(-2, -1), 9.8, Color("c5cbb0"))
	draw_arc(Vector2(-2, -1), 9.8, PI * 0.9, PI * 1.6, 16, Color("ecedd2"), 1.2, true)
	# Recessed rear vents and asymmetric service panel distinguish the silhouette.
	var panel := _box(Color("546c70"), Color("92a7a0"))
	panel.set_corner_radius_all(2)
	draw_style_box(panel, Rect2(-9, -5, 6, 10))
	for y in [-3, 0, 3]:
		draw_line(Vector2(-7.5,y), Vector2(-4.5,y), Color("243e47"), 1)
	draw_style_box(_box(Color("263e49"), Color("edf0cc")), Rect2(1, -5.5, 9, 11))
	draw_rect(Rect2(6, -3.5, 2, 7), Color("df6e38"))
	draw_rect(Rect2(6, -2, 2, 4), Color("ffe4a0"))
	draw_circle(Vector2(-1, -7), 1, Color("dfad55"))
	draw_circle(Vector2(-1, 7), 1, Color("536970"))
	draw_line(Vector2(0, 8), Vector2(5, 7), Color("b18e48"), 2, true)

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	return box
