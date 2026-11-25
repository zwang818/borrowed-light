extends Node2D
## World-space prop geometry. The map and gameplay controllers own all hitboxes.
const INK := Color("261a20")
const SIDE := Color("3c252e")
const RED := Color("673842")
const RUST := Color("814b52")
const STEEL := Color("514044")
const BRASS := Color("b68653")
const COPPER := Color("a96142")
const AMBER := Color("f2bd75")
const TEAL := Color("9ad4c7")
const GLASS := Color("25363b")
const SOLID_CASINGS := {
	&"record": [Rect2(-25, -18, 50, 38), 5.0, 6.0],
	&"gate_reader": [Rect2(-12, -15, 24, 33), 4.0, 6.0],
	&"protocol_console": [Rect2(-37, -25, 74, 46), 7.0, 7.0],
	&"blueprint": [Rect2(-36, -20, 72, 39), 6.0, 7.0],
	&"fluid": [Rect2(-33, -25, 64, 50), 6.0, 6.0],
	&"exit_console": [Rect2(-27, -20, 54, 41), 7.0, 7.0],
}
const RECORD_KEYBOARD := Rect2(-13, 22, 26, 5)
const CHECKPOINT_PLATE := Rect2(-13, -8, 25, 16)
const CHECKPOINT_LANTERN_BASE := Rect2(-14, -11, 28, 21)
const CHECKPOINT_LANTERN_OFFSET := Vector2(-28, 1)
const CHECKPOINT_CABLE := [Vector2(-13, 1), Vector2(-18, 1), Vector2(-22, -3)]

var kind: StringName
var span := Vector2.ZERO
var active := false
var pressure := 0
var fill_step := -1
var route := PackedVector2Array()
var stop_index := 0
var gate: Node2D
var gate_gap := 0

func _ready() -> void:
	set_process(false)

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	queue_redraw()

func set_fluid_state(fraction: float, progress: float) -> void:
	var segments := ceili(clampf(fraction, 0.0, 1.0) * 4.0)
	var step := -1 if progress < 0.0 else roundi(clampf(progress, 0.0, 1.0) * 32.0)
	if pressure == segments and fill_step == step:
		return
	pressure = segments
	fill_step = step
	queue_redraw()

func set_route(points: PackedVector2Array, pause_index: int) -> void:
	route = points
	stop_index = pause_index
	queue_redraw()

func track_door(value: Node2D) -> void:
	gate = value
	set_process(true)
	_update_aperture()

func _process(_delta: float) -> void:
	_update_aperture()

func _update_aperture() -> void:
	if not is_instance_valid(gate):
		set_process(false)
		return
	var aperture: Variant = gate.get("aperture")
	var amount := float(aperture) if aperture != null else float(gate.is_open)
	var gap := roundi(amount * _gate_half())
	if gate_gap != gap or active != gate.is_open:
		gate_gap = gap
		active = gate.is_open
		queue_redraw()

func _draw() -> void:
	match kind:
		&"record": _draw_record()
		&"blueprint": _draw_blueprint()
		&"return_duct": _draw_return_duct()
		&"exit_console": _draw_exit_console()
		&"valve": _draw_valve()
		&"gate_cover": _draw_gate_cover()
		&"service_cover", &"service_threshold", &"service_hint": _draw_service()
		&"checkpoint": _draw_checkpoint()
		&"observation": _draw_observation()
		&"protocol_console": _draw_protocol_console()
		&"demo_reader": _draw_demo_reader()
		&"gate_reader": _draw_gate_reader()
		&"fluid": _draw_fluid()
		&"authorization_gate", &"exit_gate": _draw_gate()
		&"receiver_latch": _draw_receiver_latch()
		&"receiver_bulkhead": _draw_receiver_bulkhead()

func solid_outline() -> PackedVector2Array:
	var casing: Array = SOLID_CASINGS[kind]
	var silhouette := _armor_silhouette(casing[0], casing[1], casing[2])
	if kind == &"record":
		var keyboard := _armor_outline(RECORD_KEYBOARD, 2.0)
		for corner in keyboard:
			silhouette.append(corner + Vector2(2, 2))
	return _outer_outline(silhouette)

func checkpoint_contact_outlines() -> Array[PackedVector2Array]:
	var plate := _armor_silhouette(CHECKPOINT_PLATE, 4.0, 1.0)
	plate.append_array(PackedVector2Array(CHECKPOINT_CABLE))
	var lantern := _armor_silhouette(CHECKPOINT_LANTERN_BASE, 5.0, 4.0)
	lantern.append_array(PackedVector2Array([Vector2(-8, -29), Vector2(0, -35), Vector2(8, -29),
		Vector2(13, -8), Vector2(-12, -6)]))
	return [_outer_outline(plate), Transform2D(0.0, CHECKPOINT_LANTERN_OFFSET) * _outer_outline(lantern)]

func _outer_outline(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	hull.resize(hull.size() - 1) # The hull repeats its first vertex at the end.
	return hull

func interaction_position(clearance: float) -> Vector2:
	var casing: Array = SOLID_CASINGS[kind]
	var box: Rect2 = casing[0]
	# The tall gate reader is approached from the incoming side of the corridor.
	if box.size.y > box.size.x:
		return to_global(Vector2(box.position.x - clearance, box.get_center().y))
	var front: float = box.end.y + casing[2]
	if kind == &"record":
		front = RECORD_KEYBOARD.end.y + 2.0
	return to_global(Vector2(box.get_center().x + 2.0, front + clearance))

func _draw_solid_casing() -> void:
	var casing: Array = SOLID_CASINGS[kind]
	_armor(casing[0], RED, casing[1], casing[2])

func _armor_outline(box: Rect2, bevel: float) -> PackedVector2Array:
	var at := box.position
	var end := box.end
	return PackedVector2Array([at + Vector2(bevel, 0), Vector2(end.x - bevel, at.y),
		Vector2(end.x, at.y + bevel), Vector2(end.x, end.y - bevel),
		end - Vector2(bevel, 0), Vector2(at.x + bevel, end.y),
		Vector2(at.x, end.y - bevel), Vector2(at.x, at.y + bevel)])

func _armor_silhouette(box: Rect2, bevel: float, depth: float) -> PackedVector2Array:
	var outline := _armor_outline(box, bevel)
	outline.append_array(Transform2D(0.0, Vector2(2, depth)) * outline)
	return outline

func _armor(box: Rect2, paint: Color, bevel: float, depth: float) -> void:
	var at := box.position
	var end := box.end
	var outline := _armor_outline(box, bevel)
	var offset := Vector2(2.0, depth)
	draw_colored_polygon(Transform2D(0.0, offset) * outline, INK)
	if depth > 0.0:
		_cast_side(outline[3], outline[4], offset, paint.darkened(0.59))
		_cast_side(outline[4], outline[5], offset, paint.darkened(0.48))
		_cast_side(outline[5], outline[6], offset, paint.darkened(0.52))
	draw_colored_polygon(outline, paint)
	var border := outline.duplicate()
	border.append(outline[0])
	draw_polyline(border, INK, 1.0)
	draw_polyline(PackedVector2Array([outline[7], outline[0], outline[1], outline[2]]),
		paint.lerp(Color("d1a282"), 0.36), 1.0)
	draw_line(outline[5] - Vector2(0, 1), outline[4] - Vector2(0, 1), paint.darkened(0.30), 1)
	if box.size.x > 14 and box.size.y > 14:
		for x in [at.x + 5, end.x - 6]:
			for y in [at.y + 5, end.y - 6]:
				_bolt(Vector2(x, y))
		draw_line(outline[0] + Vector2(0, 2), outline[1] + Vector2(0, 2),
			paint.darkened(0.18))
		for fraction: float in [0.18, 0.41, 0.76]:
			var x := floorf(lerpf(at.x, end.x, fraction))
			var scuff := Vector2(x, end.y - 4)
			draw_rect(Rect2(scuff, Vector2(4, 1)), paint.lerp(BRASS, 0.32))
			draw_rect(Rect2(scuff + Vector2(1, 1), Vector2(2, 1)), paint.darkened(0.25))

func _cast_side(from: Vector2, to: Vector2, offset: Vector2, color: Color) -> void:
	if absf((to - from).cross(offset)) < 0.01:
		return
	draw_colored_polygon(PackedVector2Array([from, to, to + offset, from + offset]), color)
	if offset.y >= 4:
		draw_line(from + offset * 0.30, to + offset * 0.30,
			color.lerp(Color("9b6658"), 0.30), 1.0)
		draw_line(from + offset * 0.82, to + offset * 0.82, INK, 1.0)

func _bolt(at: Vector2) -> void:
	draw_rect(Rect2(at - Vector2(2, 1), Vector2(4, 3)), INK)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 3)), BRASS.darkened(0.29))
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 1)), Color("d6aa77"))
	draw_rect(Rect2(at, Vector2(1, 1)), INK)

func _lamp(box: Rect2, color: Color) -> void:
	draw_rect(box.grow(2), INK)
	draw_rect(box.grow(1), color.darkened(0.55))
	draw_rect(box, color)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), color.lightened(0.30))

func _glass(box: Rect2) -> void:
	draw_rect(box.grow(3), INK)
	draw_rect(box.grow(1), Color("657173"))
	draw_rect(box, GLASS)
	draw_rect(Rect2(box.position + Vector2(1, 1), Vector2(box.size.x - 2, 1)), Color("52666b"))
	draw_rect(Rect2(box.end - Vector2(box.size.x, 1), Vector2(box.size.x, 1)), Color("172429"))
	if box.size.x > 15.0 and box.size.y > 10.0:
		for y in range(4, floori(box.size.y) - 2, 3):
			draw_line(box.position + Vector2(2, y), box.position + Vector2(box.size.x - 2, y),
				Color("3b585e"), 1.0)

func _ring(at: Vector2, radius: float, color: Color, sides := 16) -> void:
	var edge := PackedVector2Array()
	for i in range(sides):
		edge.append((at + Vector2.from_angle(TAU * float(i) / sides) * radius).round())
	draw_colored_polygon(edge, color)

func _coupling(at: Vector2, radius: float) -> void:
	_ring(at + Vector2(1, 2), radius + 2, INK)
	_ring(at, radius, BRASS)
	_ring(at + Vector2(0, 1), radius - 3, COPPER.darkened(0.49))
	_ring(at + Vector2(0, 1), radius - 5, INK)
	draw_arc(at, radius - 1, PI * 0.90, PI * 1.74, 9, Color("e0b386"), 1)
	draw_arc(at + Vector2(0, 1), radius - 3, 0.12, PI * 0.8, 8, Color("935d45"), 1)
	for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var lug: Vector2 = (at + axis * (radius - 1.0)).round()
		draw_rect(Rect2(lug - Vector2(2, 2), Vector2(4, 4)), BRASS.lightened(0.13))

func _draw_record() -> void:
	_draw_solid_casing()
	_armor(Rect2(-21, -20, 42, 33), STEEL, 4, 2)
	for x in [-24, 21]:
		draw_line(Vector2(x, -8), Vector2(x, 10), BRASS.darkened(0.24), 1)
		_bolt(Vector2(x + 1, 13))
	for y: float in [-14, -2]:
		_glass(Rect2(-14, y, 28, 7))
		draw_line(Vector2(-11, y + 3), Vector2(8, y + 3), TEAL.darkened(0.28))
		draw_line(Vector2(-11, y + 5), Vector2(2, y + 5), Color("50767a"))
	_armor(Rect2(-12, 10, 24, 15), COPPER.darkened(0.24), 3, 3)
	draw_rect(Rect2(-9, 12, 18, 11), Color("524039"))
	for y in range(14, 22, 2):
		draw_rect(Rect2(-8, y, 16, 1), BRASS.lightened(0.11))
		draw_rect(Rect2(4, y, 2, 1), Color("836349"))
	_armor(RECORD_KEYBOARD, BRASS, 2, 2)
	draw_rect(Rect2(-4, 23, 8, 2), INK)

func _draw_blueprint() -> void:
	_draw_solid_casing()
	for x: float in [-25.0, 12.0]:
		_armor(Rect2(x - 8, -16, 21, 30), BRASS, 3, 2)
		draw_rect(Rect2(x - 5, -13, 15, 24), Color("b29a79"))
		draw_line(Vector2(x - 4, 10), Vector2(x + 8, 10), Color("8c7560"))
		var sketch := PackedVector2Array([Vector2(x - 3, -6), Vector2(x + 1, -9),
			Vector2(x + 7, -7), Vector2(x + 8, -3), Vector2(x + 4, 0),
			Vector2(x + 2, 4), Vector2(x - 1, 3), Vector2(x, -1), Vector2(x - 3, -6)])
		draw_polyline(sketch, Color("665350"), 1)
		draw_rect(Rect2(x - 3, 7, 7, 1), Color("7e6657"))
		_armor(Rect2(x - 2, -17, 6, 5), BRASS.lightened(0.14), 1, 1)
	_glass(Rect2(-12, -13, 24, 21))
	var arm := PackedVector2Array([Vector2(-8, -4), Vector2(-4, -8), Vector2(0, -6),
		Vector2(8, -6), Vector2(9, -1), Vector2(3, 0), Vector2(1, 3),
		Vector2(-6, 2), Vector2(-8, -4)])
	draw_polyline(arm, TEAL)
	_ring(Vector2(-4, -3), 2, TEAL, 8)
	draw_rect(Rect2(-12, 13, 24, 7), INK)
	for x in [-7, 0, 7]:
		_lamp(Rect2(x - 1, 13, 2, 3), AMBER.darkened(0.18))

func _draw_return_duct() -> void:
	_ring(Vector2(2, 4), 33, INK, 8)
	_ring(Vector2.ZERO, 32, RED, 8)
	_ring(Vector2(0, -1), 26, BRASS)
	_ring(Vector2(0, -1), 24, COPPER)
	draw_arc(Vector2(0, -1), 24, PI * 0.86, PI * 1.91, 20, Color("d99c70"), 2)
	_ring(Vector2(0, -1), 21, INK)
	for i in range(6):
		var direction := TAU * float(i) / 6.0
		var tip := Vector2.from_angle(direction + 0.60) * 9
		var heel := Vector2.from_angle(direction) * 20
		var edge := Vector2.from_angle(direction + 0.99) * 20
		draw_colored_polygon(PackedVector2Array([heel, edge, tip,
			Vector2.from_angle(direction - 0.40) * 9]), STEEL.lightened(float(i % 3) * 0.06))
		draw_line(edge, tip, INK, 1.5)
		draw_line(edge * 0.92, tip * 1.12, Color("8f6c5e"), 1)
	for i in range(8):
		_bolt((Vector2.from_angle(TAU * (i + 0.5) / 8.0) * 28).round())
	_armor(Rect2(-9, 24, 18, 9), RUST, 2, 3)
	draw_polyline(PackedVector2Array([Vector2(-5, 26), Vector2(0, 30), Vector2(5, 26)]), AMBER, 2)

func _draw_exit_console() -> void:
	for x: float in [-16.0, 15.0]:
		var lead := PackedVector2Array([Vector2(x, -12), Vector2(x, -24),
			Vector2(x + 9, -32), Vector2(x + 15, -32)])
		draw_polyline(lead, INK, 8.0)
		draw_polyline(lead, COPPER, 6.0)
		draw_polyline(lead, COPPER.lightened(0.3), 2.0)
	_draw_solid_casing()
	for x in [-24, 20]:
		_armor(Rect2(x, -13, 5, 31), RUST, 1, 2)
		_bolt(Vector2(x + 2, 12))
	_armor(Rect2(-20, -14, 40, 28), STEEL, 4, 3)
	_coupling(Vector2(-10, -2), 8)
	_armor(Rect2(2, -10, 16, 16), BRASS, 2, 1)
	draw_rect(Rect2(5, -7, 10, 8), INK)
	draw_rect(Rect2(12, -1, 3, 4), BRASS.darkened(0.36))
	_lamp(Rect2(-11, 16, 22, 3), AMBER)

func _draw_valve() -> void:
	var half := span * 0.5
	# The chamfer and side faces are inset from the original hitbox in local space.
	_armor(Rect2(-half + Vector2(2, 2), span - Vector2(5, 13)), RED, 7, 9)
	_armor(Rect2(-half + Vector2(6, 7), span - Vector2(13, 23)), STEEL, 5, 2)
	_armor(Rect2(-20, -22, 40, 43), INK, 4, 3)
	for y: float in [-half.y + 11, half.y - 19]:
		_armor(Rect2(-16, y - 3, 32, 6), Color("48323a"), 2, 2)
		for x: float in [-11.0, 11.0]:
			_bolt(Vector2(x, y))
	for x: float in [-half.x + 4, half.x - 17]:
		_armor(Rect2(x, -half.y + 3, 13, span.y - 17), RUST, 4, 6)
		_armor(Rect2(x + 2, -half.y + 7, 9, span.y - 25), RED, 3, 2)
		for y: float in [-half.y + 13, half.y - 24]:
			_bolt(Vector2(x + 6, y))
		_armor(Rect2(x - 1, -8, 12, 15), BRASS.darkened(0.18), 3, 2)
		draw_rect(Rect2(x + 1, -5, 8, 8), STEEL)
		draw_line(Vector2(x + 2, -4), Vector2(x + 7, -4), Color("b48564"))
		_bolt(Vector2(x + 5, 1))
	var hub := Vector2(0, -2)
	_ring(hub + Vector2(1, 3), 19, INK, 20)
	_ring(hub, 18, COPPER.darkened(0.26), 20)
	_ring(hub - Vector2(0, 1), 17, COPPER, 20)
	_ring(hub + Vector2(0, 1), 13, Color("472b2e"), 20)
	_ring(hub + Vector2(0, 2), 10, Color("2e2529"), 16)
	draw_arc(hub - Vector2(0, 1), 16, PI * 0.94, PI * 1.78, 12, Color("de9a6d"), 1.6)
	draw_arc(hub, 16, PI * 0.12, PI * 0.78, 11, Color("63372e"), 1.4)
	for index in range(3):
		var direction := Vector2.from_angle(TAU * float(index) / 3.0 + 0.45)
		var start := (hub + direction * 4).round()
		var tip := (hub + direction * 15).round()
		draw_line(start + Vector2(0, 2), tip + Vector2(0, 2), INK, 4)
		draw_line(start, tip, COPPER, 4)
		draw_line(start - Vector2(0, 1), tip - Vector2(0, 1), Color("cb9064"), 1)
	_ring(hub + Vector2(0, 1), 6, INK, 8)
	_ring(hub, 5, BRASS, 8)
	_bolt(hub)

func _draw_gate_cover() -> void:
	var half := span * 0.5
	_armor(Rect2(-half + Vector2(2, 2), span - Vector2(5, 13)), RED, 7, 9)
	_armor(Rect2(-half + Vector2(8, 8), span - Vector2(17, 25)), STEEL, 4, 2)
	for y in range(ceili(-half.y + 16), floori(half.y - 22), 17):
		_armor(Rect2(-half.x + 11, y, span.x - 23, 12), RED, 3, 2)
		draw_rect(Rect2(-half.x + 14, y + 2, span.x - 29, 2), Color("94664f"))
		for x in [-half.x + 16, half.x - 17]:
			_bolt(Vector2(x, y + 6))
	for x in [-half.x + 3, half.x - 8]:
		draw_line(Vector2(x, -half.y + 13), Vector2(x, half.y - 18), BRASS.darkened(0.16), 2)

func _draw_service() -> void:
	var half := span.y * 0.5
	match kind:
		&"service_cover":
			_armor(Rect2(-19, -half - 3, 35, span.y + 6), Color("775952"), 4, 4)
			_armor(Rect2(-14, -half + 4, 26, span.y - 8), Color("866963"), 3, 0)
			for y: float in [-half + 9, half - 17]:
				_armor(Rect2(-20, y, 11, 10), STEEL, 2, 1)
				_bolt(Vector2(-15, y + 5))
			for y in range(ceili(-half + 19.0), floori(half - 18.0), 16):
				draw_rect(Rect2(-12, y, 3, 7), Color("725653"))
				draw_rect(Rect2(-11, y, 1, 6), Color("a0796c"))
			draw_line(Vector2(12, -half + 7), Vector2(12, half - 7), Color("a47a68"), 1)
		&"service_hint":
			_lamp(Rect2(11, -10, 3, 20), AMBER)
		&"service_threshold":
			for x: float in [-8.0, 7.0]:
				draw_rect(Rect2(x, -half + 4, 2, span.y - 8), BRASS.darkened(0.42))
			_armor(Rect2(-17, -half - 17, 33, 24), RED, 4, 5)
			_armor(Rect2(-16, half - 7, 30, 24), RUST, 4, 5)
			_armor(Rect2(-10, half - 5, 18, 15), STEEL, 3, 2)
			_lamp(Rect2(-6, -half - 8, 12, 3), AMBER.darkened(0.21))

func _draw_checkpoint() -> void:
	# A flush pressure plate marks the activation point. The lantern is offset
	# from the walking line, so the hero can step onto the plate cleanly.
	_armor(CHECKPOINT_PLATE, Color("52403e"), 4, 1)
	_armor(Rect2(-8, -5, 15, 10), Color("785b4d"), 2, 0)
	var signal_color := TEAL if active else Color("bd6f56")
	for x in [-5, 0, 5]:
		draw_rect(Rect2(x - 1, -1, 2, 2), signal_color)
	draw_polyline(PackedVector2Array(CHECKPOINT_CABLE), Color("76534a"), 3)
	draw_set_transform(CHECKPOINT_LANTERN_OFFSET)
	_armor(CHECKPOINT_LANTERN_BASE, RED, 5, 4)
	_armor(Rect2(-11, -10, 22, 16), RUST, 4, 2)
	_bolt(Vector2(-9, 5))
	_bolt(Vector2(9, 5))
	var color := Color("edaa5d") if active else Color("a46047")
	# The enclosure has independent glass faces, bronze ribs and a dark cap.
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-24), Vector2(6,-24),
		Vector2(13,-8), Vector2(4,0), Vector2(-12,-6)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-21), Vector2(-1,-17),
		Vector2(-2,-3), Vector2(-10,-7)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(2,-19), Vector2(6,-22),
		Vector2(11,-8), Vector2(2,-3)]), color.darkened(0.24))
	draw_polyline(PackedVector2Array([Vector2(-7,-18), Vector2(-6,-16), Vector2(-6,-9)]),
		color.lightened(0.39), 2)
	draw_line(Vector2(6,-17), Vector2(7,-11), color.lightened(0.14), 1)
	if active:
		draw_polyline(PackedVector2Array([Vector2(-7,-8), Vector2(-5,-13),
			Vector2(-3,-11), Vector2(-3,-6)]), Color("ffdb8b"), 1)
		draw_line(Vector2(5, -11), Vector2(6, -7), Color("e7b26d"), 1)
	draw_polyline(PackedVector2Array([Vector2(-10,-6), Vector2(-1,-1), Vector2(11,-8)]),
		BRASS.darkened(0.14), 2)
	draw_line(Vector2(0,-21), Vector2(0,-2), BRASS, 3)
	_armor(Rect2(-8, -29, 16, 9), STEEL, 3, 2)
	_ring(Vector2(0,-27), 4, Color("372a2d"), 8)
	draw_arc(Vector2(0,-27), 3, PI, TAU, 7, Color("9b7260"), 1)
	_lamp(Rect2(-2, -25, 4, 2), signal_color)
	draw_set_transform(Vector2.ZERO)

func _draw_observation() -> void:
	var length := span.x
	_armor(Rect2(-length * 0.5, -11, length, 22), RED, 4, 5)
	var width := length * 0.5 - 18.0
	for x: float in [-length * 0.5 + 11.0, 7.0]:
		_glass(Rect2(x, -6, width, 12))
		draw_rect(Rect2(x + 1, -5, width - 2, 9), Color("35494d"))
		draw_rect(Rect2(x + 3, -4, width - 5, 2), Color("526469"))
		draw_rect(Rect2(x + 2, 2, width - 4, 1), Color("27363b"))
		draw_polyline(PackedVector2Array([Vector2(x + 9, 3), Vector2(x + 20, -5),
			Vector2(x + 24, -5)]), Color("73878a"), 1)
	for x: float in [-length * 0.5 + 3.0, -4.0, length * 0.5 - 11.0]:
		_armor(Rect2(x, -12, 8, 24), RUST, 2, 2)
		_bolt(Vector2(x + 4, -6))
		_bolt(Vector2(x + 4, 7))
	_lamp(Rect2(-10, -13, 20, 3), AMBER.darkened(0.18))

func _draw_protocol_console() -> void:
	_draw_solid_casing()
	_armor(Rect2(-32, -25, 64, 33), STEEL, 4, 2)
	for x in [-34, 30]:
		_armor(Rect2(x, -15, 4, 21), BRASS.darkened(0.20), 1, 2)
		_bolt(Vector2(x + 2, -10))
	_glass(Rect2(-27, -20, 54, 25))
	for x in range(-24, 26, 6):
		draw_line(Vector2(x, -19), Vector2(x, 4), Color("35474b"))
	for y in range(-17, 5, 5):
		draw_line(Vector2(-26, y), Vector2(26, y), Color("35474b"))
	if not route.is_empty():
		var points := route.duplicate()
		points.append(points[0])
		var trace := TEAL if active else AMBER
		draw_polyline(points, trace, 1.5)
		draw_rect(Rect2(points[0] - Vector2(2,2), Vector2(4,4)), trace)
		draw_rect(Rect2(points[clampi(stop_index, 0, route.size() - 1)] - Vector2(2,2),
			Vector2(5,5)), TEAL, false, 1)
	for index in range(4):
		var x := -25 + 11 * index
		_armor(Rect2(x, 10, 8, 8), STEEL, 1, 1)
		var at := Vector2(x + 4, 14)
		var direction: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][index]
		draw_line(at - direction, at + direction * 2, BRASS, 1)
		draw_line(at + direction * 2, at + direction.orthogonal(), BRASS, 1)
	_lamp(Rect2(21, 11, 7, 5), TEAL if active else AMBER)

func _draw_demo_reader() -> void:
	_armor(Rect2(-14, -12, 28, 22), RED, 6, 4)
	_armor(Rect2(-11, -11, 22, 11), RUST, 3, 2)
	for x in [-10, 9]:
		_bolt(Vector2(x, -8))
	_glass(Rect2(-6, -4, 12, 10))
	for x: float in [-11.0, 8.0]:
		_armor(Rect2(x, -4, 4, 13), BRASS, 1, 2)
	_lamp(Rect2(-2, -1, 4, 3), TEAL if active else Color("557679"))

func _draw_gate_reader() -> void:
	draw_line(Vector2(3,-12), Vector2(3,-20), INK, 8)
	draw_line(Vector2(3,-12), Vector2(3,-20), COPPER, 5)
	_draw_solid_casing()
	_armor(Rect2(-10, -16, 20, 16), RUST, 3, 2)
	for x in [-10, 9]:
		draw_line(Vector2(x, 2), Vector2(x, 13), Color("956958"), 1)
	for x in [-6, 5]:
		_bolt(Vector2(x, 14))
	_lamp(Rect2(-5, -10, 10, 3), TEAL if active else AMBER)
	for segment in range(4):
		var start := float(segment) * PI * 0.5 + 0.16
		draw_arc(Vector2(0, 8), 5, start, start + 1.13, 4, TEAL if active else BRASS, 1.5)

func _draw_fluid() -> void:
	_draw_solid_casing()
	_armor(Rect2(-32, -25, 30, 46), RUST, 5, 3)
	_armor(Rect2(-27, -32, 11, 14), COPPER, 2, 2)
	_armor(Rect2(-29, -29, 15, 5), BRASS, 1, 1)
	var tube := PackedVector2Array([Vector2(-26,14), Vector2(-26,-12), Vector2(-22,-18),
		Vector2(-16,-18), Vector2(-12,-12), Vector2(-12,7), Vector2(-9,11), Vector2(11,11)])
	draw_polyline(tube, INK, 12)
	draw_polyline(tube, Color("645354"), 9)
	draw_polyline(tube, Color("763941"), 7)
	draw_polyline(tube, Color("a64e4d"), 4)
	var glass_edge := PackedVector2Array()
	for point in tube:
		glass_edge.append(point - Vector2(2, 1))
	draw_polyline(glass_edge, Color("dfa99a"), 1.5)
	for bubble in [Vector2(-25, -9), Vector2(-25, 9), Vector2(-13, -2), Vector2(-2, 11)]:
		draw_rect(Rect2(bubble, Vector2(1, 2)), Color("d58370"))
	for at in [Vector2(-26, 3), Vector2(-12, -5)]:
		_armor(Rect2(at - Vector2(6,2), Vector2(12,5)), BRASS, 1, 1)
		_bolt(at - Vector2(4, 0))
	_armor(Rect2(-4, -21, 31, 17), BRASS, 3, 2)
	_bolt(Vector2(24, -6))
	for index in range(4):
		var x := -1 + index * 7
		draw_rect(Rect2(x, -18, 5, 10), INK)
		var lit := index < pressure
		if fill_step >= 0:
			lit = index * 8 < fill_step
		var segments := index + 1
		for segment in range(segments):
			draw_rect(Rect2(x + 1, -10 - segment * 2, 3, 1), AMBER if lit else Color("674849"))
	_coupling(Vector2(14, 12), 9)
	if fill_step >= 0:
		draw_line(Vector2(-26, 14), Vector2(-26, 14 - roundf(float(fill_step) * 26.0 / 32.0)), AMBER, 2)
		_lamp(Rect2(11, 24, 6, 2), AMBER)

func _gate_half() -> float:
	return span.y * 0.5 - 12.0

func _draw_gate() -> void:
	var half := _gate_half()
	var width := span.x
	var exit := kind == &"exit_gate"
	var light := TEAL if active and not exit else AMBER
	# The rail is flush with the walkway, and the leaves never extend outside the guide.
	draw_rect(Rect2(-width * 0.5 - 2, -half, 7, half * 2), INK)
	draw_rect(Rect2(-width * 0.5, -half, 3, half * 2), BRASS.darkened(0.28))
	draw_rect(Rect2(width * 0.5 - 3, -half, 4, half * 2), Color("62454a"))
	for y in range(ceili(-half + 6), floori(half - 5), 15):
		draw_rect(Rect2(-width * 0.5, y, 2, 2), Color("b68a5e"))
		draw_rect(Rect2(width * 0.5 - 2, y, 2, 2), Color("332830"))
	if float(gate_gap) < half - 1.0:
		for side: float in [-1.0, 1.0]:
			var length := half - float(gate_gap)
			var y := -half if side < 0.0 else float(gate_gap)
			_armor(Rect2(-width * 0.5 + 2, y, width - 4, length), RED,
				minf(4.0, length * 0.34), 4)
			if length > 25.0 and not exit:
				_armor(Rect2(-width * 0.5 + 6, y + 5, width - 12, length - 10),
					RUST.darkened(0.14), 3, 1)
			for rib in range(9, floori(length) - 5, 17 if exit else 37):
				var inset := 5.0 if exit else 9.0
				draw_rect(Rect2(-width * 0.5 + inset, y + rib, width - inset * 2, 2), INK)
				draw_rect(Rect2(-width * 0.5 + inset, y + rib + 2, width - inset * 2, 1), RUST)
			if length > 14.0:
				_lamp(Rect2(-5, y + (length - 6 if side < 0 else 3), 10, 3), AMBER)
	for side: float in [-1.0, 1.0]:
		var y := side * (half + 2.0)
		if not exit:
			_armor(Rect2(-width * 0.5 - 9, y - 10, width + 18, 20), SIDE, 4, 7)
			for x: float in [-width * 0.5 - 6, width * 0.5 + 1]:
				draw_rect(Rect2(x, y - 4, 4, 8), COPPER)
		_armor(Rect2(-width * 0.5 - 6, y - 9, width + 12, 18), RUST if not exit else RED, 4, 6)
		_armor(Rect2(-width * 0.5 - 2, y - 6, width + 4, 12), RED, 3, 1)
		_lamp(Rect2(-9, y - 2, 18, 4), light)
		for x in [-width * 0.5 + 1, width * 0.5 - 2]:
			_bolt(Vector2(x, y + 4))

func _draw_receiver_latch() -> void:
	_armor(Rect2(-23, -13, 46, 26), RED, 5, 7)
	_armor(Rect2(-19, -11, 29, 22), RUST, 4, 4)
	draw_rect(Rect2(9, -9, 7, 18), BRASS)
	_lamp(Rect2(-22, -5, 5, 10), AMBER)
	_bolt(Vector2(18, -6))
	_bolt(Vector2(18, 6))

func _draw_receiver_bulkhead() -> void:
	var height := span.y * 0.5
	_armor(Rect2(-23, -height, 68, span.y), SIDE, 14, 10)
	_armor(Rect2(-20, -height + 9, 42, span.y - 18), RED, 10, 8)
	_armor(Rect2(-20, -125, 34, 250), INK, 7, 4)
	draw_line(Vector2(-7, -120), Vector2(-7, 120), BRASS.darkened(0.25), 2)
	for side: float in [-1.0, 1.0]:
		var center := side * 170.5
		_armor(Rect2(-27, center - 34, 57, 68), RUST, 6, 7)
		for lane in [153.0, 188.0]:
			var y: float = lane * side
			_coupling(Vector2(-10, y), 12)
			_lamp(Rect2(10, y - 3, 10, 6), AMBER.darkened(0.25))
	for y in range(-111, 112, 23):
		draw_rect(Rect2(-13, y, 14, 3), BRASS.darkened(0.63))
