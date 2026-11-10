extends Node2D
## Draws individual 2D fittings at their world size. Collision stays on the graybox.
const INK := Color("111920")
const STEEL := Color("4f555a")
const EDGE := Color("9b9084")
const BRASS := Color("bb8846")
const AMBER := Color("ffd589")
const CYAN := Color("a8e3e7")

var kind := "terminal"
var span := Vector2.ZERO
var tint := BRASS
var seconds := 0.0
var arc_preview := false
var door: Node2D
var last_frame := -1
var last_door_state := false

func _ready() -> void:
	set_process((kind == "seam" and arc_preview) or kind == "door")

func _process(delta: float) -> void:
	if kind == "door":
		if door.is_open != last_door_state:
			last_door_state = door.is_open
			queue_redraw()
		return
	seconds += delta
	var frame := int(seconds * 14)
	if frame != last_frame:
		last_frame = frame
		queue_redraw()

func _panel(box: Rect2, paint := STEEL, thickness := 4.0) -> void:
	draw_rect(Rect2(box.position + Vector2(2, thickness), box.size), INK)
	draw_rect(box, paint)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 2)), paint.lightened(0.28))
	draw_rect(Rect2(box.end - Vector2(box.size.x, 3), Vector2(box.size.x, 3)), paint.darkened(0.45))
	draw_rect(box, INK, false, 1.0)
	for x in [box.position.x + 4.0, box.end.x - 5.0]:
		for y in [box.position.y + 4.0, box.end.y - 5.0]:
			_bolt(Vector2(x, y))

func _bolt(at: Vector2) -> void:
	draw_rect(Rect2(at.floor(), Vector2(3, 3)), INK)
	draw_rect(Rect2(at.floor(), Vector2(2, 1)), EDGE)

func _ring(at: Vector2, radius: float, stroke: float, paint: Color) -> void:
	draw_arc(at, radius, 0.0, TAU, 36, paint, stroke)

func _lamp(box: Rect2, paint: Color) -> void:
	draw_rect(box.grow(3), INK)
	draw_rect(box.grow(1), paint.darkened(0.5))
	draw_rect(box, paint)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), paint.lightened(0.46))

func _stripes(box: Rect2, paint: Color) -> void:
	draw_rect(box, INK)
	for x in range(0, int(box.size.x) - 8, 12):
		var at := box.position + Vector2(x, 0)
		draw_colored_polygon(PackedVector2Array([at + Vector2(4, 0), at + Vector2(9, 0),
			at + Vector2(5, box.size.y), at + Vector2(0, box.size.y)]), paint)

func _draw() -> void:
	match kind:
		"terminal", "record", "blueprint":
			_draw_console()
		"duct":
			_draw_duct()
		"valve":
			_draw_valve()
		"barrier":
			_draw_barrier()
		"seam":
			_draw_seam()
		"door", "entry":
			_draw_door()
		"socket":
			_draw_socket()
		"dock_flange":
			_draw_dock_flange()

func _draw_console() -> void:
	var width := 56.0 if kind == "blueprint" else 43.0
	draw_rect(Rect2(-width / 2 - 3, -17, width + 10, 34), Color(0.04, 0.06, 0.08, 0.60))
	_panel(Rect2(-width / 2, -23, width, 37), STEEL.darkened(0.13), 5)
	_panel(Rect2(-width / 2 + 4, -20, width - 8, 22), Color("26363c"), 2)
	draw_rect(Rect2(-width / 2 + 7, -17, width - 14, 16), Color("173a48"))
	draw_rect(Rect2(-width / 2 + 7, -17, width - 14, 1), CYAN.darkened(0.35))
	for y in range(-14, -1, 4):
		draw_line(Vector2(-width / 2 + 8, y), Vector2(width / 2 - 8, y), Color("275261"), 1)
	if kind == "blueprint":
		draw_polyline(PackedVector2Array([Vector2(-14, -10), Vector2(-8, -14), Vector2(7, -14),
			Vector2(7, -12), Vector2(15, -12), Vector2(15, -9), Vector2(2, -9),
			Vector2(-1, -5), Vector2(-6, -5), Vector2(-5, -9), Vector2(-14, -10)]), CYAN, 1)
	else:
		for y in range(-14, -3, 4):
			var length := 12 + posmod(y * 7, 10)
			draw_line(Vector2(-11, y), Vector2(-11 + length, y), CYAN.darkened(0.20), 1)
	for x in range(-12, 13, 6):
		draw_rect(Rect2(x, 6, 4, 3), INK)
		draw_rect(Rect2(x, 6, 3, 1), EDGE)
	_lamp(Rect2(width / 2 - 9, 5, 3, 4), CYAN if kind == "record" else AMBER)

func _draw_duct() -> void:
	var center := Vector2(0, -2)
	draw_circle(Vector2(3, 5), 35, Color("271a20"))
	draw_circle(center, 34, Color("674743"))
	_ring(center, 31, 4, Color("9b7160"))
	draw_arc(center, 30, PI, TAU, 22, Color("c69978"), 2)
	_ring(center, 26, 4, Color("3a2529"))
	_ring(center, 22, 2, Color("ac7854"))
	draw_circle(center, 19, Color("26191e"))
	draw_arc(center, 16, PI, TAU, 20, Color("4c2a29"), 2)
	for index in range(10):
		var direction := Vector2.from_angle(index * TAU / 10)
		_bolt(center + direction * 30)
		draw_line(center + direction * 24, center + direction * 26, Color("c48d62"), 1)
	draw_rect(Rect2(-14, 17, 28, 10), Color("3a2d32"))
	draw_line(Vector2(-14, 18), Vector2(14, 18), Color("936551"), 2)
	draw_polyline(PackedVector2Array([Vector2(0, -10), Vector2(0, 8)]), Color("754727"), 5)
	draw_polyline(PackedVector2Array([Vector2(0, -10), Vector2(0, 8)]), AMBER, 2)
	draw_polyline(PackedVector2Array([Vector2(-6, 2), Vector2(0, 8), Vector2(6, 2)]), AMBER, 2)

func _draw_valve() -> void:
	_panel(Rect2(-26, -33, 52, 66), Color("333b43"))
	_panel(Rect2(-17, -29, 32, 56), STEEL)
	for y in [-23, -15, 15, 23]:
		draw_line(Vector2(-13, y), Vector2(11, y), INK, 2)
		draw_line(Vector2(-13, y + 2), Vector2(11, y + 2), EDGE.darkened(0.35), 1)
	var hub := Vector2(0, 2)
	draw_circle(hub + Vector2(2, 2), 18, INK)
	draw_circle(hub, 15, Color("472623"))
	_ring(hub, 13, 3, Color("aa5d40"))
	for i in range(3):
		draw_line(hub, hub + Vector2.from_angle(i * TAU / 3 + 0.6) * 12, Color("bb7151"), 2)
	draw_circle(hub, 4, BRASS.darkened(0.25))
	_lamp(Rect2(-9, -27, 17, 2), AMBER)

func _draw_barrier() -> void:
	_panel(Rect2(-12, -span.y * 0.5 + 4, 24, span.y - 8), STEEL.darkened(0.13))
	for y in range(int(-span.y * 0.5 + 11), int(span.y * 0.5 - 12), 18):
		draw_rect(Rect2(-10, y, 20, 9), BRASS)
		draw_line(Vector2(-8, y + 8), Vector2(8, y), INK, 4)
	_lamp(Rect2(-6, -3, 12, 3), Color("f19752"))

func _draw_seam() -> void:
	_panel(Rect2(0, 0, span.x, span.y), Color("424852"), 1)
	for x in range(11, int(span.x) - 8, 10):
		for y in range(11, int(span.y) - 8, 13):
			draw_rect(Rect2(x, y, 6, 8), INK)
			draw_line(Vector2(x, y + 8), Vector2(x + 6, y + 8), EDGE.darkened(0.40), 1)
	_stripes(Rect2(0, 1, span.x, 8), BRASS)
	_stripes(Rect2(0, span.y - 9, span.x, 8), BRASS)
	for y in [8.0, span.y - 8.0]:
		_panel(Rect2(span.x / 2 - 10, y - 7, 20, 14), Color("424750"), 1)
		_lamp(Rect2(span.x / 2 - 4, y - 3, 8, 6), AMBER)
	if arc_preview and fmod(seconds, 4.8) > 4.45:
		var sparks := PackedVector2Array([Vector2(span.x / 2, 13)])
		for y in range(25, int(span.y) - 13, 13):
			var jitter := float(posmod(y * 17 + last_frame * 13, 29) - 14)
			sparks.append(Vector2(span.x / 2 + jitter, y))
		sparks.append(Vector2(span.x / 2, span.y - 13))
		draw_polyline(sparks, Color(0.32, 0.66, 1.0, 0.30), 6)
		draw_polyline(sparks, Color("c8ecff"), 2)

func _draw_door() -> void:
	var half := span * 0.5
	var opened := kind == "entry" or last_door_state
	if not opened:
		_panel(Rect2(-half, span), Color("555653"), 0)
		for y in range(int(-half.y) + 16, int(half.y) - 14, 16):
			draw_rect(Rect2(-half.x + 5, y, span.x - 10, 10), Color("3b4249"))
			draw_line(Vector2(-half.x + 6, y), Vector2(half.x - 6, y), EDGE.darkened(0.32), 1)
		draw_line(Vector2(-half.x, 0), Vector2(half.x, 0), INK, 2)
		_lamp(Rect2(-4, -4, 8, 8), tint)
	for side in [-1, 1]:
		var end_y: float = side * (half.y - 9)
		var post := Rect2(-half.x - 3, end_y - 9, span.x + 6, 18)
		_panel(post, Color("6d4b43"), 3)
		draw_line(Vector2(post.position.x + 3, end_y + 6), Vector2(post.end.x - 3, end_y + 6), Color("b18368"), 1)
		_lamp(Rect2(-half.x + 5, end_y - 3, span.x - 10, 6), tint)
	if opened:
		for side in [-1, 1]:
			var edge: float = side * half.x
			draw_line(Vector2(edge, -half.y + 18), Vector2(edge, half.y - 18), Color("67433c"), 2)

func _draw_socket() -> void:
	var half := span * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(-half.x, -half.y + 27), Vector2(-half.x + 24, -half.y),
		Vector2(half.x - 20, -half.y), Vector2(half.x, -half.y + 22), Vector2(half.x, half.y - 12),
		Vector2(half.x - 19, half.y + 13), Vector2(-half.x + 15, half.y + 13),
		Vector2(-half.x, half.y - 8)]), Color("39252a"))
	draw_rect(Rect2(-half + Vector2(14, 10), span - Vector2(28, 20)), Color("564f49"))
	draw_rect(Rect2(-half + Vector2(21, 18), span - Vector2(42, 36)), Color("221a20"))
	for i in range(-3, 4):
		var y := float(i * 38)
		draw_rect(Rect2(-half.x - 9, y - 12, span.x + 25, 24), Color("462e2f"))
		draw_rect(Rect2(-half.x - 7, y - 7, span.x + 22, 7), Color("764a40"))
	for x in [-half.x + 6.0, half.x - 23.0]:
		_panel(Rect2(x, -half.y + 5, 18, span.y - 9), Color("625952"), 5)
		draw_line(Vector2(x + 6, -half.y + 8), Vector2(x + 6, half.y - 8), EDGE.darkened(0.25), 2)
		for y in range(int(-half.y) + 15, int(half.y) - 9, 22):
			_bolt(Vector2(x + 11, y))
	for y in [-half.y + 10.0, half.y - 24.0]:
		_panel(Rect2(-half.x + 7, y, span.x - 14, 15), Color("525456"), 4)
		_lamp(Rect2(-half.x + 24, y + 4, 20, 4), AMBER)

func _draw_dock_flange() -> void:
	var half := span * 0.5
	_panel(Rect2(-half, span), Color("524749"), 4)
	for x in [-half.x + 4.0, half.x - 6.0]:
		draw_rect(Rect2(x, -half.y + 3.0, 3.0, span.y - 6.0), Color("242830"))
		draw_rect(Rect2(x + 3.0, -half.y + 3.0, 1.0, span.y - 6.0), EDGE.darkened(0.26))
	for y in range(int(-half.y + 7.0), int(half.y - 4.0), 12):
		_bolt(Vector2(-1, y))
