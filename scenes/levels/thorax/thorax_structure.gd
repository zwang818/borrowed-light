@tool
extends Node2D
## Independent side plating, rib sections and deck cable runs.
enum Layer { DEPTH, SURFACE }
const ART_SCALE := 1.88
const ARMOR := preload("res://assets/sprites/environment/thorax/floor_tiles.png")
const SHADOW := Color("0b1428")
const STEEL := Color("35466b")
const GRAY_EDGE := Color("849bb7")
var _last_deck := PackedVector2Array()

@export var layer := Layer.DEPTH:
	set(value):
		layer = value
		queue_redraw()

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	var deck := get_node_or_null("../../Floors/Deck") as Polygon2D
	if deck != null and deck.polygon != _last_deck:
		queue_redraw()

func _draw() -> void:
	var deck := get_node_or_null("../../Floors/Deck") as Polygon2D
	if deck == null or deck.polygon.size() < 3:
		return
	_last_deck = deck.polygon.duplicate()
	var rim := deck.polygon.duplicate()
	for index in range(rim.size()):
		rim[index] /= ART_SCALE
	rim.append(rim[0])
	if layer == Layer.DEPTH:
		_draw_cage()
		_draw_cladding(rim)
	else:
		_draw_deck_trim(rim)
		_draw_deck_connections()

func _draw_cage() -> void:
	_draw_bulkhead()
	# Nested frames and columns sit behind the deck and its wall panels.
	for side: float in [-1.0, 1.0]:
		for index in range(5):
			var x := 758.0 + side * (190.0 + index * 115.0)
			var roof := 17.0 + index * 9.0
			var span := 115.0 + index * 4.0
			var upper := PackedVector2Array([
				Vector2(x, 274), Vector2(x, roof + 111),
				Vector2(x + side * 12.0, roof + 71),
				Vector2(x + side * 42.0, roof + 37),
				Vector2(x + side * 82.0, roof + 15),
				Vector2(x + side * span, roof + 4),
			])
			_draw_rib(_rounded(upper, 16.0), 18.0, Color("233454"), 0.58)
		for index in range(4):
			var start_x := 762.0 + side * (235.0 + 145.0 * index)
			var top := 749.0 + 10.0 * (index % 2)
			var lower := PackedVector2Array([
				Vector2(start_x, top), Vector2(start_x, top + 95.0),
				Vector2(start_x + side * 21.0, top + 145.0),
				Vector2(start_x + side * 65.0, top + 190.0),
				Vector2(start_x + side * 104.0, top + 253.0),
			])
			_draw_rib(_rounded(lower, 12.0), 23.0, Color("192b49"), 0.43)
		for index in range(2):
			var outer_x := 758.0 + side * (436.0 + index * 152.0)
			var foreground := PackedVector2Array([
				Vector2(outer_x, 756 + index * 11), Vector2(outer_x + side * 12, 805),
				Vector2(outer_x + side * 41, 860), Vector2(outer_x + side * 78, 919),
				Vector2(outer_x + side * 121, 1018),
			])
			_draw_rib(_rounded(foreground, 18.0), 31.0, Color("304365"), 0.72)
	for offset in [0.0, 63.0, 124.0]:
		var brace := PackedVector2Array([
			Vector2(45, 718 + offset), Vector2(192, 795 + offset),
			Vector2(395, 822 + offset), Vector2(590, 797 + offset),
			Vector2(758, 835 + offset), Vector2(965, 797 + offset),
			Vector2(1170, 820 + offset), Vector2(1350, 787 + offset),
			Vector2(1480, 717 + offset),
		])
		_draw_rib(_rounded(brace, 20.0), 15.0, Color("253754"), 0.36)

func _draw_bulkhead() -> void:
	# A recessed skin closes the gaps behind the structural ribs.
	var top := PackedVector2Array([
		Vector2(17, 136), Vector2(188, 36), Vector2(415, -13), Vector2(765, -28),
		Vector2(1104, -13), Vector2(1340, 35), Vector2(1502, 133),
	])
	var skin := top.duplicate()
	skin.append_array(PackedVector2Array([Vector2(1502, 284), Vector2(17, 284)]))
	draw_colored_polygon(skin, Color("132139"))
	for row in range(5):
		for column in range(17):
			var origin := Vector2(17 + column * 91 + (row % 2) * 42 - 30, -29 + row * 64)
			var size := Vector2(88, 61)
			var panel := PackedVector2Array([origin, origin + Vector2(size.x, 0), origin + size, origin + Vector2(0, size.y)])
			for face in Geometry2D.intersect_polygons(panel, skin):
				var uv := PackedVector2Array()
				for point in face:
					uv.append(Vector2(0.08, 0.08) + (point - origin) / size * 0.33)
				var shade := 0.44 + float((row * 3 + column * 7) % 4) * 0.03
				draw_colored_polygon(face, Color(shade, shade * 1.07, shade * 1.24), uv, ARMOR)
	var band := _rounded(top, 36.0)
	draw_polyline(band, Color("0c162b"), 19)
	draw_polyline(band, Color("293958"), 12)
	for x in range(87, 1475, 74):
		var y := 28.0 + pow(absf(float(x) - 758.0) / 741.0, 2.0) * 122.0
		draw_rect(Rect2(x, y, 13, 264.0 - y), Color("0d182e"))
		draw_rect(Rect2(x + 2, y, 2.5, 264.0 - y), Color("223450"))
		_bolt(Vector2(x + 8, y + 15), Color("3b506c"))

func _draw_rib(points: PackedVector2Array, width: float, color: Color, edge_strength: float) -> void:
	draw_polyline(points, SHADOW, width + 5)
	draw_polyline(points, color, width)
	for index in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		var cross := (b - a).normalized().orthogonal() * (width * 0.33)
		_armored_face(a - cross, b - cross, b + cross, a + cross, Color(0.66, 0.72, 0.89))
	var edge := PackedVector2Array()
	for point in points:
		edge.append(point + Vector2(-width * 0.20, -width * 0.16))
	draw_polyline(edge, color.lightened(edge_strength * 0.18), 2)
	var remaining := 26.0
	for index in range(points.size() - 1):
		var start := points[index]
		var segment := points[index + 1] - start
		var length := segment.length()
		var axis := segment.normalized()
		while remaining < length:
			var center := start + axis * remaining
			var cross := axis.orthogonal() * (width * 0.43)
			draw_line(center - cross, center + cross, color.darkened(0.42), 2)
			draw_line(center - cross + axis, center + cross + axis, color.lightened(0.13), 0.8)
			remaining += 38.0
		remaining -= length

func _draw_cladding(rim: PackedVector2Array) -> void:
	for index in range(rim.size() - 1):
		var a := rim[index]
		var b := rim[index + 1]
		var delta := b - a
		# Near edges expose the vertical fascia below the playable surface.
		if delta.x >= 0.0:
			continue
		var depth := Vector2(0, 37)
		draw_colored_polygon(PackedVector2Array([a, b, b + depth, a + depth]), Color("1a2945"))
		_armored_face(a, b, b + depth, a + depth, Color(0.61, 0.69, 0.89))
		draw_line(a + Vector2(0, 28), b + Vector2(0, 28), Color("101d34"), 12)
		draw_line(a + Vector2(0, 6), b + Vector2(0, 6), Color("2b3c59"), 5)
		var axis := delta.normalized()
		for step in range(12, int(delta.length()), 26):
			var seam := a + axis * step
			draw_line(seam, seam + depth * 0.75, SHADOW, 1.4)
			draw_line(seam + axis * 1.5, seam + axis * 1.5 + depth * 0.6, Color("3d5070"), 1)
			_bolt(seam + axis * 4.0 + Vector2(0, 11), Color("72849e"))

func _armored_face(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	var uv := PackedVector2Array([Vector2(0.1, 0.10), Vector2(0.35, 0.10), Vector2(0.35, 0.23), Vector2(0.10, 0.23)])
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), color, uv, ARMOR)

func _draw_deck_trim(rim: PackedVector2Array) -> void:
	draw_polyline(rim, SHADOW, 8.0)
	draw_polyline(rim, STEEL, 5.2)
	draw_polyline(rim, Color("687d9b"), 1.0)
	for index in range(rim.size() - 1):
		var a := rim[index]
		var delta := rim[index + 1] - a
		var axis := delta.normalized()
		var cross := axis.orthogonal() * 2.2
		for step in range(14, int(delta.length()), 25):
			var seam := a + axis * step
			draw_line(seam - cross, seam + cross, SHADOW, 1.2)
			_bolt(seam + axis * 5.0, GRAY_EDGE)

func _draw_deck_connections() -> void:
	_cable(PackedVector2Array([
		Vector2(664, 303), Vector2(650, 335), Vector2(475, 335),
		Vector2(427, 306), Vector2(395, 254), Vector2(354, 243),
	]), Vector2(537, 335))
	_cable(PackedVector2Array([
		Vector2(845, 303), Vector2(870, 335), Vector2(1050, 335),
		Vector2(1095, 303), Vector2(1181, 303), Vector2(1255, 343),
		Vector2(1357, 372), Vector2(1281, 428), Vector2(1242, 507),
		Vector2(1242, 633), Vector2(1210, 669), Vector2(1163, 672),
	]), Vector2(970, 335))
	_cable(PackedVector2Array([
		Vector2(208, 602), Vector2(249, 625), Vector2(250, 665),
		Vector2(345, 665), Vector2(372, 698),
	]), Vector2(303, 665))

func _cable(nodes: PackedVector2Array, clamp_anchor: Vector2) -> void:
	var path := _rounded(nodes, 17.0)
	for shift in [-2.2, 2.2]:
		var run := PackedVector2Array()
		var highlight := PackedVector2Array()
		for point in path:
			run.append(point + Vector2(0, shift))
			highlight.append(point + Vector2(0, shift - 1))
		draw_polyline(run, SHADOW, 5.2)
		draw_polyline(run, Color("2d3d58"), 3.0)
		draw_polyline(highlight, Color("647893"), 0.7)
	draw_rect(Rect2(clamp_anchor - Vector2(5, 6), Vector2(10, 12)), SHADOW)
	draw_rect(Rect2(clamp_anchor - Vector2(4, 5), Vector2(8, 10)), STEEL)
	_bolt(clamp_anchor + Vector2(-2.2, -3), GRAY_EDGE)
	_bolt(clamp_anchor + Vector2(2.2, 3), GRAY_EDGE)
	var tail := path[-1]
	draw_rect(Rect2(tail - Vector2(5, 6), Vector2(10, 12)), SHADOW)
	draw_rect(Rect2(tail - Vector2(4, 4), Vector2(8, 8)), STEEL)
	draw_line(tail + Vector2(-3, -3), tail + Vector2(3, -3), GRAY_EDGE, 0.7)

func _bolt(point: Vector2, color: Color) -> void:
	draw_rect(Rect2(point - Vector2.ONE, Vector2(2.0, 2.0)), SHADOW)
	draw_rect(Rect2(point - Vector2(0.75, 0.75), Vector2(0.95, 0.95)), color)

func _rounded(points: PackedVector2Array, reach: float) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	for index in range(1, points.size() - 1):
		var p := points[index]
		var pre := p.move_toward(points[index - 1], minf(reach, p.distance_to(points[index - 1]) * 0.45))
		var post := p.move_toward(points[index + 1], minf(reach, p.distance_to(points[index + 1]) * 0.45))
		for hop in range(5):
			var t := float(hop) / 4.0
			result.append(pre.lerp(p, t).lerp(p.lerp(post, t), t))
	result.append(points[-1])
	return result
