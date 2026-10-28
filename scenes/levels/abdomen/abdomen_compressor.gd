@tool
extends Node2D
## Ambient machinery only. The existing parent owns collision and occlusion.
const PARTS = preload("res://assets/sprites/environment/abdomen/compressor_parts.png")
const PIXEL_MATERIAL = preload("res://scenes/levels/abdomen/abdomen_pixel.tres")
const DESIGN_SIZE := Vector2(128, 128)
const SOURCE_SIZE := Vector2(1280, 1280)
const CYCLE_SECONDS := 4.0
const POSE_FPS := 24.0
const BASE_SOURCE := Rect2(64, 48, 616, 587)
const BASE_TARGET := Rect2(6, 20, 116, 108)
# Actual PNG pixels. These bearings are not centered in their crop rectangles.
const APERTURE_PIVOT := Vector2(369, 204)
const ROTOR_SOURCE := Rect2(718, 116, 490, 490)
const ROTOR_PIVOT := Vector2(961, 362)
const GUARD_SOURCE := Rect2(694, 684, 492, 478)
const GUARD_PIVOT := Vector2(941, 927.5)

@export_range(0.25, 3.0, 0.05) var animation_speed := 1.0
@export var preview_in_editor := false
var _elapsed := 0.0
var _frame := -1
var _fan_angle := 0.0
var _stroke := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = PIXEL_MATERIAL
	_fit_base()
	_update_pose(0.0)

func _process(delta: float) -> void:
	_fit_base()
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_elapsed = fposmod(_elapsed + delta * animation_speed, CYCLE_SECONDS)
	var frame := int(_elapsed * POSE_FPS)
	if frame != _frame:
		_frame = frame
		_update_pose(float(frame) / POSE_FPS)

func _fit_base() -> void:
	var parent := get_parent()
	if parent != null and parent.get("size") is Vector2:
		scale = parent.get("size") / DESIGN_SIZE

func _update_pose(time: float) -> void:
	var phase := fposmod(time, CYCLE_SECONDS) / CYCLE_SECONDS
	_fan_angle = phase * TAU * 2.0
	_stroke = sin(phase * TAU * 2.0) * 3.0
	queue_redraw()

func _source(rect: Rect2) -> Rect2:
	var ratio := PARTS.get_size() / SOURCE_SIZE
	return Rect2(rect.position * ratio, rect.size * ratio)

func _draw_clipped_slider(source: Rect2, target: Rect2, bay: Rect2) -> void:
	# Clip to the existing opening: rods never slide across the fixed housings.
	var visible := target.intersection(bay)
	if not visible.has_area():
		return
	var ratio := source.size / target.size
	var cropped := Rect2(source.position + (visible.position - target.position) * ratio, visible.size * ratio)
	draw_texture_rect_region(PARTS, visible, _source(cropped))

func _draw() -> void:
	# Keep the existing chassis and slider framing. Map the measured aperture into it.
	var base_source := _source(BASE_SOURCE)
	var fan_center := BASE_TARGET.position + (APERTURE_PIVOT - base_source.position) / base_source.size * BASE_TARGET.size
	draw_texture_rect_region(PARTS, BASE_TARGET, base_source)
	_draw_clipped_slider(Rect2(146, 700, 123, 455), Rect2(24.5, 65 + _stroke, 10, 34), Rect2(24.5, 68, 10, 23))
	_draw_clipped_slider(Rect2(387, 700, 123, 455), Rect2(93, 65 - _stroke, 10, 34), Rect2(93, 68, 10, 23))
	# Only the rotor turns. The rim and crossed safety supports are drawn afterward.
	draw_set_transform(fan_center, _fan_angle, Vector2.ONE * (33.0 / 460.0))
	draw_texture_rect_region(PARTS, Rect2(ROTOR_SOURCE.position - ROTOR_PIVOT, ROTOR_SOURCE.size), ROTOR_SOURCE)
	draw_set_transform(fan_center, 0.0, Vector2.ONE * (36.0 / 478.0))
	draw_texture_rect_region(PARTS, Rect2(GUARD_SOURCE.position - GUARD_PIVOT, GUARD_SOURCE.size), GUARD_SOURCE)
	draw_set_transform(Vector2.ZERO)
