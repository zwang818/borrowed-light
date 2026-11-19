extends Node2D
## Terminal dressing and the real patrol route used as the puzzle reference.
const DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const EDGE := Color("81e2db")
const CORE := Color("bbf3df")
const AMBER := Color("c8a268")
const INSPECTION_AFTER := 3
var demonstration := PackedVector2Array()
var terminal := Vector2.ZERO
var board_angle := 0.0
var powered := false

func configure(flow: Node2D) -> void:
	var forward: Vector2 = flow.F
	var side := Vector2(-forward.y, forward.x)
	var start: Vector2 = flow.anchor("ProtocolCleaner")
	board_angle = forward.angle()
	terminal = to_local(flow.anchor("ProtocolTerminal"))
	demonstration = PackedVector2Array([
		start,
		start + forward * 124.0,
		start + forward * 124.0 + side * 42.0,
		start + forward * 60.0 + side * 42.0,
		start + forward * 60.0 + side * 92.0,
		start + side * 92.0,
	])
	flow.demo_cleaner.configure_loop(demonstration, INSPECTION_AFTER)

func observed_directions() -> Array[int]:
	var result: Array[int] = []
	for i in range(demonstration.size()):
		var next := demonstration[(i + 1) % demonstration.size()]
		var direction := demonstration[i].direction_to(next).rotated(-board_angle)
		var compass := Vector2(roundf(direction.x), roundf(direction.y))
		result.append(DIRECTIONS.find(compass))
	return result

func set_powered(value: bool) -> void:
	powered = value
	queue_redraw()

func _draw() -> void:
	if demonstration.is_empty():
		return
	# Cover the old switches on the terminal only in this scene.
	draw_rect(Rect2(terminal + Vector2(-31, -24), Vector2(62, 39)), Color("263235"))
	draw_rect(Rect2(terminal + Vector2(-29, -22), Vector2(58, 35)), Color("587573"), false, 2.0)
	var color := CORE if powered else AMBER
	var board_points := PackedVector2Array()
	for point in demonstration:
		var offset := (point - demonstration[0]).rotated(-board_angle)
		board_points.append(terminal + Vector2(-20, -15) + offset * Vector2(0.32, 0.23))
	board_points.append(board_points[0])
	draw_polyline(board_points, color, 2.0)
	draw_rect(Rect2(board_points[0] - Vector2(3, 3), Vector2(6, 6)), color)

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
