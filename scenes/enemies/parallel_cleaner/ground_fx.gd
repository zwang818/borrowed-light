extends Node2D
## Draw atlas frames inside the same wall-clipped disk used for gameplay.
const ART := "res://assets/sprites/enemies/parallel_cleaner/ground_actions/"
const RAYS := 72
const WORLD := 1
const SILK_TRANSITION := 0.20
const CLIPS := {
	&"slam": "borrowed-light-claw-slam",
	&"splat": "borrowed-light-silk-splat",
	&"patch": "borrowed-light-silk-patch",
}
var clips := {}
var patches: Array[Dictionary] = []
var impact: Dictionary = {}
var warning := false
var warning_point := Vector2.ZERO
var warning_radii := PackedFloat32Array()
var warning_progress := 0.0
var warning_exclusion := PackedVector2Array()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for key in CLIPS:
		var path := ART + str(CLIPS[key])
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
		var meta: Dictionary = manifest.meta.pixelfx
		var frames: Array[Rect2] = []
		for index: Dictionary in manifest.frames:
			var r: Dictionary = index.frame
			frames.append(Rect2(r.x, r.y, r.w, r.h))
		clips[key] = {
			"texture": load(path + ".png"), "frames": frames, "fps": float(meta.fps), "loop": bool(meta.loop),
			"pivot": Vector2(meta.pivot[0], meta.pivot[1]),
			"radius": float(manifest.meta.borrowed_light.get("visual_ring_max_px", 26)),
		}

func duration(clip: StringName) -> float:
	var data: Dictionary = clips[clip]
	return data.frames.size() / data.fps

static func _ray(space: PhysicsDirectSpaceState2D, at: Vector2, direction: Vector2, distance: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(at, at + direction * distance, WORLD)
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	return distance if hit.is_empty() else maxf(0.0, at.distance_to(hit.position) - 0.35)

static func clip_disk(space: PhysicsDirectSpaceState2D, at: Vector2, radius: float) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	var step := TAU / RAYS
	var previous := _ray(space, at, Vector2.RIGHT, radius)
	for i in range(RAYS):
		var next := _ray(space, at, Vector2.from_angle((i + 1) * step), radius)
		var middle := _ray(space, at, Vector2.from_angle((i + 0.5) * step), radius)
		lengths.append(minf(previous, minf(next, middle)))
		previous = next
	return lengths

static func covers(space: PhysicsDirectSpaceState2D, at: Vector2, point: Vector2, limits: PackedFloat32Array) -> bool:
	if limits.is_empty():
		return false
	var offset := point - at
	if offset.is_zero_approx():
		return limits[0] > 0.0
	var slice := mini(int(fposmod(offset.angle(), TAU) * limits.size() / TAU), limits.size() - 1)
	return offset.length() <= limits[slice] and _ray(space, at, offset.normalized(), offset.length()) + 0.01 >= offset.length()

func _draw() -> void:
	for patch in patches:
		var age := float(patch.age)
		var clip := &"splat" if age < SILK_TRANSITION else &"patch"
		var clock := age if clip == &"splat" else age - SILK_TRANSITION
		_draw_clipped_frame(clip, patch.at, patch.radius, patch.limits, clock, 1.0)
		_outline(patch.at, patch.limits, Color(0.79, 0.75, 0.56, 0.32 if clip == &"splat" else 0.26))
	if warning:
		_outline(warning_point, warning_radii, Color(1.0, 0.53, 0.25, 0.78), 2.5, lerpf(0.11, 0.24, warning_progress))
		draw_circle(to_local(warning_point), 2.5, Color(1.0, 0.71, 0.35, 0.88))
	if not impact.is_empty():
		_draw_clipped_frame(&"slam", impact.at, impact.radius, impact.limits, impact.age, 1.0)

func _outline(at: Vector2, limits: PackedFloat32Array, color: Color, width := 1.0, fill := 0.0,
		exclude := PackedVector2Array()) -> void:
	var x := to_local(at)
	var cutout := _local_polygon(exclude)
	for i in range(limits.size()):
		if limits[i] <= 0.25:
			continue
		var a := x + Vector2.from_angle(i * TAU / RAYS) * limits[i]
		var b := x + Vector2.from_angle((i + 1) * TAU / RAYS) * limits[i]
		if fill > 0:
			for piece in _floor_pieces(PackedVector2Array([x, a, b]), cutout):
				draw_colored_polygon(piece, Color(color, fill))
		if cutout.is_empty():
			draw_line(a, b, color, width)
		else:
			for edge in Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), cutout):
				draw_polyline(edge, color, width)

func _local_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var local := PackedVector2Array()
	for point in points:
		local.append(to_local(point))
	return local

func _floor_pieces(triangle: PackedVector2Array, cutout: PackedVector2Array) -> Array[PackedVector2Array]:
	return [triangle] if cutout.is_empty() else Geometry2D.clip_polygons(triangle, cutout)

func _draw_clipped_frame(clip: StringName, at: Vector2, radius: float, limits: PackedFloat32Array, age: float,
		opacity: float, exclude := PackedVector2Array()) -> void:
	var info: Dictionary = clips[clip]
	var index := int(floor((age + 0.00001) * float(info.fps)))
	if info.loop:
		index %= info.frames.size()
	elif index >= info.frames.size():
		return
	var texture: Texture2D = info.texture
	var texture_size := Vector2(texture.get_size())
	var frame: Rect2 = info.frames[index]
	var uv0 := (frame.position + Vector2(info.pivot)) / texture_size
	var ratio := float(info.radius) / radius
	var centre := to_local(at)
	var cutout := _local_polygon(exclude)
	var tint := PackedColorArray([Color(1, 1, 1, opacity)])
	for i in range(limits.size()):
		if limits[i] <= 0.25:
			continue
		var a := Vector2.from_angle(i * TAU / RAYS) * limits[i]
		var b := Vector2.from_angle((i + 1) * TAU / RAYS) * limits[i]
		for piece in _floor_pieces(PackedVector2Array([centre, centre + a, centre + b]), cutout):
			var uv := PackedVector2Array()
			for point in piece:
				uv.append(uv0 + (point - centre) * ratio / texture_size)
			draw_polygon(piece, tint, uv, texture)
