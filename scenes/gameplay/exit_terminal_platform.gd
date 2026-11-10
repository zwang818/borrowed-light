extends Node2D

const METAL := preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")
# Relative to the terminal marker. Only the upper landing grants access.
const LANDING := Rect2(-58, -45, 116, 87)

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cell := METAL.get_size() / 4.0
	var plate := Rect2(Vector2(1, 2) * cell, cell)
	draw_rect(Rect2(-60, -45, 120, LANDING.size.y + 26), Color("111b20"))
	draw_texture_rect_region(METAL, LANDING, plate, Color("b5c2ba"))
	for step in range(3):
		var top := LANDING.end.y + step * 8.0
		var tread := Rect2(-58, top, 116, 7)
		draw_texture_rect_region(METAL, tread, plate, Color("88988e"))
		draw_line(Vector2(-58, top), Vector2(58, top), Color("82948e"), 2)
		draw_line(Vector2(-58, top + 6), Vector2(58, top + 6), Color("23333a"), 2)
	draw_line(LANDING.position, Vector2(-58, LANDING.end.y), Color("87988c"), 2)
	draw_line(Vector2(58, LANDING.position.y), LANDING.end, Color("657870"), 2)
