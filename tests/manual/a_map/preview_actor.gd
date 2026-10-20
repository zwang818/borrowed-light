extends CharacterBody2D
## Movement-only test double. Never used by the main scene or B's player module.
const Metrics = preload("res://scenes/levels/graybox/graybox_metrics.gd")

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = Metrics.BODY_RADIUS
	$Collision.shape = shape
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var distance := Vector2(x - 128, y - 128).length() / 128.0
			image.set_pixel(x, y, Color(1, 0.9, 0.7, pow(maxf(0, 1 - distance), 1.2)))
	$Lamp.texture = ImageTexture.create_from_image(image)
	$Lamp.texture_scale = Metrics.LIGHT_RADIUS / 128.0

func _physics_process(_delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	)
	velocity = direction.normalized() * Metrics.WALK_SPEED
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, Metrics.BODY_RADIUS, Color("c7e2dd"))
	draw_arc(Vector2.ZERO, Metrics.BODY_RADIUS, 0, TAU, 32, Color("233e41"), 2)
	draw_circle(Vector2(4, -3), 3, Color("e6bd70"))
