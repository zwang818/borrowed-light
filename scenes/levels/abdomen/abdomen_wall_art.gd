@tool
extends "res://scenes/levels/graybox/graybox_wall.gd"
## Inherits the original collision/occluder geometry without changing it.
const ATLAS = preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")
const ART_SCALE = preload("res://scenes/levels/abdomen/abdomen_art_scale.gd")

func _ready() -> void:
	material = ART_SCALE.surface_material(
		ART_SCALE.ATLAS_CELL_PX / ART_SCALE.WALL_STEP_WORLD.x,
		ART_SCALE.ATLAS_CELL_PX / ART_SCALE.WALL_STEP_WORLD.y
	)
	super._ready()

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cell := ATLAS.get_size() / 4.0
	var horizontal := size.x >= size.y
	# Long panels read as wall lengths, instead of a checkerboard of tiny tiles.
	var step := Vector2(64, 32) if horizontal else Vector2(32, 64)
	for y in range(0, int(size.y), int(step.y)):
		for x in range(0, int(size.x), int(step.x)):
			var extent := step.min(size - Vector2(x, y))
			var variant := posmod(int(position.x / 32) + int(position.y / 32) + int(x / 64) + int(y / 64), 4)
			var source := Rect2(Vector2(variant, 2) * cell, cell * extent / step)
			draw_texture_rect_region(ATLAS, Rect2(Vector2(x, y), extent), source, Color(0.75, 0.86, 0.87, 1))
	# Thin edge highlights and a dark foot distinguish a solid wall from floor plate.
	draw_rect(Rect2(Vector2.ZERO, size), Color("18232a"), false, 2)
	draw_line(Vector2(2, 2), Vector2(size.x - 2, 2), Color("718786"), 2)
	draw_line(Vector2(2, 3), Vector2(2, size.y - 3), Color("536c70"), 1)
	draw_rect(Rect2(Vector2(1, size.y - 7), Vector2(size.x - 2, 6)), Color(0.035, 0.055, 0.065, 0.88))
	for x in range(8, int(size.x) - 4, 32):
		draw_line(Vector2(x, size.y - 5), Vector2(mini(x + 12, int(size.x) - 3), size.y - 5), Color("34484c"), 2)
