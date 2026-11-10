extends Node2D
## Circulation pump with two independent sliders clipped to the fixed chassis.
const PART = preload("res://scenes/levels/spine/spine_texture.gd")
const COMPRESSOR = preload("res://assets/sprites/environment/abdomen/compressor_parts.png")
const BODY := Rect2(64, 49, 601, 578)
const RODS: Array[Rect2] = [Rect2(149, 704, 117, 455), Rect2(390, 704, 117, 455)]
const SLOTS: Array[Rect2] = [Rect2(-62, -11, 16, 35), Rect2(47, -11, 16, 35)]
const TINT := Color("c7a397")

var sliders: Array[Sprite2D] = []

func build() -> void:
	var mount := Vector2(-90, -87)
	PART.part(self, COMPRESSOR, BODY, Rect2(mount, BODY.size * 0.30), TINT)
	for index in range(RODS.size()):
		var source := RODS[index]
		sliders.append(PART.part(self, COMPRESSOR, source, Rect2(SLOTS[index].position, Vector2(16, 63)), TINT))
	var dial_center := mount + (Vector2(369, 204) - BODY.position) * 0.30
	var meter := Node2D.new()
	meter.position = dial_center
	add_child(meter)
	meter.draw.connect(func() -> void:
		meter.draw_circle(Vector2.ZERO, 26.0, Color("321d22"))
		meter.draw_circle(Vector2.ZERO, 21.0, Color("aa7352"))
		meter.draw_circle(Vector2.ZERO, 17.0, Color("d1a275"))
		for index in range(7):
			var tick := Vector2.from_angle(PI * (0.80 + index * 0.24))
			meter.draw_line(tick * 12.0, tick * 15.0, Color("604032"), 1.0)
		meter.draw_line(Vector2.ZERO, Vector2(7, -10), Color("642930"), 2.0)
		meter.draw_circle(Vector2.ZERO, 2.0, Color("463034"))
	)
	set_pose(0.0, 0.0)

func set_pose(clock: float, phase: float) -> void:
	for index in range(sliders.size()):
		var slot := SLOTS[index]
		var stroke := roundf(sin(clock * TAU / 4.0 + phase) * 11.0) * (-1.0 if index == 0 else 1.0)
		var destination := Rect2(slot.position - Vector2(0, 14 - stroke), Vector2(16, 63))
		var opening := destination.intersection(slot)
		var source := RODS[index]
		var ratio := source.size / destination.size
		sliders[index].position = opening.position
		sliders[index].region_rect = Rect2(source.position + (opening.position - destination.position) * ratio, opening.size * ratio)

func _draw() -> void:
	draw_rect(Rect2(-104, 65, 208, 34), Color("28161e"))
	draw_rect(Rect2(-101, 62, 202, 27), Color("52343b"))
	draw_rect(Rect2(-100, 62, 200, 2), Color("916450"))
	draw_rect(Rect2(-100, 88, 200, 3), Color("1b141c"))
	for x in range(-92, 93, 20):
		draw_rect(Rect2(x, 77, 11, 7), Color("2d2027"))
		draw_rect(Rect2(x + 2, 79, 4, 2), Color("89614d"))
