@tool
extends Node2D
## Editable art only: no collision, AI, interaction, IDs or progress state.
const ATLAS = preload("res://assets/sprites/environment/abdomen/props_atlas.png")
const ART_SCALE = preload("res://scenes/levels/abdomen/abdomen_art_scale.gd")
@export_range(0, 15) var atlas_cell: int = 0:
	set(value):
		atlas_cell = value
		queue_redraw()
@export var draw_size := Vector2(96, 96):
	set(value):
		draw_size = value
		queue_redraw()
@export var mirror_x := false:
	set(value):
		mirror_x = value
		queue_redraw()
@export var fit_parent_wall := false
var _last_size := Vector2.ZERO

func _ready() -> void:
	material = ART_SCALE.surface_material(
		ART_SCALE.ATLAS_CELL_PX / maxf(draw_size.x, 1.0),
		ART_SCALE.ATLAS_CELL_PX / maxf(draw_size.y, 1.0)
	)
	set_process(fit_parent_wall)

func _process(_delta: float) -> void:
	if fit_parent_wall and get_parent() != null:
		var wall_size: Vector2 = get_parent().get("size")
		if wall_size != _last_size:
			_last_size = wall_size
			queue_redraw()

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cell := ATLAS.get_size() / 4.0
	var source := Rect2(Vector2(atlas_cell % 4, atlas_cell / 4) * cell, cell)
	var target := Rect2(-draw_size * 0.5, draw_size)
	if fit_parent_wall:
		target = Rect2(Vector2.ZERO, get_parent().get("size"))
	ART_SCALE.apply_to(self, cell.x / maxf(absf(target.size.x), 1.0), cell.y / maxf(absf(target.size.y), 1.0))
	if mirror_x:
		target.position.x += draw_size.x
		target.size.x *= -1
	draw_texture_rect_region(ATLAS, target, source)
