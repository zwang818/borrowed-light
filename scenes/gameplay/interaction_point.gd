extends Node2D
## Proximity cue shared by abdomen devices and ducts.
enum Cue { RECTANGLE, SEAM }

const REACTION_RANGE := 112.0
const PROMPT_DELAY := 0.22

var interaction_id: StringName
var cue := Cue.RECTANGLE
var cue_offset := Vector2.ZERO
var nearby := false
var prompt_ready := false
var _dwell := 0.0
var _strength := 0.0
var _rectangle_focused := false

func can_interact_from(origin: Vector2, reach: float) -> bool:
	if origin.distance_squared_to(global_position) >= reach * reach:
		return false
	var query := PhysicsRayQueryParameters2D.create(origin, global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func update_approach(origin: Vector2, can_prompt: bool, still: bool, delta: float) -> void:
	nearby = can_interact_from(origin, REACTION_RANGE)
	_dwell = minf(_dwell + delta, PROMPT_DELAY) if can_prompt and still else 0.0
	prompt_ready = _dwell >= PROMPT_DELAY
	if cue == Cue.RECTANGLE:
		if _rectangle_focused != can_prompt:
			_rectangle_focused = can_prompt
			queue_redraw()
		return
	var strength := move_toward(_strength, 1.0 if nearby else 0.0, delta * 5.0)
	if strength != _strength:
		_strength = strength
		queue_redraw()

func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	if cue == Cue.RECTANGLE:
		_draw_recess_marker()
	elif not is_zero_approx(_strength):
		var light := Color(Color("abcebb"), _strength)
		draw_rect(Rect2(cue_offset, Vector2(11, 2)), Color(light, _strength * 0.24))
		draw_rect(Rect2(cue_offset + Vector2(2, 0), Vector2(7, 1)), light)

func _draw_recess_marker() -> void:
	var tint := Color("f0ce8a")
	var radius := 10.0 if _rectangle_focused else 7.0
	var rect := Rect2(cue_offset - Vector2(radius, radius), Vector2.ONE * radius * 2.0)
	draw_rect(rect, Color("16282e"))
	draw_rect(rect, tint, false, 1)
	if _rectangle_focused:
		draw_line(cue_offset + Vector2(-3, -4), cue_offset + Vector2(-3, 4), tint)
		for y in [-4, 0, 4]:
			draw_line(cue_offset + Vector2(-3, y), cue_offset + Vector2(3, y), tint)
	else:
		draw_circle(cue_offset, 2, tint)
