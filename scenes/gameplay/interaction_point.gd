extends Node2D
## Access position, a small response on the prop, and a short dwell before the prompt.
enum Cue { INDICATOR, SEAM, NONE, FLOOR_BUTTON, PANEL, RECTANGLE }

const REACTION_RANGE := 112.0
const PROMPT_DELAY := 0.22
const BUTTON_TREAD := Rect2(-16, -9, 32, 18)
const STEP_MARKER_RADIUS := 20.0
const TERRAIN := preload("res://assets/sprites/environment/abdomen/terrain_atlas.png")

var interaction_id: StringName
var cue := Cue.INDICATOR
var cue_offset := Vector2.ZERO
var panel_size := Vector2.ZERO
var nearby := false
var prompt_ready := false
var _dwell := 0.0
var _strength := 0.0
var _tint := Color("abcebb")
var _button_depth := 0.0
var _rectangle_focused := false
var step_marker: Sprite2D
var _marker_occupied := false
var _marker_pulse: Tween

func add_step_marker() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.19, 0.37, 1.0])
	gradient.colors = PackedColorArray([Color("e6f3f4"), Color("b9dbe5"), Color("7eaaba", 0.24), Color("7eaaba", 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	step_marker = Sprite2D.new()
	step_marker.name = "StepMarker"
	step_marker.texture = texture
	step_marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(step_marker)

func is_on_step_marker(origin: Vector2) -> bool:
	return origin.distance_squared_to(global_position) <= STEP_MARKER_RADIUS * STEP_MARKER_RADIUS

func update_approach(origin: Vector2, can_prompt: bool, still: bool, delta: float, ready := true) -> void:
	if cue == Cue.FLOOR_BUTTON:
		nearby = is_on_button(origin)
		prompt_ready = nearby and can_prompt
		var depth := move_toward(_button_depth, 1.0 if nearby else 0.0, delta * 11.0)
		if depth != _button_depth:
			_button_depth = depth
			queue_redraw()
		return
	var in_range := origin.distance_squared_to(global_position) < REACTION_RANGE * REACTION_RANGE
	nearby = in_range and has_clear_path_from(origin)
	_dwell = minf(_dwell + delta, PROMPT_DELAY) if can_prompt and still else 0.0
	prompt_ready = _dwell >= PROMPT_DELAY
	if step_marker != null:
		prompt_ready = can_prompt and is_on_step_marker(origin)
		if prompt_ready and not _marker_occupied:
			if _marker_pulse != null and _marker_pulse.is_running():
				_marker_pulse.kill()
			_marker_pulse = create_tween().set_trans(Tween.TRANS_SINE)
			_marker_pulse.tween_property(step_marker, "scale", Vector2.ONE * 1.85, 0.14).set_ease(Tween.EASE_OUT)
			_marker_pulse.tween_property(step_marker, "scale", Vector2.ONE, 0.32).set_ease(Tween.EASE_IN_OUT)
		_marker_occupied = prompt_ready
	if cue == Cue.RECTANGLE and _rectangle_focused != can_prompt:
		_rectangle_focused = can_prompt
		queue_redraw()
	var strength := move_toward(_strength, 1.0 if nearby else 0.0, delta * 5.0)
	var tint := Color("abcebb") if ready else Color("d0a273")
	if not is_equal_approx(strength, _strength) or tint != _tint:
		_strength = strength
		_tint = tint
		queue_redraw()

func is_on_button(origin: Vector2) -> bool:
	return BUTTON_TREAD.has_point(to_local(origin))

func has_clear_path_from(origin: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin, global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	if cue == Cue.FLOOR_BUTTON:
		_draw_floor_button()
		return
	if cue == Cue.RECTANGLE:
		_draw_recess_marker()
		return
	if is_zero_approx(_strength) or cue == Cue.NONE:
		return
	var light := Color(_tint, _strength)
	if cue == Cue.PANEL:
		var surface := Rect2(cue_offset, panel_size)
		draw_rect(surface, Color(light, _strength * 0.23))
		draw_rect(surface, Color(light, _strength * 0.65), false, 1)
		draw_rect(Rect2(cue_offset + Vector2(5, 3), Vector2(panel_size.x - 10.0, 4)), Color(light, _strength * 0.88))
	elif cue == Cue.SEAM:
		draw_rect(Rect2(cue_offset, Vector2(11, 2)), Color(light, _strength * 0.24))
		draw_rect(Rect2(cue_offset + Vector2(2, 0), Vector2(7, 1)), light)
	else:
		draw_rect(Rect2(cue_offset - Vector2(2, 1), Vector2(7, 5)), Color(light, _strength * 0.2))
		draw_rect(Rect2(cue_offset, Vector2(3, 2)), light)

func _draw_floor_button() -> void:
	var cell := TERRAIN.get_size() / 4.0
	var panel := Rect2(Vector2(2, 2) * cell, cell)
	var tread := Rect2(panel.position + Vector2(12, 12), Vector2(104, 56))
	draw_rect(Rect2(-21, -13, 42, 28), Color("131d20"))
	draw_texture_rect_region(TERRAIN, Rect2(-20, -12, 40, 24), panel, Color("82928b"))
	draw_rect(Rect2(-18, -11, 36, 22), Color("1a2427"))
	var travel := roundf(7.0 * _button_depth)
	var top := -15.0 + travel
	draw_rect(Rect2(-16, top, 32, 25 - travel), Color("172322"))
	draw_rect(Rect2(-15, top + 16, 30, 8 - travel), Color("40514b"))
	draw_texture_rect_region(TERRAIN, Rect2(-16, top, 32, 16), tread, Color("b1beba"))
	draw_rect(Rect2(-16, top, 32, 16), Color("889e93"), false, 1)
	draw_line(Vector2(-15, top + 1), Vector2(15, top + 1), Color("a6b9ad"))
	for x in [-10, 0, 10]:
		draw_rect(Rect2(x - 2, top + 8, 5, 2), Color("233334"))
	for x in [-19, 17]:
		draw_rect(Rect2(x, -9, 2, 2), Color("a99576"))
	for x in [-12, 7]:
		draw_rect(Rect2(x, 10, 5, 2), Color("796750").lerp(Color("a6d5a9"), _button_depth))

func _draw_recess_marker() -> void:
	var tint := Color("f0ce8a")
	var radius := 10.0 if _rectangle_focused else 7.0
	var rect := Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0)
	draw_rect(rect, Color("16282e"))
	draw_rect(rect, tint, false, 1)
	if _rectangle_focused:
		draw_line(Vector2(-3, -4), Vector2(-3, 4), tint)
		for y in [-4, 0, 4]:
			draw_line(Vector2(-3, y), Vector2(3, y), tint)
	else:
		draw_circle(Vector2.ZERO, 2, tint)
