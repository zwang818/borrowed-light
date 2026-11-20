extends Node2D
## Play the authored atlas by sampling only the unobstructed part of each sector slice.
const DIR := "res://assets/sprites/enemies/parallel_cleaner/sweep_rift_v2/"
const DISTORTION := preload("res://scenes/enemies/parallel_cleaner/sweep_displacement.gdshader")
var atlas: Texture2D
var displacement: Texture2D
var frames: Array[Rect2] = []
var displacement_frames := PackedByteArray()
var pivot := Vector2.ZERO
var fps := 30.0
var source_radius := 82.0
var source_half_angle := deg_to_rad(72.0)
var hitstop_seconds := 0.067
var frame_index := -1
var aim := Vector2.DOWN
var mirror := false
var radius := 70.0
var half_angle := PI * 0.4
var limits := PackedFloat32Array()
var distortion := Node2D.new()
var distortion_material := ShaderMaterial.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	atlas = load(DIR + "borrowed-light-rift-sweep.png") as Texture2D
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "borrowed-light-rift-sweep.json"))
	var settings: Dictionary = manifest.meta.pixelfx
	var effect: Dictionary = manifest.meta.borrowed_light
	pivot = Vector2(float(settings.pivot[0]), float(settings.pivot[1]))
	fps = float(settings.fps)
	source_radius = float(effect.visual_radius_px)
	source_half_angle = deg_to_rad(float(effect.sector_half_degrees))
	hitstop_seconds = float(effect.hitstop_ms_on_damage) * 0.001
	displacement = load(DIR + str(effect.displacement_mask)) as Texture2D
	var mask := displacement.get_image()
	for item: Dictionary in manifest.frames:
		var rect: Dictionary = item.frame
		var region := Rect2i(rect.x, rect.y, rect.w, rect.h)
		frames.append(Rect2(region))
		displacement_frames.append(int(mask.get_region(region).get_used_rect().has_area()))
	# Draw the displaced tiles below the boss sprite and the blade above it.
	distortion.z_index = -2
	distortion_material.shader = DISTORTION
	distortion_material.set_shader_parameter("max_offset_px", float(effect.max_displacement_display_px))
	distortion.material = distortion_material
	add_child(distortion)
	distortion.draw.connect(_draw_displacement)
	distortion.hide()

func present(direction: Vector2, reflected: bool, age: float, span: float, reach: float, allowed: PackedFloat32Array) -> void:
	frame_index = mini(int(floor((age + 0.00001) * fps)), frames.size() - 1)
	aim = direction
	mirror = reflected
	half_angle = span
	radius = reach
	limits = allowed
	var distort := displacement_frames[frame_index] != 0 and not limits.is_empty()
	distortion.visible = distort
	if distort:
		distortion_material.set_shader_parameter("sweep_radius", reach)
		distortion.queue_redraw()
	queue_redraw()

func clear() -> void:
	distortion.hide()
	if frame_index != -1:
		frame_index = -1
		queue_redraw()

func _uv(angle: float, distance: float, rect: Rect2, texture_size: Vector2) -> Vector2:
	# Map the wider gameplay arc onto the authored arc without stretching its radius.
	var source := Vector2.DOWN.rotated(angle * source_half_angle / half_angle) * (distance * source_radius / radius)
	if mirror:
		source.x = -source.x
	return (rect.position + pivot + source) / texture_size

func _draw() -> void:
	_draw_sector(self, atlas)

func _draw_displacement() -> void:
	_draw_sector(distortion, displacement)

func _draw_sector(layer: CanvasItem, texture: Texture2D) -> void:
	if frame_index < 0 or limits.is_empty():
		return
	var rect := frames[frame_index]
	var texture_size := Vector2(atlas.get_size())
	var centre_uv := (rect.position + pivot) / texture_size
	var step := 2.0 * half_angle / limits.size()
	for i in range(limits.size()):
		if limits[i] < 0.1:
			continue
		var start := -half_angle + i * step
		var end := start + step
		var distance := limits[i]
		var mesh := PackedVector2Array([Vector2.ZERO, aim.rotated(start) * distance, aim.rotated(end) * distance])
		var uv := PackedVector2Array([centre_uv, _uv(start, distance, rect, texture_size), _uv(end, distance, rect, texture_size)])
		var tint := Color(distance / radius, 1, 1) if layer == distortion else Color.WHITE
		layer.draw_polygon(mesh, PackedColorArray([tint]), uv, texture)
