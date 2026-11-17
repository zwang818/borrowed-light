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
	if is_instance_valid(door):
		if door.is_open != last_door_state:
			last_door_state = door.is_open
			queue_redraw()
		return
	seconds += delta
	var frame := int(seconds * 14)
	if frame != last_frame:
		last_frame = frame
		queue_redraw()

func track_door(value: Node2D) -> void:
	door = value
	last_door_state = door.is_open
	set_process(true)
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
		"wall_emitter":
			_draw_emitter()
		"ground_electrode":
			_draw_electrode()
		"isolation_gate", "service_hatch", "service_exit":
			_draw_defense_frame()
		"inspection_window":
			_draw_inspection_window()
		"service_lamp":
			_draw_service_lamp()
		"service_cover":
			_draw_service_cover()
		"service_seam_hint":
			_lamp(Rect2(12, -19, 3, 38), Color("e5b887"))
		"protocol_dials":
			_draw_protocol_dials()
		"protocol_reader":
			_draw_protocol_reader()
		"protocol_window":
			_draw_protocol_window()
		"protocol_gate_frame":
			_draw_protocol_gate_frame()
		"protocol_gate_leaf":
			_draw_protocol_gate_leaf()
		"protocol_cover":
			_draw_protocol_cover()
		"spinal_fluid_tap":
			_draw_spinal_fluid_tap()


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

func _draw_emitter() -> void:
	var copper := Color("a76544")
	_panel(Rect2(-28, -17, 48, 34), Color("66413c"))
	_panel(Rect2(-25, -12, 22, 24), Color("474042"), 2)
	for x in [-20.0, -13.0]:
		draw_rect(Rect2(x, -7, 3, 14), INK)
	_panel(Rect2(-6, -9, 31, 18), copper, 3)
	draw_rect(Rect2(15, -13, 12, 26), Color("402b31"))
	_panel(Rect2(20, -13, 12, 26), Color("6d5250"), 2)
	draw_rect(Rect2(28, -8, 6, 16), INK)
	draw_rect(Rect2(31, -5, 3, 10), Color("c27d63"))
	_lamp(Rect2(-20, -14, 7, 3), AMBER)

func _draw_electrode() -> void:
	var radius := span.x * 0.5
	draw_circle(Vector2(2, 4), radius + 2.0, Color("2c2027"))
	draw_circle(Vector2.ZERO, radius, Color("4a383b"))
	_ring(Vector2.ZERO, radius - 3.0, 2.0, Color("b3875c"))
	_ring(Vector2.ZERO, radius - 11.0, 4.0, Color("24252e"))
	for i in range(8):
		var radial := Vector2.from_angle(TAU * i / 8.0)
		_bolt(radial * (radius - 7.0))
		draw_line(radial * (radius - 23.0), radial * (radius - 14.0), Color("a16858"), 3)
	var hub := floorf(radius * 0.40)
	_panel(Rect2(-hub, -hub, hub * 2, hub * 2), Color("684640"), 2)
	_lamp(Rect2(-hub * 0.5, -2, hub, 4), Color("fead7f"))

func _draw_defense_frame() -> void:
	var half := span * 0.5
	var shutter := kind == "isolation_gate"
	var post := 23.0 if shutter else 14.0
	var closed := is_instance_valid(door) and not last_door_state
	var steel := Color("674443") if shutter else Color("473b43")
	var lamp := Color("ffac6c") if shutter else Color("94bac0")
	draw_rect(Rect2(-half, span), Color("2c2129"))
	_panel(Rect2(-half + Vector2(3, 3), span - Vector2(6, 6)), steel if closed else Color("373037"), 3)
	for x in [-half.x + 3, half.x - 5]:
		draw_rect(Rect2(x, -half.y + post, 2, span.y - post * 2), Color("a27360"))
	if closed:
		for y in range(ceili(-half.y + post), floori(half.y - post), 16):
			draw_rect(Rect2(-half.x + 6, y, span.x - 12, 7), steel.lightened(0.12))
			draw_rect(Rect2(-half.x + 6, y + 7, span.x - 12, 2), INK)
		_lamp(Rect2(-3, -11, 6, 22), lamp)
	for side in [-1, 1]:
		var y: float = side * (half.y - post * 0.4)
		_panel(Rect2(-half.x - 5, y - post * 0.5, span.x + 10, post), steel, 3)
		_lamp(Rect2(-half.x + 4, y - 3, span.x - 8, 5), lamp)

func _draw_inspection_window() -> void:
	var half := span.x * 0.5
	_panel(Rect2(-half, -13, span.x, 26), Color("4e3e46"), 3)
	draw_rect(Rect2(-half + 6, -8, span.x - 12, 16), Color("482b3b"))
	draw_rect(Rect2(-half + 6, -6, span.x - 12, 10), Color("a26066"))
	draw_rect(Rect2(-half + 7, -6, span.x - 14, 2), Color("d69385"))
	draw_rect(Rect2(-half + 7, 3, span.x - 14, 2), Color("693f4f"))
	for x in range(ceili(-half + 12), floori(half - 8), 22):
		draw_rect(Rect2(x, -9, 4, 18), Color("342630"))
		draw_rect(Rect2(x, -9, 1, 16), Color("867079"))

func _draw_service_lamp() -> void:
	var pool := PackedVector2Array([Vector2(-9, 1), Vector2(9, 1), Vector2(26, 32), Vector2(-26, 32)])
	draw_colored_polygon(pool, Color(0.82, 0.59, 0.36, 0.10))
	_panel(Rect2(-12, -6, 24, 12), Color("51413b"), 2)
	_lamp(Rect2(-7, -2, 14, 4), Color("e1b684"))

func _draw_service_cover() -> void:
	var half := span.y * 0.5
	var plate := Color("77564e")
	# Local +X faces the public deck; the skirt hides the steel edge above the shaft.
	draw_rect(Rect2(-33, -half - 5, 46, span.y + 10), Color("34252d"))
	draw_rect(Rect2(-30, -half - 4, 41, span.y + 8), Color("55393c"))
	_panel(Rect2(-25, -half - 3, 44, span.y + 6), plate, 2)
	draw_rect(Rect2(12, -half + 3, 3, span.y - 6), Color("5a3e3d"))
	for end in [-1.0, 1.0]:
		var edge: float = end * (half - 8.0)
		draw_rect(Rect2(-26, edge - 4, 38, 8), Color("63454a"))
		_bolt(Vector2(-15, edge - 1))
		_bolt(Vector2(4, edge - 1))
	# The inactive seam lines up with the ordinary armored lip.
	draw_rect(Rect2(16, -half + 4, 2, span.y - 8), Color("aa7c65"))

func _draw_protocol_dials() -> void:
	_panel(Rect2(-38, -28, 76, 47), Color("684746"), 5)
	_panel(Rect2(-31, -25, 62, 43), Color("414b51"), 3)
	_panel(Rect2(-24, -21, 48, 10), Color("23323c"), 1)
	draw_rect(Rect2(-18, -17, 36, 2), Color("5f7e86"))
	for x: float in [-18.0, 0.0, 18.0]:
		_panel(Rect2(x - 7, -5, 14, 16), Color("522f36"), 2)
		draw_rect(Rect2(x - 2, -3, 4, 10), INK)
		draw_rect(Rect2(x - 4, 2, 8, 4), Color("c29465"))
	_lamp(Rect2(28, -15, 3, 8), Color("9cbfbc"))

func _draw_protocol_reader() -> void:
	_panel(Rect2(-15, -18, 30, 33), Color("70514b"), 4)
	_panel(Rect2(-11, -16, 22, 25), Color("3d4149"), 2)
	draw_rect(Rect2(-8, -10, 16, 12), Color("233b46"))
	draw_rect(Rect2(-5, -8, 10, 2), Color("66868c"))
	_lamp(Rect2(-4, 5, 8, 3), Color("a3bdba"))

func _draw_protocol_window() -> void:
	var half := span.x * 0.5
	_panel(Rect2(-half, -10, span.x, 20), Color("593e44"), 3)
	for x in range(ceili(-half + 8), floori(half - 30), 46):
		draw_rect(Rect2(x, -6, 39, 12), Color("293a43"))
		draw_rect(Rect2(x + 2, -5, 34, 3), Color("6e8a8d"))
		draw_line(Vector2(x + 23, 4), Vector2(x + 31, -2), Color("536a73"), 1)
		_bolt(Vector2(x + 40, -1))

func _draw_protocol_gate_frame() -> void:
	var half := span.y * 0.5
	draw_rect(Rect2(-23, -half, 46, span.y), Color("3b2d33"))
	for x: float in [-23.0, 19.0]:
		draw_rect(Rect2(x, -half + 9, 4, span.y - 18), Color("b98b62"))
		draw_rect(Rect2(x + 1, -half + 9, 1, span.y - 18), Color("e0b383"))
	for y in range(ceili(-half + 20), floori(half - 16), 18):
		draw_rect(Rect2(-13, y, 26, 5), Color("24242d"))
		draw_rect(Rect2(-12, y + 5, 24, 1), Color("796062"))
	for side: float in [-1.0, 1.0]:
		var y := side * (half - 12.0)
		_panel(Rect2(-30, y - 12, 60, 24), Color("70484a"), 6)
		_panel(Rect2(-15, y - 8, 30, 16), Color("3c444b"), 2)
		_lamp(Rect2(-9, y - 2, 18, 4), Color("9dbfbd"))

func _draw_protocol_gate_leaf() -> void:
	if last_door_state:
		return
	var half := span.y * 0.5
	_panel(Rect2(-16, -half + 11, 32, span.y - 22), Color("685052"), 4)
	for y in range(ceili(-half + 18), floori(half - 14), 18):
		draw_rect(Rect2(-11, y, 22, 8), Color("343641"))
		draw_line(Vector2(-10, y + 2), Vector2(8, y + 2), Color("796461"), 1)
	_lamp(Rect2(-3, -12, 6, 24), AMBER)

func _draw_protocol_cover() -> void:
	var half := span * 0.5
	_panel(Rect2(-half + Vector2(4, 4), span - Vector2(8, 8)), Color("734e44"), 6)
	_panel(Rect2(-half + Vector2(12, 11), span - Vector2(24, 22)), Color("3d444d"), 3)
	for y in range(ceili(-half.y + 16), floori(half.y - 13), 17):
		draw_rect(Rect2(-half.x + 15, y, span.x - 30, 9), Color("735046"))
		draw_rect(Rect2(-half.x + 16, y, span.x - 32, 2), Color("ba8a65"))
	_lamp(Rect2(-half.x + 7, -14, 3, 28), Color("c49665"))

func _draw_spinal_fluid_tap() -> void:
	_panel(Rect2(-34, -27, 68, 55), Color("664544"), 5)
	_panel(Rect2(-29, -23, 58, 46), Color("3c434a"), 3)
	# Glass feed tube, with the fluid visible between its end caps and highlights.
	_panel(Rect2(-23, -19, 22, 37), Color("775950"), 2)
	draw_rect(Rect2(-19, -15, 14, 29), Color("202932"))
	draw_rect(Rect2(-17, -6, 10, 19), Color("ad5b4c"))
	draw_rect(Rect2(-16, -6, 7, 2), Color("e79667"))
	draw_rect(Rect2(-17, -13, 2, 26), Color("8ea2a0"))
	draw_rect(Rect2(-8, -13, 1, 23), Color("4b6167"))
	for y: float in [-15.0, 13.0]:
		draw_rect(Rect2(-21, y, 18, 4), Color("9c7159"))

	_panel(Rect2(3, -18, 22, 21), Color("28252d"), 1)
	for index in range(4):
		var level := Color("e3ac74") if index < 2 else Color("62544d")
		draw_rect(Rect2(6 + index * 4, -13, 3, 11), level)
	draw_rect(Rect2(6, 6, 16, 11), Color("76514b"))
	_ring(Vector2(14, 11), 5.0, 2.0, Color("c39c76"))
	draw_circle(Vector2(14, 11), 2.2, INK)
	_lamp(Rect2(25, 9, 3, 6), Color("e9ba81"))
