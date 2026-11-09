extends Node2D
const DOOR_TEXTURE := preload("res://assets/sprites/interactables/bulkhead.png")
const TERMINAL_TEXTURE := preload("res://assets/sprites/interactables/access_terminal.png")
const ART_SCALE := preload("res://scenes/levels/abdomen/abdomen_art_scale.gd")
## Presentation for C's existing colliders; no game state or input authority.
var kind := "door"
var dimensions := Vector2(64, 32)
var unlocked := false
var focused := false
var activated := false
var open_amount := 0.0:
	set(value):
		open_amount = clampf(value, 0, 1)
		queue_redraw()

func set_status(is_unlocked: bool, is_focused: bool = false, is_activated: bool = false) -> void:
	if unlocked == is_unlocked and focused == is_focused and activated == is_activated:
		return
	unlocked = is_unlocked
	focused = is_focused
	activated = is_activated
	queue_redraw()

func _ready() -> void:
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	var tint := Color("86cbbc") if unlocked else Color("c6a26a")
	var half := dimensions * 0.5
	if kind == "terminal":
		var source := Rect2(88, 45, 865, 1470)
		material = ART_SCALE.surface_material(source.size.x / 42, source.size.y / 64)
		draw_texture_rect_region(TERMINAL_TEXTURE, Rect2(-21, -36, 42, 64), source)
		var status_color := Color("9fdec4") if unlocked else Color("cda45c")
		if activated:
			draw_polyline(PackedVector2Array([Vector2(-7, -17), Vector2(-3, -13), Vector2(4, -21)]), status_color, 1)
		else:
			for i in 3:
				draw_rect(Rect2(-8, -23 + i * 3, 9 + i * 2, 1), status_color)
		if focused:
			draw_line(Vector2(-24, 30), Vector2(24, 30), status_color, 1)
		return
	if kind == "door":
		var source := Rect2(30, 140, 2118, 430)
		var width := dimensions.x
		var height := maxf(dimensions.y, 30)
		material = ART_SCALE.surface_material(source.size.x / width, source.size.y / height)
		var part_width := width * 0.5 * (1 - open_amount)
		if part_width > 0.1:
			var fraction := part_width / width
			draw_texture_rect_region(DOOR_TEXTURE, Rect2(-width * 0.5, -height * 0.5, part_width, height), Rect2(source.position, Vector2(source.size.x * fraction, source.size.y)))
			draw_texture_rect_region(DOOR_TEXTURE, Rect2(width * 0.5 - part_width, -height * 0.5, part_width, height), Rect2(source.position + Vector2(source.size.x * (1 - fraction), 0), Vector2(source.size.x * fraction, source.size.y)))
		for x in [-width * 0.5, width * 0.5]:
			draw_rect(Rect2(x - 2, -height * 0.5, 4, height), Color("435350"))
			draw_rect(Rect2(x - 1, -3, 2, 6), tint)
		return
	var atlas: Texture2D = preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")
	var cell := atlas.get_size() / 4.0
	material = ART_SCALE.surface_material(cell.x / dimensions.x, cell.y / dimensions.y)
	draw_rect(Rect2(-half + Vector2(3, 3), dimensions), Color(0.02, 0.04, 0.05, 0.45))
	draw_texture_rect_region(atlas, Rect2(-half, dimensions), Rect2(Vector2(0, 2) * cell, cell), Color(0.75, 0.86, 0.87, 1))
	draw_rect(Rect2(Vector2(-half.x, half.y - 5), Vector2(dimensions.x, 5)), Color("26373b"))
	draw_line(Vector2(-half.x, half.y - 5), Vector2(half.x, half.y - 5), Color("75898a"), 1)
	draw_rect(Rect2(-half, dimensions), Color("25383d"), false, 1)
