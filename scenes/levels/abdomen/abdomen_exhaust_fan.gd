@tool
extends Node2D
## Only the rotor moves. This decoration adds no physics or interaction nodes.
const ATLAS = preload("res://assets/sprites/environment/abdomen/props_atlas.png")
const PARTS = preload("res://assets/sprites/environment/abdomen/compressor_parts.png")
const PIXEL_MATERIAL = preload("res://scenes/levels/abdomen/abdomen_pixel.tres")
# Measured in the actual 1254 px source, not the image viewer's display size.
const ATLAS_PIVOT := Vector2(755, 520)
const ROTOR_SOURCE := Rect2(718, 116, 490, 490)
const ROTOR_PIVOT := Vector2(961, 362)
const GUARD_SOURCE := Rect2(694, 684, 492, 478)
const GUARD_PIVOT := Vector2(941, 927.5)
@export var draw_size := Vector2(144, 144)
@export_range(2.0, 20.0, 0.25) var seconds_per_turn := 6.0
@export var preview_in_editor := false
var _elapsed := 0.0
var _frame := -1
var _angle := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = PIXEL_MATERIAL
	_update_pose(0.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_elapsed = fposmod(_elapsed + delta, seconds_per_turn)
	var frame := int(_elapsed * 24.0)
	if frame != _frame:
		_frame = frame
		_update_pose(float(frame) / 24.0)

func _update_pose(time: float) -> void:
	_angle = fposmod(time, seconds_per_turn) / seconds_per_turn * TAU
	queue_redraw()

func _draw() -> void:
	var sizing := draw_size / 320.0
	var cell := ATLAS.get_size() / 4.0
	var center := (ATLAS_PIVOT / cell - Vector2(2, 1)) * 320.0 - Vector2(160, 160)
	draw_set_transform(Vector2.ZERO, 0.0, sizing)
	draw_texture_rect_region(ATLAS, Rect2(-160, -160, 320, 320), Rect2(Vector2(2, 1) * cell, cell))
	# Cover the old baked blades inside the aperture; retain the square frame and bolts.
	draw_circle(center, 85.0, Color(0.035, 0.045, 0.05, 1))
	for radius in [78.0, 82.0]:
		draw_arc(center, radius, 0, TAU, 64, Color(0.1, 0.13, 0.14), 1.0)
	var rotor_scale := 164.0 / 460.0
	draw_set_transform(center * sizing, _angle, sizing * rotor_scale)
	draw_texture_rect_region(PARTS, Rect2(ROTOR_SOURCE.position - ROTOR_PIVOT, ROTOR_SOURCE.size), ROTOR_SOURCE)
	# Reuse the existing stationary safety cage; it must never inherit rotor rotation.
	draw_set_transform(center * sizing, 0.0, sizing * (178.0 / 478.0))
	draw_texture_rect_region(PARTS, Rect2(GUARD_SOURCE.position - GUARD_PIVOT, GUARD_SOURCE.size), GUARD_SOURCE)
	draw_set_transform(Vector2.ZERO)
