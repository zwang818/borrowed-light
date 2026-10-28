extends CharacterBody2D
## Harmless environmental reaction: no enemy group, health, damage or achievements.
const FRAMES = preload("res://assets/sprites/environment/abdomen/fleeing_spider.png")
const DRAW_SIZE := Vector2(26, 26) # Visible legs span ~20 units; robot head spans ~19.
var direction := Vector2.RIGHT
var drop_offset := Vector2(0, -10)
var background := false
var age := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0 if background else 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("ambient_spiders")
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	collider.shape = shape
	add_child(collider)

func _physics_process(delta: float) -> void:
	age += delta
	if age > 0.22:
		velocity = direction * 170.0
		move_and_slide()
		if get_slide_collision_count() > 0:
			var normal := get_slide_collision(0).get_normal()
			direction = (normal + direction.rotated(PI * 0.5)).normalized()
	if age > 1.8:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var fade := clampf((1.8 - age) / 0.35, 0.0, 1.0)
	var offset := drop_offset * (1.0 - clampf(age / 0.22, 0, 1))
	var frame := int(age * 14.0) % 4
	var cell := FRAMES.get_size() / 2.0
	draw_set_transform(offset, direction.angle() + PI * 0.5)
	draw_texture_rect_region(FRAMES, Rect2(-DRAW_SIZE / 2, DRAW_SIZE), Rect2(Vector2(frame % 2, frame / 2) * cell, cell), Color(1, 1, 1, fade))
