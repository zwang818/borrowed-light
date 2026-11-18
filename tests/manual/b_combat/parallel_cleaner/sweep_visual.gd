extends Node2D
## Play the authored atlas by sampling only the unobstructed part of each sector slice.
const DIR := "res://tests/manual/b_combat/parallel_cleaner/art/claw_sweep_fx/"
var atlas: Texture2D
var frames: Array[Rect2] = []
var pivot := Vector2.ZERO
var fps := 30.0
var source_radius := 82.0
var frame_index := -1
var aim := Vector2.DOWN
var mirror := false
var radius := 70.0
var half_angle := PI * 0.4
var limits := PackedFloat32Array()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	atlas = load(DIR + "borrowed-light-claw-sweep.png") as Texture2D
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "borrowed-light-claw-sweep.json"))
	var settings: Dictionary = manifest.meta.pixelfx
	pivot = Vector2(float(settings.pivot[0]), float(settings.pivot[1]))
	fps = float(settings.fps)
	source_radius = float(manifest.meta.borrowed_light.visual_radius_px)
	for item: Dictionary in manifest.frames:
		var rect: Dictionary = item.frame
		frames.append(Rect2(rect.x, rect.y, rect.w, rect.h))

func present(direction: Vector2, reflected: bool, age: float, span: float, reach: float, allowed: PackedFloat32Array) -> void:
	frame_index = mini(int(floor((age + 0.00001) * fps)), frames.size() - 1)
	aim = direction
	mirror = reflected
	half_angle = span
	radius = reach
	limits = allowed
	queue_redraw()

func clear() -> void:
	if frame_index != -1:
		frame_index = -1
		queue_redraw()

func _uv(point: Vector2, rect: Rect2, rotation_to_source: float, texture_size: Vector2) -> Vector2:
	var source := point.rotated(rotation_to_source) * (source_radius / radius)
	if mirror:
		source.x = -source.x
	return (rect.position + pivot + source) / texture_size

func _draw() -> void:
	if frame_index < 0 or limits.is_empty():
		return
	var rect := frames[frame_index]
	var texture_size := Vector2(atlas.get_size())
	var rotation_to_source := PI * 0.5 - aim.angle()
	var centre_uv := _uv(Vector2.ZERO, rect, rotation_to_source, texture_size)
	var step := 2.0 * half_angle / limits.size()
	for i in range(limits.size()):
		if limits[i] < 0.1:
			continue
		var a := aim.rotated(-half_angle + i * step) * limits[i]
		var b := aim.rotated(-half_angle + (i + 1) * step) * limits[i]
		var mesh := PackedVector2Array([Vector2.ZERO, a, b])
		var uv := PackedVector2Array([centre_uv, _uv(a, rect, rotation_to_source, texture_size), _uv(b, rect, rotation_to_source, texture_size)])
		draw_polygon(mesh, PackedColorArray([Color.WHITE]), uv, atlas)
