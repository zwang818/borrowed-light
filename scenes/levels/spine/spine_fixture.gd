extends Node2D
## Draws individual 2D fittings at their world size. Collision stays on the graybox.
const INK := Color("111920")
const STEEL := Color("4f555a")
const EDGE := Color("9b9084")
const BRASS := Color("bb8846")
const AMBER := Color("ffd589")
const CYAN := Color("a8e3e7")

var kind := ""
var span := Vector2.ZERO
var seconds := 0.0
var arc_preview := false
var door: Node2D
var last_frame := -1
var last_door_state := false

func _ready() -> void:
	set_process(kind == "seam" and arc_preview)

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
		"barrier":
			_draw_barrier()
		"seam":
			_draw_seam()
		"dock_flange":
			_draw_dock_flange()
		"wall_emitter":
			_draw_emitter()
		"ground_electrode":
			_draw_electrode()
		"isolation_gate":
			_draw_defense_frame()
		"inspection_window":
			_draw_inspection_window()
		"service_lamp":
			_draw_service_lamp()


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
