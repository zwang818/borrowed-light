@tool
extends Node2D

const BLUEPRINT := preload("res://assets/sprites/ui/pulse_arm_blueprint.svg")
const METAL := preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")
const SCREEN := Rect2(-40, -33, 80, 46)
const CABLE_PORT := Vector2(57, 29)
const INK := Color("101b20")
const CYAN := Color("73e8e0")

var transfer_time := -1.0
var receiver := Vector2.ZERO
var inserting := true

func show_transfer(seconds: float, socket: Vector2, insert := true) -> void:
	inserting = insert
	transfer_time = seconds
	receiver = to_local(socket)
	queue_redraw()

func _draw() -> void:
	# The original metal rack remains the foundation.
	draw_rect(Rect2(-60, -37, 123, 83), Color("10191d", 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-64, -35), Vector2(-49, -48), Vector2(54, -48), Vector2(66, -35),
		Vector2(66, 24), Vector2(54, 40), Vector2(-64, 40),
	]), INK)
	var cell := METAL.get_size() / 4.0
	var panel := Rect2(Vector2(2, 2) * cell, cell)
	var bevel := Rect2(panel.position, Vector2(cell.x, cell.y * 0.32))
	draw_texture_rect_region(METAL, Rect2(-59, -34, 111, 70), panel, Color("b9cbc8"))
	draw_texture_rect_region(METAL, Rect2(-48, -44, 101, 9), bevel, Color("a1b2ad"))
	draw_texture_rect_region(METAL, Rect2(52, -33, 10, 55), bevel, Color("657976"))
	draw_line(Vector2(-58, -34), Vector2(52, -34), Color("718786"), 2)
	draw_line(Vector2(-59, 35), Vector2(52, 35), Color("18232a"), 3)
	draw_rect(SCREEN.grow(5), INK)
	draw_texture_rect(BLUEPRINT, SCREEN, false)
	draw_rect(SCREEN, CYAN, false, 1)
	draw_rect(Rect2(-39, 19, 56, 11), INK)
	for column in range(7):
		draw_rect(Rect2(-36 + column * 7, 21, 4, 2), Color("829995"))
		draw_rect(Rect2(-36 + column * 7, 26, 4, 2), Color("556e70"))
	draw_rect(Rect2(28, 20, 12, 10), INK)
	draw_rect(Rect2(31, 23, 6, 4), CYAN)
	for bolt in [Vector2(-54, -30), Vector2(47, -30), Vector2(-54, 30), Vector2(47, 30)]:
		draw_rect(Rect2(bolt, Vector2(3, 3)), Color("b7a782"))
	if transfer_time >= 0.0:
		_draw_transfer()

func _draw_transfer() -> void:
	var source := CABLE_PORT
	var progress := clampf((transfer_time - 0.55) / 3.7, 0.0, 1.0)
	var retract := smoothstep(4.55, 5.0, transfer_time)
	var approach := Vector2(18, 0)
	var insertion := smoothstep(0.0, 0.55, transfer_time) if inserting else 0.0
	var end := (receiver + approach * (1.0 - insertion)).lerp(source, retract)
	var span := end - source
	var bend := minf(44.0, span.length() * 0.85) * (1.0 - retract)
	var control_a := source + Vector2(bend, 0)
	var control_b := end + Vector2(bend, 16.0 * (1.0 - retract))
	var wire := PackedVector2Array()
	for i in range(17):
		var t := float(i) / 16.0
		wire.append(source.bezier_interpolate(control_a, control_b, end, t))
	draw_polyline(wire, Color("0d1518"), 8)
	draw_polyline(wire, Color("797c70"), 5)
	draw_polyline(wire, Color("b4ad94"), 2)
	if span.length() > 24.0:
		var wrap := wire[5]
		var tangent := (wire[6] - wire[4]).normalized()
		draw_line(wrap - tangent * 4, wrap + tangent * 4, Color("807055"), 5)
		draw_line(wrap, wrap + tangent, Color("b6a383"), 5)
	draw_rect(Rect2(source - Vector2(4, 4), Vector2(8, 8)), INK)
	draw_rect(Rect2(receiver - Vector2(6, 6), Vector2(12, 12)), Color("161d20"))
	draw_rect(Rect2(receiver - Vector2(5, 5), Vector2(10, 10)), Color("bb955e"), false, 2)
	draw_rect(Rect2(receiver - Vector2(3, 2), Vector2(6, 4)), CYAN if insertion >= 1.0 and retract == 0.0 else Color("576663"))

	draw_set_transform(end, (end - wire[15]).angle())
	draw_rect(Rect2(-14, -6, 14, 12), INK)
	draw_rect(Rect2(-12, -4, 8, 8), Color("a0a89a"))
	draw_rect(Rect2(-4, -3, 4, 6), Color("d0ad70"))
	draw_set_transform(Vector2.ZERO)

	if insertion >= 1.0 and progress < 1.0:
		_draw_bits(wire)
	draw_rect(Rect2(-40, 9, 80, 4), INK)
	draw_rect(Rect2(-40, 9, 80 * progress, 4), CYAN)

func _draw_bits(wire: PackedVector2Array) -> void:
	# Pixel glyphs stay readable without a font or glow around the cable.
	for i in range(5):
		var phase := fposmod((transfer_time - 0.55) * 0.85 - i * 0.19, 1.0)
		if phase < 0.04 or phase > 0.96:
			continue
		var sample := phase * 16.0
		var index := int(sample)
		var point := wire[index].lerp(wire[index + 1], sample - index).round() - Vector2(2, 17)
		draw_rect(Rect2(point - Vector2(2, 2), Vector2(11, 14)), Color("132529"))
		if i % 2 == 0:
			draw_rect(Rect2(point, Vector2(7, 10)), CYAN, false, 2)
		else:
			draw_line(point + Vector2(3, 0), point + Vector2(3, 9), CYAN, 2)
			draw_line(point + Vector2(0, 9), point + Vector2(6, 9), CYAN, 2)
