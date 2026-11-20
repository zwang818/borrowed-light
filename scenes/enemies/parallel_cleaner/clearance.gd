extends Node2D
## Half-health attack. Body frames, ground atlas and hit checks share action time.
signal event_reached(event: StringName)
signal shake_requested(offsets: PackedVector2Array)
signal silk_requested(at: Vector2)

const GEO := preload("res://scenes/enemies/parallel_cleaner/clearance_geometry.gd")
const GROUND_FX := preload("res://scenes/enemies/parallel_cleaner/ground_fx.gd")
const ART := "res://assets/sprites/enemies/parallel_cleaner/"
const INNER_TIME := 1.0
const OUTER_TIME := 1.35
const INNER_TRAVEL := 0.30
const OUTER_TRAVEL := 0.45
const TRAVEL_EASE := 1.42
const FINISHER_RADIUS := 80.0
const REACTION_MARGIN := 0.18
const EPS := 0.00001
const NEAR_COLOR := Color(0.88, 0.52, 0.24, 0.80)
const OUTER_COLOR := Color(0.78, 0.42, 0.21, 0.75)
const GAP_COLOR := Color(0.56, 0.83, 0.73, 0.76)

var clock := 0.0
var hitstop := 0.0
var confirmed_hit: StringName = &""
var active := false
var origin := Vector2.ZERO
var face_right := true
var arena := Rect2()
var gap_angle := 0.0
var gap_entry := Vector2.ZERO
var gap_onward := Vector2.ZERO
var gap_wedge := PackedVector2Array()
var silk_spots := PackedVector2Array()
var outer_radius := 0.0
var wave_slices: Array[Dictionary] = []
var room_warning_edges: Array[PackedVector2Array] = []
var gap_edges: Array[PackedVector2Array] = []
var finisher_at := Vector2.ZERO
var finisher_nominal := Vector2.ZERO
var finisher_limits := PackedFloat32Array()
var previous_feet := Vector2.ZERO
var body: Dictionary
var finisher: Dictionary
var quake: Texture2D
var quake_frames: Array[Rect2] = []
var quake_pivot := Vector2.ZERO
var quake_start := 0.9
var quake_fps := 60.0
var time_to_finisher := 1.47
var finisher_warning := 1.58
var finisher_contact := 2.0
var duration := 2.62
var hold_time := 0.067
var events: Array[Dictionary] = []
var beat_impulses: Dictionary = {}
var finisher_ground: GROUND_FX

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body = _load_body("clearance_body", 7)
	finisher = _load_body("clearance_finisher", 6)
	var folder := ART + "clearance_quake/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "borrowed-light-clearance-quake.json"))
	var planar: Dictionary = manifest.meta.pixelfx
	var info: Dictionary = manifest.meta.borrowed_light
	quake = load(folder + str(manifest.meta.image)) as Texture2D
	quake_pivot = _pair(planar.pivot)
	quake_fps = float(planar.fps)
	quake_start = float(info.pose_timeline_start_ms) * 0.001
	for item: Dictionary in manifest.frames:
		var rect: Dictionary = item.frame
		quake_frames.append(Rect2(rect.x, rect.y, rect.w, rect.h))
	for beat: Dictionary in info.camera_impulses:
		var offsets := PackedVector2Array()
		for offset: Array in beat.offsets_px_60fps:
			offsets.append(_pair(offset))
		beat_impulses[StringName(beat.pose_event)] = offsets
	time_to_finisher = float(finisher.manifest.recommended_ultimate_start_ms) * 0.001
	duration = time_to_finisher + float(finisher.manifest.duration_ms) * 0.001
	hold_time = float(body.manifest.extra_hitstop_ms_on_confirmed_damage) * 0.001
	events.assign(body.events)
	for entry: Dictionary in finisher.events:
		events.append({"event": entry.event, "at": entry.at + time_to_finisher})
		if entry.event == &"begin_finisher_warning":
			finisher_warning = entry.at + time_to_finisher
		elif entry.event == &"ground_contact":
			finisher_contact = entry.at + time_to_finisher

func _load_body(directory: String, count: int) -> Dictionary:
	var path := ART + directory + "/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "frames.json"))
	var atlas := load(path + str(manifest.atlas)) as Texture2D
	var poses: Array[AtlasTexture] = []
	var times := PackedFloat32Array()
	var marks: Array[Dictionary] = []
	for i in range(count):
		var frame: Dictionary = manifest.frames[i]
		var r: Array = frame.rect
		var pose := AtlasTexture.new()
		pose.atlas = atlas
		pose.region = Rect2(r[0], r[1], r[2], r[3])
		pose.filter_clip = true
		poses.append(pose)
		var at := float(frame.start_ms) * 0.001
		times.append(at)
		if frame.has("event"):
			marks.append({"event": StringName(frame.event), "at": at})
	return {"manifest": manifest, "poses": poses, "times": times, "events": marks,
		"foot": _pair(manifest.foot_anchor), "mirror_foot": _pair(manifest.mirror_foot_anchor)}

func _pair(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))

func start(at: Vector2, right: bool, scale_hint: float, room_bounds: Rect2, player: CharacterBody2D,
		travel_speed: float, ground: GROUND_FX) -> void:
	active = true
	origin = at
	arena = room_bounds
	previous_feet = player.global_position
	finisher_ground = ground
	var plan := GEO.path_to_gap(player, origin, arena, travel_speed * (INNER_TIME - REACTION_MARGIN), right)
	gap_angle = plan.angle
	gap_entry = plan.entry
	gap_onward = plan.onward
	outer_radius = GEO.room_radius(origin, arena)
	gap_wedge = GEO.protected_wedge(origin, gap_angle, outer_radius * 1.1)
	var space := get_world_2d().direct_space_state
	silk_spots = GEO.seal_spots(space, origin, gap_angle, previous_feet, gap_entry, gap_onward, arena)
	face_right = right
	finisher_nominal = _finisher_contact_point(face_right, scale_hint)
	finisher_at = _clip_finisher(space, finisher_nominal)
	if GEO.in_gap(origin, finisher_at, gap_angle):
		var mirrored := _finisher_contact_point(not face_right, scale_hint)
		var landing := _clip_finisher(space, mirrored)
		if not GEO.in_gap(origin, landing, gap_angle):
			finisher_nominal = mirrored
			finisher_at = landing
			face_right = not face_right
	_prepare_wave_mesh()
	event_reached.emit(&"begin_clearance_warning")
	queue_redraw()

func _finisher_contact_point(right: bool, scale_hint: float) -> Vector2:
	var contact: Dictionary = finisher.manifest.frames[int(finisher.manifest.contact_index)]
	var offset := _pair(contact.impact_point) - Vector2(finisher.foot) if right else (
		_pair(contact.mirror_impact_point) - Vector2(finisher.mirror_foot))
	return origin + offset * scale_hint

func _clip_finisher(space: PhysicsDirectSpaceState2D, nominal: Vector2) -> Vector2:
	return GEO.floor_point(space, origin, nominal, arena.grow(-1.0), 1.25)

func pose_index() -> int:
	var finishing := clock + EPS >= time_to_finisher
	var sequence: Dictionary = finisher if finishing else body
	var age := clock - time_to_finisher if finishing else clock
	var times: PackedFloat32Array = sequence.times
	for i in range(times.size() - 1, 0, -1):
		if age + EPS >= times[i]:
			return i
	return 0

func pose_texture() -> Texture2D:
	var sequence: Dictionary = finisher if clock + EPS >= time_to_finisher else body
	return sequence.poses[pose_index()]

func foot() -> Vector2:
	var sequence: Dictionary = finisher if clock + EPS >= time_to_finisher else body
	return sequence.foot if face_right else sequence.mirror_foot

func quake_index() -> int:
	var index := int(floor((clock - quake_start + EPS) * quake_fps))
	return index if index >= 0 and index < quake_frames.size() else -1

func confirm_hit(source: StringName) -> void:
	confirmed_hit = source
	hitstop = hold_time

func advance(delta: float, feet: Vector2, can_hit: bool) -> StringName:
	if hitstop > 0.0:
		var held := minf(hitstop, delta)
		hitstop -= held
		delta -= held
		previous_feet = feet
		if delta <= EPS:
			return &""
	var before := clock
	clock = minf(clock + delta, duration)
	_refresh_finisher(before)
	var source: StringName = &""
	for mark: Dictionary in events:
		if before + EPS < mark.at and clock + EPS >= mark.at:
			_cross_event(mark.event, feet)
			if mark.event == &"ground_contact" and can_hit and confirmed_hit == &"" and _finisher_contains(feet):
				source = &"ground_contact"
	if can_hit and confirmed_hit == &"" and source == &"":
		if _wave_crosses(INNER_TIME, INNER_TRAVEL, 12.0, GEO.ATLAS_INNER_RADIUS, before, feet):
			source = &"inner_sweep_contact"
		elif _wave_crosses(OUTER_TIME, OUTER_TRAVEL, 27.0, GEO.ATLAS_OUTER_RADIUS, before, feet, GEO.ATLAS_INNER_RADIUS):
			source = &"outer_sweep_contact"
	previous_feet = feet
	_update_finisher()
	queue_redraw()
	return source

func _cross_event(event: StringName, feet: Vector2) -> void:
	if event == &"cast_ground_silk":
		for spot in silk_spots:
			silk_requested.emit(spot)
	elif beat_impulses.has(event):
		shake_requested.emit(beat_impulses[event])
	elif event == &"ground_contact":
		var strength := lerpf(0.17, 1.0, 1.0 - clampf(feet.distance_to(finisher_at) / 200.0, 0.0, 1.0))
		var offsets := PackedVector2Array([Vector2(0, 3), Vector2(-2, -2), Vector2(2, 1), Vector2(-1, -1), Vector2(0, 1), Vector2.ZERO])
		for i in range(offsets.size()):
			offsets[i] *= strength
		shake_requested.emit(offsets)
	event_reached.emit(event)

func _refresh_finisher(before: float) -> void:
	if clock + EPS < finisher_warning or before + EPS >= finisher_contact:
		return
	finisher_at = _clip_finisher(get_world_2d().direct_space_state, finisher_nominal)
	finisher_limits = GEO.arena_limits(finisher_at, arena, Vector2.ONE, FINISHER_RADIUS, GROUND_FX.RAYS)

func _floor_covers(point: Vector2) -> bool:
	return arena.has_point(point)

func _wave_radius(age: float, travel: float, seed: float, reach: float) -> float:
	var u := clampf(age / travel, 0.0, 1.0)
	return lerpf(seed, reach, 1.0 - pow(1.0 - u, TRAVEL_EASE))

func _wave_crosses(at: float, travel: float, seed: float, reach: float, before: float, feet: Vector2,
		min_radius := 0.0) -> bool:
	var armed_at := at
	if min_radius > seed:
		armed_at += travel * (1.0 - pow(1.0 - inverse_lerp(seed, reach, min_radius), 1.0 / TRAVEL_EASE))
	var start := maxf(before, armed_at)
	var end := minf(clock, at + travel)
	if end + EPS < start:
		return false
	var age := maxf(clock - before, EPS)
	var p0 := previous_feet.lerp(feet, clampf((start - before) / age, 0.0, 1.0))
	var p1 := previous_feet.lerp(feet, clampf((end - before) / age, 0.0, 1.0))
	# Test in atlas units so each wave stays on the visible ripple during the stretch.
	var r0 := GEO.atlas_quake_radius(((p0 - origin) / GEO.PLANE).length(), outer_radius)
	var r1 := GEO.atlas_quake_radius(((p1 - origin) / GEO.PLANE).length(), outer_radius)
	var d0 := r0 - _wave_radius(start - at, travel, seed, reach)
	var d1 := r1 - _wave_radius(end - at, travel, seed, reach)
	if d0 * d1 > 0.0:
		return false
	var fraction := clampf(d0 / (d0 - d1), 0.0, 1.0) if absf(d0 - d1) > EPS else 0.0
	var contact := p0.lerp(p1, fraction)
	var radius := GEO.atlas_quake_radius(((contact - origin) / GEO.PLANE).length(), outer_radius)
	return radius >= min_radius - EPS and radius <= reach + EPS and not GEO.in_gap(origin, contact, gap_angle) and _floor_covers(contact)

func _finisher_contains(feet: Vector2) -> bool:
	return not GEO.in_gap(origin, feet, gap_angle) and GEO.covers(
		arena, finisher_at, feet, finisher_limits, Vector2.ONE)

func _update_finisher() -> void:
	finisher_ground.warning = clock + EPS >= finisher_warning and clock + EPS < finisher_contact
	if finisher_ground.warning:
		finisher_ground.warning_point = finisher_at
		finisher_ground.warning_radii = finisher_limits
		finisher_ground.warning_progress = clampf(inverse_lerp(finisher_warning, finisher_contact, clock), 0.0, 1.0)
		finisher_ground.warning_exclusion = gap_wedge
	if clock + EPS >= finisher_contact:
		finisher_ground.impact = {"at": finisher_at, "age": maxf(0.0, clock - finisher_contact),
			"radius": FINISHER_RADIUS, "limits": finisher_limits, "exclude": gap_wedge}

func reset() -> void:
	if active:
		shake_requested.emit(PackedVector2Array())
	if is_instance_valid(finisher_ground):
		finisher_ground.warning = false
		finisher_ground.warning_exclusion.clear()
		finisher_ground.impact.clear()
		finisher_ground.queue_redraw()
	active = false
	clock = 0.0
	hitstop = 0.0
	confirmed_hit = &""
	gap_wedge.clear()
	silk_spots.clear()
	wave_slices.clear()
	room_warning_edges.clear()
	gap_edges.clear()
	finisher_limits.clear()
	queue_redraw()

func _prepare_wave_mesh() -> void:
	var bounds := GEO.arena_corners(Rect2(arena.position - origin, arena.size))
	var perimeter := bounds.duplicate()
	perimeter.append(bounds[0])
	var safe_wedge := PackedVector2Array()
	for point in gap_wedge:
		safe_wedge.append(point - origin)
	room_warning_edges = Geometry2D.clip_polyline_with_polygon(perimeter, safe_wedge)
	for edge in [safe_wedge[1], safe_wedge[2]]:
		gap_edges.append_array(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2.ZERO, edge]), bounds))

	# The extended mesh allows the rectangular room clip to retain all four corners.
	var reach := remap(GEO.ATLAS_DRAW_RADIUS, GEO.ATLAS_INNER_RADIUS, GEO.ATLAS_OUTER_RADIUS,
		GEO.INNER_RADIUS, outer_radius)
	for i in range(GEO.SLICES):
		var a := GEO.point_at(Vector2.ZERO, i * GEO.STEP, 1.0)
		var b := GEO.point_at(Vector2.ZERO, (i + 1) * GEO.STEP, 1.0)
		var inner_a := a * GEO.INNER_RADIUS
		var inner_b := b * GEO.INNER_RADIUS
		var near := _clip_wave_polygon(PackedVector2Array([Vector2.ZERO, inner_a, inner_b]), bounds)
		var far := _clip_wave_polygon(PackedVector2Array([inner_a, a * reach, b * reach, inner_b]), bounds)
		var safe := GEO.in_gap(Vector2.ZERO, a + b, gap_angle)
		wave_slices.append({
			"near": near, "far": far, "safe": safe,
			"near_uv": _wave_uv(near), "far_uv": _wave_uv(far),
			"rim": Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([inner_a, inner_b]), bounds),
		})

func _clip_wave_polygon(polygon: PackedVector2Array, bounds: PackedVector2Array) -> PackedVector2Array:
	var pieces := Geometry2D.intersect_polygons(polygon, bounds)
	return PackedVector2Array() if pieces.is_empty() else pieces[0]

func _wave_uv(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		var radius := (point / GEO.PLANE).length()
		result.append(point * GEO.atlas_quake_radius(radius, outer_radius) / radius if radius > EPS else Vector2.ZERO)
	return result

func _draw() -> void:
	if not active:
		return
	var index := quake_index()
	var tex_size := Vector2(quake.get_size())
	var uv0 := quake_frames[index].position + quake_pivot if index >= 0 else Vector2.ZERO
	var near_warning := clock < INNER_TIME + INNER_TRAVEL
	var outer_warning := clock < OUTER_TIME + OUTER_TRAVEL
	var near_opacity := 0.9 if clock < INNER_TIME else 0.48
	var outer_opacity := 0.8 if clock < OUTER_TIME else 0.45
	for slice in wave_slices:
		if slice.safe:
			if outer_warning:
				_draw_wave_fill(slice.near, Color(GAP_COLOR, 0.06))
				_draw_wave_fill(slice.far, Color(GAP_COLOR, 0.06))
			continue
		if index >= 0:
			_draw_wave_texture(slice.near, slice.near_uv, uv0, tex_size)
			_draw_wave_texture(slice.far, slice.far_uv, uv0, tex_size)
		if near_warning:
			_draw_wave_fill(slice.near, Color(NEAR_COLOR, 0.09 * near_opacity))
		if outer_warning:
			_draw_wave_fill(slice.far, Color(OUTER_COLOR, 0.07 * outer_opacity))
		if near_warning or outer_warning:
			for edge: PackedVector2Array in slice.rim:
				var rim_color := Color(NEAR_COLOR, NEAR_COLOR.a * near_opacity) if near_warning else (
					Color(OUTER_COLOR, OUTER_COLOR.a * outer_opacity * 0.66))
				draw_polyline(edge, rim_color, 1.35)
	if outer_warning:
		for edge in room_warning_edges:
			draw_polyline(edge, Color(OUTER_COLOR, OUTER_COLOR.a * outer_opacity), 1.35)
		for edge in gap_edges:
			draw_polyline(edge, GAP_COLOR, 1.1)

func _draw_wave_fill(polygon: PackedVector2Array, tint: Color) -> void:
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, tint)

func _draw_wave_texture(polygon: PackedVector2Array, source: PackedVector2Array, uv0: Vector2, tex_size: Vector2) -> void:
	if polygon.size() < 3:
		return
	var uv := PackedVector2Array()
	for point in source:
		uv.append((uv0 + point) / tex_size)
	draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, quake)
