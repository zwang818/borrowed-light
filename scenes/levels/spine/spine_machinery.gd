@tool
extends Node2D
## Background motion blockouts only, not interactive machines or walkable surfaces.
@export_enum("fan", "piston", "distributor") var kind := "fan"
@export var phase := 0.0
var clock := 0.0
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		clock += delta
	queue_redraw()
func _draw() -> void:
	var pale := Color("657b81")
	var dark := Color("20333d")
	draw_rect(Rect2(-90,-90,180,180), Color("172730"))
	draw_rect(Rect2(-90,-90,180,180), pale, false, 4)
	if kind == "fan":
		draw_circle(Vector2.ZERO, 72, dark)
		draw_arc(Vector2.ZERO,74,0,TAU,48,pale,4)
		for i in range(4):
			var angle := clock * TAU / 6 + phase + i * PI / 2
			var direction := Vector2.from_angle(angle)
			draw_line(direction * 16,direction * 64,Color("435b65"),23)
		draw_circle(Vector2.ZERO,16,pale)
	else:
		for side in [-1,1]:
			var x: float = side * 42.0
			var travel: float = sin(clock * TAU / 4 + phase) * side * 24
			draw_rect(Rect2(x-15,-64,30,128),dark)
			draw_rect(Rect2(x-9,-32+travel,18,64),pale)
			draw_rect(Rect2(x-22,-44+travel,44,12),Color("405761"))
	for x in [-76,76]:
		for y in [-76,76]: draw_circle(Vector2(x,y),4,pale)
