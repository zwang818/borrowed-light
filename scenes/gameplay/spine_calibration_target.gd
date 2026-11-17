extends Area2D
signal scatter_hit(target: int, burst: int)
var index := 0
var flash := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7
	shape.shape = circle
	add_child(shape)
	z_index = 18

func apply_damage(_amount: int) -> void:
	flash = 0.15 # Pulse leaves a mark, but cannot complete scatter calibration.

func receive_scatter_hit(_amount: int, burst: int) -> void:
	flash = 0.35
	scatter_hit.emit(index, burst)

func _process(delta: float) -> void:
	flash = maxf(0, flash - delta)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-10,-10,20,20), Color("263336"))
	draw_rect(Rect2(-9,-9,18,18), Color("b28d56"), false, 2)
	draw_circle(Vector2.ZERO, 6, Color("e4b76c") if flash <= 0 else Color("b7eee0"))
	draw_line(Vector2(-3,0),Vector2(3,0),Color("16272c"),2)
