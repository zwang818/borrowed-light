@tool
extends Node2D
## Ambient two-link rig. Only the art moves; the existing table collider stays fixed.
const PARTS = preload("res://assets/sprites/environment/abdomen/welding_station_parts.png")
const PIXEL_MATERIAL = preload("res://scenes/levels/abdomen/abdomen_pixel.tres")
const DESIGN_SIZE := Vector2(128, 96)
const SHOULDER := Vector2(41.4, 36.8)
const UPPER_LENGTH := 30.0
const FOREARM_LENGTH := 39.0
const CYCLE_SECONDS := 6.4
const POSE_FPS := 12.0

@export_range(0.25, 3.0, 0.05) var animation_speed := 1.0
@export var welding_sparks := true
@export var preview_in_editor := false
var _elapsed := 0.0
var _frame := -1
var _tip := Vector2(90, 30)
var _elbow := Vector2.ZERO
var _welding := false
var _sample_time := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = PIXEL_MATERIAL
	_fit_existing_base()
	_update_pose(0.0)

func _process(delta: float) -> void:
	_fit_existing_base()
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_elapsed = fposmod(_elapsed + delta * animation_speed, CYCLE_SECONDS)
	var frame := int(_elapsed * POSE_FPS)
	if frame != _frame:
		_frame = frame
		_update_pose(float(frame) / POSE_FPS)

func _fit_existing_base() -> void:
	var parent := get_parent()
	if parent != null and parent.get("size") is Vector2:
		scale = parent.get("size") / DESIGN_SIZE

func _ease_between(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(b, smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0)))

func _update_pose(time: float) -> void:
	_sample_time = fposmod(time, CYCLE_SECONDS)
	var t := _sample_time
	_welding = false
	if t < 0.65:
		_tip = Vector2(90, 30)
	elif t < 1.6:
		_tip = _ease_between(Vector2(90, 30), Vector2(91, 57), (t - 0.65) / 0.95)
	elif t < 3.25:
		_tip = Vector2(91, 57).lerp(Vector2(79, 63), (t - 1.6) / 1.65)
		_welding = true
	elif t < 3.8:
		_tip = _ease_between(Vector2(79, 63), Vector2(80, 43), (t - 3.25) / 0.55)
	elif t < 4.35:
		_tip = _ease_between(Vector2(80, 43), Vector2(98, 59), (t - 3.8) / 0.55)
	elif t < 5.1:
		_tip = Vector2(98, 59).lerp(Vector2(91, 63), (t - 4.35) / 0.75)
		_welding = true
	elif t < 6.05:
		_tip = _ease_between(Vector2(91, 63), Vector2(90, 30), (t - 5.1) / 0.95)
	else:
		_tip = Vector2(90, 30)
	# Keep the elbow above the work surface. Source pivots remain connected in every pose.
	var reach := _tip - SHOULDER
	var distance := clampf(reach.length(), 1.0, UPPER_LENGTH + FOREARM_LENGTH - 0.01)
	var bend := acos(clampf((distance * distance + UPPER_LENGTH * UPPER_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH) / (2.0 * distance * UPPER_LENGTH), -1.0, 1.0))
	_elbow = SHOULDER + Vector2.from_angle(reach.angle() - bend) * UPPER_LENGTH
	queue_redraw()

func _draw_part(cell_index: Vector2, pivot_uv: Vector2, end_uv: Vector2, from: Vector2, to: Vector2) -> void:
	var cell := PARTS.get_size() * 0.5
	var source_axis := (end_uv - pivot_uv) * cell
	var factor := from.distance_to(to) / source_axis.length()
	draw_set_transform(from, (to - from).angle() - source_axis.angle(), Vector2.ONE * factor)
	draw_texture_rect_region(PARTS, Rect2(-pivot_uv * cell, cell), Rect2(cell_index * cell, cell))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	var cell := PARTS.get_size() * 0.5
	# Fixed table plate and pedestal, with the old static arm removed in the new asset.
	draw_texture_rect_region(PARTS, Rect2(Vector2.ZERO, DESIGN_SIZE), Rect2(Vector2.ZERO, cell))
	_draw_part(Vector2(1, 0), Vector2(0.1625, 0.6281), Vector2(0.7656, 0.6469), SHOULDER, _elbow)
	_draw_part(Vector2(0, 1), Vector2(0.1922, 0.5281), Vector2(0.9625, 0.7047), _elbow, _tip)
	# A small bearing cap covers the common elbow pivot, without shifting the table.
	var cap_source := Rect2(Vector2(0.66, 0.68) * PARTS.get_size(), Vector2(0.16, 0.165) * PARTS.get_size())
	draw_texture_rect_region(PARTS, Rect2(_elbow - Vector2(4.5, 4.5), Vector2(9, 9)), cap_source)
	if _welding and welding_sparks:
		_draw_weld()

func _draw_weld() -> void:
	# Small, local pixel sparks: no light/visibility state, damage, audio or input.
	var pulse := 0.7 + 0.3 * sin(_sample_time * 47.0)
	var contact := _tip.round()
	draw_circle(contact, 7.0, Color(0.35, 0.68, 0.72, 0.08 * pulse))
	draw_rect(Rect2(contact - Vector2(2, 2), Vector2(4, 4)), Color(0.64, 0.95, 1.0, 0.8 * pulse))
	draw_rect(Rect2(contact - Vector2.ONE, Vector2(2, 2)), Color(0.96, 1.0, 1.0, 1))
	for i in range(7):
		var age := fposmod(_sample_time * 2.7 + float(i) * 0.173, 1.0)
		var angle := float(i) * 2.399 + 0.4
		var ray := Vector2(cos(angle), sin(angle) * 0.65)
		var particle := (contact + ray * (3.0 + age * 12.0) + Vector2(0, age * age * 5.0)).round()
		var color := Color(0.69, 0.93, 0.95, 1.0 - age)
		if i % 3 == 0:
			color = Color(0.87, 0.7, 0.37, 1.0 - age)
		draw_line(particle, particle - ray * 2.0, color, 1.0, false)
