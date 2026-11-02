extends Node2D
const ATLAS := preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")
const ART_SCALE := preload("res://scenes/levels/abdomen/abdomen_art_scale.gd")
var dimensions := Vector2(48, 48)
var unlocked := false
var lid: Sprite2D
var motion: Tween
var is_open := false

func _ready() -> void:
	z_index = 0
	lid = Sprite2D.new()
	lid.region_enabled = true
	var cell := ATLAS.get_size() / 4.0
	lid.texture = ATLAS
	lid.region_rect = Rect2(Vector2(3, 1) * cell, cell)
	lid.scale = dimensions / cell
	lid.material = ART_SCALE.surface_material(cell.x / dimensions.x, cell.y / dimensions.y)
	lid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(lid)
	queue_redraw()

func set_unlocked(value: bool) -> void:
	unlocked = value
	queue_redraw()

func set_open(value: bool) -> void:
	if not is_instance_valid(lid) or is_open == value:
		return
	is_open = value
	if motion != null and motion.is_valid():
		motion.kill()
	# Menu opening is an explicit state change, not an advancing world timer.
	if get_tree().paused:
		lid.position.x = -dimensions.x * 0.42 if value else 0.0
		lid.scale.x = dimensions.x / (ATLAS.get_width() / 4.0) * (0.16 if value else 1.0)
		return
	motion = create_tween().set_parallel()
	motion.tween_property(lid, "position:x", -dimensions.x * 0.42 if value else 0.0, 0.22)
	motion.tween_property(lid, "scale:x", dimensions.x / (ATLAS.get_width() / 4.0) * (0.16 if value else 1.0), 0.22)

func _draw() -> void:
	var half := dimensions * 0.5
	draw_rect(Rect2(-half, dimensions), Color("071318"))
	draw_rect(Rect2(-half, dimensions), Color("5c7168"), false, 2)
	for x in [-8, 8]:
		draw_line(Vector2(x, -half.y + 4), Vector2(x, half.y - 4), Color("52605b"), 2)
	for y in range(int(-half.y + 7), int(half.y - 3), 7):
		draw_line(Vector2(-8, y), Vector2(8, y), Color("7c7c62"), 2)
	draw_rect(Rect2(half.x - 6, half.y - 4, 4, 3), Color("a3d2b6") if unlocked else Color("c6a26a"))
