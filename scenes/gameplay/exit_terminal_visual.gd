extends Node2D

const METAL := preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")
const INK := Color("10191d")
const GREEN := Color("a5e8ae")
var powered := false
var authorized := false
var sensing := false
var lever := 0.0:
	set(value):
		lever = value
		queue_redraw()
var lever_tween: Tween

func set_status(available: bool, nearby: bool, unlocked: bool) -> void:
	var response := available and nearby and not unlocked
	if authorized == unlocked and sensing == response:
		return
	authorized = unlocked
	sensing = response
	queue_redraw()

func set_power(enabled: bool) -> void:
	powered = enabled
	if lever_tween:
		lever_tween.kill()
	if enabled:
		lever_tween = create_tween().set_trans(Tween.TRANS_QUAD)
		lever_tween.tween_property(self, "lever", 1.0, 0.28)
	else:
		lever = 0.0
	queue_redraw()

func _draw() -> void:
	var cell := METAL.get_size() / 4.0
	var steel := Rect2(Vector2(2, 2) * cell, cell)
	draw_rect(Rect2(-56, -18, 112, 36), INK)
	draw_texture_rect_region(METAL, Rect2(-54, -16, 108, 32), steel)
	draw_rect(Rect2(-49, -13, 74, 26), INK)
	var screen := Rect2(-46, -10, 68, 20)
	var screen_color := Color("163127") if powered else Color("111e20")
	if sensing:
		screen_color = Color("376052") if powered else Color("4f4934")
	draw_rect(screen, screen_color)
	if sensing:
		var light := Color("8bc3a7") if powered else Color("c4aa76")
		draw_rect(screen, light, false, 1)
		draw_rect(Rect2(-42, 7, 60, 2), Color(light, 0.55))
	if powered:
		for i in range(3):
			draw_rect(Rect2(-42, -6 + 5 * i, 45 - i * 9, 2), GREEN if authorized or i == 0 else Color("568a68"))
	var switch_well := Rect2(30, -13, 21, 26)
	draw_rect(switch_well, Color("51412b") if sensing and not powered else INK)
	if sensing and not powered:
		draw_rect(switch_well, Color("c4aa76"), false, 1)
	draw_rect(Rect2(36, -10, 8, 20), Color("465451"))
	var handle_y := lerpf(-8.0, 7.0, lever)
	draw_rect(Rect2(33, handle_y - 3, 15, 7), Color("7d4c2c"))
	draw_rect(Rect2(34, handle_y - 3, 13, 3), Color("e0a464"))
	draw_rect(Rect2(27, -11, 2, 3), GREEN if powered else (Color("dfae75") if sensing else Color("78573d")))
	if sensing and not powered:
		draw_rect(Rect2(34, handle_y - 3, 13, 1), Color("f0ca91"))
