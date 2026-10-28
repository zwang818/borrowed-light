@tool
extends Area2D
## A weapon target, not an enemy. Layer 3 is the existing weapon-target bit (4).
const ATLAS = preload("res://assets/sprites/environment/abdomen/props_atlas.png")
const CAVITY = preload("res://assets/sprites/environment/abdomen/service_cavity.png")
@export var draw_size := Vector2(70, 70)
@export var mirror_x := false
var background_region := Rect2()
var broken := false
var _age := 0.0
var _spider_released := false
var environment: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0 if Engine.is_editor_hint() else 4
	collision_mask = 0
	monitoring = false
	monitorable = false
	set_physics_process(false)
	if not Engine.is_editor_hint():
		add_to_group("breakable_webs")
		var shape := CollisionPolygon2D.new()
		shape.name = "WeaponHitShape"
		shape.polygon = hit_polygon()
		add_child(shape)

func hit_polygon() -> PackedVector2Array:
	if background_region.has_area():
		return PackedVector2Array([-draw_size / 2, Vector2(draw_size.x, -draw_size.y) / 2, draw_size / 2, Vector2(-draw_size.x, draw_size.y) / 2])
	var points := PackedVector2Array([Vector2(-0.45, -0.43), Vector2(0.44, -0.43), Vector2(-0.43, 0.43)])
	for i in range(points.size()):
		points[i] *= draw_size
		if mirror_x:
			points[i].x *= -1.0
	return points

func apply_damage(amount: int) -> void:
	if amount <= 0 or broken or Engine.is_editor_hint():
		return
	broken = true
	_age = 0.0
	set_physics_process(true)
	queue_redraw()
	call_deferred("_release_spider")

func _release_spider() -> void:
	if broken and not _spider_released and is_instance_valid(environment):
		_spider_released = true
		environment.spawn_spider(self)

func _physics_process(delta: float) -> void:
	_age += delta
	# Keep blocking this beam's 0.15 s contact window, so one shot cannot pierce.
	if _age >= 0.2:
		collision_layer = 0
		set_physics_process(false)
	queue_redraw()

func reset_web() -> void:
	broken = false
	_spider_released = false
	_age = 0.0
	collision_layer = 4 if get_child_count() > 0 else 0
	set_physics_process(false)
	queue_redraw()

func _draw() -> void:
	if broken:
		if _age < 0.2:
			for i in range(5):
				var v := Vector2.from_angle(float(i) * 1.3)
				draw_line(v * (4 + _age * 28), v * (9 + _age * 38), Color(0.7, 0.76, 0.71, (1 - _age / 0.2) * 0.65), 1.0)
		return
	var target := Rect2(-draw_size / 2, draw_size)
	if background_region.has_area():
		draw_texture_rect_region(CAVITY, target, background_region, Color(0.46, 0.54, 0.58, 1))
	else:
		if mirror_x:
			target.position.x += draw_size.x
			target.size.x *= -1
		var cell := ATLAS.get_size() / 4.0
		draw_texture_rect_region(ATLAS, target, Rect2(Vector2(2, 2) * cell, cell))
