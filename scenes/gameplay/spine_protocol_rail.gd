extends Node2D
## Terminal dressing and the real patrol route used as the puzzle reference.
const DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const INSPECTION_AFTER := 3
var demonstration := PackedVector2Array()
var console: Node2D
var demo_reader: Node2D
var guide: Node2D
var board_angle := 0.0

func configure(flow: Node2D) -> void:
	var forward: Vector2 = flow.F
	var side := Vector2(-forward.y, forward.x)
	var start: Vector2 = flow.anchor("ProtocolCleaner")
	board_angle = forward.angle()
	var art: Node2D = flow.map.get_node("SpineArt")
	console = art.protocol_console
	demo_reader = art.demo_reader
	guide = flow.demo_cleaner
	demonstration = PackedVector2Array([
		start,
		start + forward * 124.0,
		start + forward * 124.0 + side * 42.0,
		start + forward * 60.0 + side * 42.0,
		start + forward * 60.0 + side * 92.0,
		start + side * 92.0,
	])
	flow.demo_cleaner.configure_loop(demonstration, INSPECTION_AFTER)
	var screen_points := PackedVector2Array()
	for point in demonstration:
		var offset := (point - start).rotated(-board_angle)
		screen_points.append((Vector2(-21, -16) + offset * Vector2(0.34, 0.16)).round())
	console.set_route(screen_points, INSPECTION_AFTER)
	queue_redraw()

func observed_directions() -> Array[int]:
	var result: Array[int] = []
	for i in range(demonstration.size()):
		var next := demonstration[(i + 1) % demonstration.size()]
		var direction := demonstration[i].direction_to(next).rotated(-board_angle)
		var compass := Vector2(roundf(direction.x), roundf(direction.y))
		result.append(DIRECTIONS.find(compass))
	return result

func set_powered(value: bool) -> void:
	console.set_active(value)

func _process(_delta: float) -> void:
	if is_instance_valid(guide):
		demo_reader.set_active(guide.is_inspecting())

func _draw() -> void:
	if demonstration.is_empty():
		return

	var start := to_local(demonstration[0])
	for i in range(demonstration.size()):
		var point := to_local(demonstration[i])
		var next := to_local(demonstration[(i + 1) % demonstration.size()])
		draw_dashed_line(point, next, Color("edc38692"), 2.0, 6.0)
	draw_circle(start, 10.0, Color("302823"))
	draw_arc(start, 9.0, 0, TAU, 20, Color("f0cd8a"), 2.0)
	draw_circle(start, 3.0, Color("f0cd8a"))
	draw_string(preload("res://scenes/gameplay/spine_flow_theme.tres").default_font, start + Vector2(-15, 25),
		"起点", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f0cd8a"))
