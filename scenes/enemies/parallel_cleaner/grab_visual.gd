extends Node2D
## Presentation track; all ground movement and damage remain in the Boss.
const ART := "res://assets/sprites/enemies/parallel_cleaner/grab_throw/"
const WORLD := 1
const SKID_RAYS := 64
const GROUND_POSE_TIME := 0.15
const TRAIL_TIME := 0.12
enum Stage { NONE, GRIPPED, FLIGHT, GROUND }

var stage := Stage.NONE
var boss_frames: Array[Texture2D] = []
var mask_frames: Array[Texture2D] = []
var sockets: Array[Vector2] = []
var mirror_sockets: Array[Vector2] = []
var foot := Vector2.ZERO
var mirror_foot := Vector2.ZERO
var held_asset: Texture2D
var held_anchor := Vector2.ZERO
var flight_anchor := Vector2.ZERO
var ground_anchor := Vector2.ZERO
var flight_frames: Array[Texture2D] = []
var ground_frames: Array[Texture2D] = []
var octants := PackedInt32Array()
var direction_row := 0
var throw_basis := Transform2D.IDENTITY
var last_motion := Vector2.DOWN
var player_sprite := Sprite2D.new()
var front_jaw := Sprite2D.new()
var grip_flash := Sprite2D.new()
var lock_clip: Dictionary
var skid_clip: Dictionary
var lock_age := -1.0
var skid_age := -1.0
var skid_limits := PackedFloat32Array()
var skid_at := Vector2.ZERO
var skid_angle := 0.0
var skid_scale := Vector2.ONE
var fx_layer := Node2D.new()
var visual_at := Vector2.ZERO
var shadow_at := Vector2.ZERO
var shadow_height := 0.0
var release_height := 0.0
var ground_pose_left := 0.0
var trail_clock := 0.0
var trail: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var manifest: Dictionary = _read("grab_frames.json")
	foot = _pair(manifest.boss.foot_anchor)
	mirror_foot = _pair(manifest.boss.mirror_foot_anchor)
	for frame: Dictionary in manifest.boss.frames:
		boss_frames.append(load(ART + str(frame.file)) as Texture2D)
		var mask: String = frame.get("front_jaw_overlay", "")
		mask_frames.append(load(ART + mask) as Texture2D if not mask.is_empty() else null)
		sockets.append(_pair(frame.get("claw_socket", [0, 0])))
		mirror_sockets.append(_pair(frame.get("claw_socket_mirrored", [0, 0])))
	var held: Dictionary = manifest.xiaoyi.frames[0]
	held_asset = load(ART + str(held.file)) as Texture2D
	held_anchor = _pair(held.anchor)
	var directions: Dictionary = _read("directional_frames.json")
	for row in directions.ordered_octants_from_positive_x:
		octants.append(int(row))
	flight_anchor = _pair(directions.stages.flight.anchor)
	ground_anchor = _pair(directions.stages.ground.anchor)
	flight_frames = _directional_frames(directions.stages.flight)
	ground_frames = _directional_frames(directions.stages.ground)
	lock_clip = _read_fx("borrowed-light-grab-lock")
	skid_clip = _read_fx("borrowed-light-throw-skid")
	for sprite in [player_sprite, front_jaw, grip_flash]:
		sprite.centered = false
		sprite.hide()
		add_child(sprite)
	player_sprite.z_index = 3
	front_jaw.z_index = 4
	grip_flash.z_index = 5
	grip_flash.region_enabled = true
	grip_flash.texture = lock_clip.texture
	fx_layer.z_index = 2
	add_child(fx_layer)
	fx_layer.draw.connect(_draw_fx)

func _read(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ART + file))

func _pair(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))

func _directional_frames(data: Dictionary) -> Array[Texture2D]:
	var atlas := load(ART + str(data.atlas)) as Texture2D
	var frames: Array[Texture2D] = []
	frames.resize(8)
	for frame: Dictionary in data.frames:
		var rect: Array = frame.frame
		var slice := AtlasTexture.new()
		slice.atlas = atlas
		slice.region = Rect2(rect[0], rect[1], rect[2], rect[3])
		slice.filter_clip = true
		frames[int(frame.source_order)] = slice
	return frames

func _read_fx(name: String) -> Dictionary:
	var manifest := _read(name + ".json")
	var regions: Array[Rect2] = []
	for item: Dictionary in manifest.frames:
		var frame: Dictionary = item.frame
		regions.append(Rect2(frame.x, frame.y, frame.w, frame.h))
	return {"regions": regions, "texture": load(ART + name + ".png"), "anchor": _pair(manifest.meta.pixelfx.pivot), "fps": float(manifest.meta.pixelfx.fps)}

func get_foot(right: bool) -> Vector2:
	return foot if right else mirror_foot

func grip_point(index: int, right: bool, sprite_scale: float) -> Vector2:
	var at := sockets[index] if right else mirror_sockets[index]
	return to_global((at - get_foot(right)) * sprite_scale)

func show_jaw(index: int, right: bool, sprite_scale: float, tint: Color) -> void:
	if stage != Stage.GRIPPED or mask_frames[index] == null:
		front_jaw.hide()
		return
	front_jaw.texture = mask_frames[index]
	front_jaw.position = -get_foot(right) * sprite_scale
	front_jaw.scale = Vector2.ONE * sprite_scale
	front_jaw.flip_h = not right
	front_jaw.modulate = tint
	front_jaw.show()

func _show_xiaoyi(texture: Texture2D, anchor: Vector2, at: Vector2, flipped := false) -> void:
	visual_at = at
	player_sprite.texture = texture
	player_sprite.flip_h = flipped
	player_sprite.position = to_local(at) - (Vector2(texture.get_width() - anchor.x, anchor.y) if flipped else anchor)
	player_sprite.show()
	queue_redraw()

func begin_grip(at: Vector2, ground: Vector2, right: bool, height: float) -> void:
	stage = Stage.GRIPPED
	lock_age = 0.0
	show_gripped(at, ground, right, height)
	_update_lock(at)

func show_gripped(at: Vector2, ground: Vector2, right: bool, height: float) -> void:
	shadow_at = ground
	shadow_height = height
	_show_xiaoyi(held_asset, held_anchor, at, not right)
	_update_lock(at)

func _update_lock(at: Vector2) -> void:
	var index := int(floor(maxf(0, lock_age) * float(lock_clip.fps)))
	if lock_age < 0 or index >= lock_clip.regions.size():
		grip_flash.hide()
		return
	grip_flash.region_rect = lock_clip.regions[index]
	grip_flash.position = to_local(at) - Vector2(lock_clip.anchor)
	grip_flash.show()

func begin_flight(at: Vector2, ground: Vector2, initial_motion: Vector2) -> void:
	stage = Stage.FLIGHT
	front_jaw.hide()
	grip_flash.hide()
	lock_age = -1.0
	throw_basis = get_canvas_transform()
	release_height = shadow_height
	last_motion = initial_motion.normalized()
	direction_row = _row_for(initial_motion, direction_row)
	trail.clear()
	trail_clock = 0.0
	show_flight(at, ground, Vector2.ZERO, 0.0, 1.0)

func _row_for(world_motion: Vector2, previous: int) -> int:
	var screen_motion := throw_basis.x * world_motion.x + throw_basis.y * world_motion.y
	if screen_motion.length_squared() < 0.01:
		return previous
	var octant := posmod(int(floor((screen_motion.angle() + PI / 8.0) / (PI / 4.0))), 8)
	return octants[octant]

func show_flight(at: Vector2, ground: Vector2, motion: Vector2, delta: float, air_ratio: float) -> void:
	if motion.length_squared() >= 0.01:
		direction_row = _row_for(motion, direction_row)
		last_motion = motion.normalized()
	shadow_at = ground
	shadow_height = release_height * air_ratio
	_show_xiaoyi(flight_frames[direction_row], flight_anchor, at)
	trail_clock += delta
	if trail_clock >= 0.034:
		trail_clock -= 0.034
		trail.append({"at": at, "left": TRAIL_TIME})

func land(at: Vector2, short_skid: bool) -> void:
	stage = Stage.GROUND
	ground_pose_left = GROUND_POSE_TIME
	_show_xiaoyi(ground_frames[direction_row], ground_anchor, at)
	skid_at = at
	skid_age = 0.0
	skid_angle = last_motion.angle()
	skid_scale = Vector2(0.58 if short_skid else 0.90, 0.84)
	_clip_skid()
	fx_layer.queue_redraw()

func override_player() -> bool:
	return stage != Stage.NONE

func release_carried() -> void:
	if stage in [Stage.GRIPPED, Stage.FLIGHT]:
		stage = Stage.NONE
		player_sprite.hide()
	front_jaw.hide()
	grip_flash.hide()
	lock_age = -1.0
	queue_redraw()

func clear() -> void:
	release_carried()
	stage = Stage.NONE
	player_sprite.hide()
	skid_age = -1.0
	skid_limits.clear()
	trail.clear()
	fx_layer.queue_redraw()

func advance(delta: float, ground: Vector2) -> void:
	if lock_age >= 0.0:
		lock_age += delta
	if stage == Stage.GROUND:
		ground_pose_left -= delta
		if ground_pose_left <= 0.0 or ground.distance_to(skid_at) > 7.0:
			stage = Stage.NONE
			player_sprite.hide()
	for i in range(trail.size() - 1, -1, -1):
		trail[i].left -= delta
		if trail[i].left <= 0.0:
			trail.remove_at(i)
	if skid_age >= 0.0:
		skid_age += delta
		if int(floor(skid_age * float(skid_clip.fps))) >= skid_clip.regions.size():
			skid_age = -1.0
		else:
			_clip_skid()
	fx_layer.queue_redraw()

func _draw() -> void:
	if stage in [Stage.GRIPPED, Stage.FLIGHT]:
		var fading := clampf(shadow_height / 70.0, 0.0, 1.0)
		var shadow := PackedVector2Array()
		for i in range(20):
			var rim := Vector2.from_angle(i * TAU / 20.0) * Vector2(15, 6)
			shadow.append(to_local(shadow_at) + rim)
		draw_colored_polygon(shadow, Color(0.04, 0.035, 0.03, lerpf(0.36, 0.13, fading)))

func _skid_edge(angle: float, frame: Rect2) -> float:
	# Ray stops at the edge of this frame, or sooner if it hits level geometry.
	var local := Vector2.from_angle(angle - skid_angle) / skid_scale
	var anchor: Vector2 = skid_clip.anchor
	var bound := Vector2(frame.size.x - anchor.x if local.x >= 0 else anchor.x,
		frame.size.y - anchor.y if local.y >= 0 else anchor.y) - Vector2(0.5, 0.5)
	var extent := minf(bound.x / maxf(absf(local.x), 0.00001), bound.y / maxf(absf(local.y), 0.00001))
	var ray := PhysicsRayQueryParameters2D.create(skid_at, skid_at + Vector2.from_angle(angle) * extent, WORLD)
	ray.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return extent if hit.is_empty() else maxf(0.0, skid_at.distance_to(hit.position) - 0.25)

func _clip_skid() -> void:
	var clip_bounds: Rect2 = skid_clip.regions[0]
	var step := TAU / SKID_RAYS
	skid_limits.resize(SKID_RAYS)
	var previous := _skid_edge(0.0, clip_bounds)
	for i in range(SKID_RAYS):
		var next := _skid_edge((i + 1) * step, clip_bounds)
		skid_limits[i] = minf(previous, minf(next, _skid_edge((i + 0.5) * step, clip_bounds)))
		previous = next

func _skid_uv(point: Vector2, frame: Rect2, texture_size: Vector2) -> Vector2:
	return (frame.position + Vector2(skid_clip.anchor) + point.rotated(-skid_angle) / skid_scale) / texture_size

func _draw_fx() -> void:
	for mark in trail:
		var texture := flight_frames[direction_row]
		var at := fx_layer.to_local(mark.at) - flight_anchor
		fx_layer.draw_texture(texture, at, Color(0.85, 0.81, 0.72, 0.27 * float(mark.left) / TRAIL_TIME))
	if skid_age < 0.0:
		return
	var index := int(floor(skid_age * float(skid_clip.fps)))
	var frame: Rect2 = skid_clip.regions[index]
	var atlas: Texture2D = skid_clip.texture
	var size := atlas.get_size()
	var origin := fx_layer.to_local(skid_at)
	var uv0 := _skid_uv(Vector2.ZERO, frame, size)
	var tint := PackedColorArray([Color.WHITE])
	for i in range(skid_limits.size()):
		if skid_limits[i] < 0.05:
			continue
		var a := Vector2.from_angle(i * TAU / SKID_RAYS) * skid_limits[i]
		var b := Vector2.from_angle((i + 1) * TAU / SKID_RAYS) * skid_limits[i]
		fx_layer.draw_polygon(PackedVector2Array([origin, origin + a, origin + b]), tint,
			PackedVector2Array([uv0, _skid_uv(a, frame, size), _skid_uv(b, frame, size)]), atlas)
