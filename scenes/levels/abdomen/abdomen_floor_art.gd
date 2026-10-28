@tool
extends "res://scenes/levels/graybox/graybox_floor.gd"
## Visual replacement only. World units and the floor's editable Size are unchanged.
const ATLAS = preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")
const PIXEL_MATERIAL = preload("res://scenes/levels/abdomen/abdomen_pixel.tres")
@export_enum("Plate", "Grate", "Workshop", "Threshold", "Hazard decal", "Hatch decal") var surface: int = 0:
	set(value):
		surface = value
		queue_redraw()

func _ready() -> void:
	material = PIXEL_MATERIAL

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cell := ATLAS.get_size() / 4.0
	if surface >= 4:
		var index := 6 if surface == 4 else 7
		draw_texture_rect_region(ATLAS, Rect2(Vector2.ZERO, size), Rect2(Vector2(index % 4, index / 4) * cell, cell), Color(0.65, 0.73, 0.68, 0.9))
		return
	# World-aligned texture coordinates keep adjoining floor rectangles continuous.
	var tile := 64.0
	var origin := position.snapped(Vector2.ONE)
	var start := (origin / tile).floor() * tile
	for y in range(int(start.y), int(origin.y + size.y), int(tile)):
		for x in range(int(start.x), int(origin.x + size.x), int(tile)):
			var world_rect := Rect2(Vector2(x, y), Vector2.ONE * tile)
			var clipped := world_rect.intersection(Rect2(origin, size))
			var variation := posmod(int(x / tile) * 7 + int(y / tile) * 13, 11)
			var index := 0 if variation < 6 else (1 if variation < 8 else (2 if variation < 10 else 3))
			var tint := Color(0.79, 0.87, 0.84, 1)
			if surface == 1:
				index = 4 if variation < 6 else 5
				tint = Color(0.73, 0.81, 0.8, 1)
			elif surface == 2:
				index = 0
				tint = Color(0.93, 0.94, 0.83, 1)
			elif surface == 3:
				index = 5
			var uv := Vector2(index % 4, index / 4) * cell
			var sampled_size := cell
			var source := Rect2(uv + (clipped.position - world_rect.position) / tile * sampled_size, clipped.size / tile * sampled_size)
			draw_texture_rect_region(ATLAS, Rect2(clipped.position - origin, clipped.size), source, tint)
