extends RefCounted
## Geometry shared by the clearance warning, wave atlas and damage.
const PLANE := Vector2(1.0, 0.68)
const INNER_RADIUS := 150.0
const ATLAS_INNER_RADIUS := 110.0
const ATLAS_OUTER_RADIUS := 226.0
const ATLAS_DRAW_RADIUS := 238.0
const SLICES := 144
const STEP := TAU / SLICES
const GAP_HALF := STEP * 4.0
const FRONT_HALF := deg_to_rad(60.0)
const MIN_APPROACH_RADIUS := 50.0
const SILK_RADIUS := 50.0
const FOOT_MARGIN := 9.0
const WORLD := 1

static func point_at(origin: Vector2, angle: float, radius: float) -> Vector2:
	return origin + Vector2.from_angle(angle) * PLANE * radius

static func arena_corners(arena: Rect2) -> PackedVector2Array:
	return PackedVector2Array([arena.position, Vector2(arena.end.x, arena.position.y),
		arena.end, Vector2(arena.position.x, arena.end.y)])

static func room_radius(origin: Vector2, arena: Rect2) -> float:
	var reach := INNER_RADIUS + 1.0
	for corner in arena_corners(arena):
		reach = maxf(reach, ((corner - origin) / PLANE).length())
	return reach

static func atlas_quake_radius(world_radius: float, outer_radius: float) -> float:
	if world_radius <= INNER_RADIUS:
		return world_radius * ATLAS_INNER_RADIUS / INNER_RADIUS
	return remap(world_radius, INNER_RADIUS, outer_radius, ATLAS_INNER_RADIUS, ATLAS_OUTER_RADIUS)

static func in_gap(origin: Vector2, point: Vector2, angle: float) -> bool:
	var off := (point - origin) / PLANE
	return off.length_squared() > 0.0001 and absf(wrapf(off.angle() - angle, -PI, PI)) <= GAP_HALF

static func path_to_gap(body: CharacterBody2D, origin: Vector2, arena: Rect2, budget: float, facing_right: bool) -> Dictionary:
	var start := body.global_position
	var offset := start - origin
	var planar := offset / PLANE
	var initial := planar.angle()
	var facing_angle := 0.0 if facing_right else PI
	var side_and_rear: Array[float] = []
	var front: Array[float] = []
	for slice in range(SLICES):
		var angle := slice * STEP
		if absf(wrapf(angle - facing_angle, -PI, PI)) >= FRONT_HALF:
			side_and_rear.append(angle)
		else:
			front.append(angle)
	side_and_rear.shuffle()
	front.shuffle()
	side_and_rear.append_array(front)
	var start_radius := planar.length()
	var min_radius := minf(start_radius, MIN_APPROACH_RADIUS)
	var lane_half := GAP_HALF - STEP
	for angle in side_and_rear:
		var inset := clampf(wrapf(initial - angle, -PI, PI), -lane_half, lane_half)
		var lane := Vector2.from_angle(angle + inset) * PLANE
		# The closest point on this safe lane can be a short diagonal inward.
		var radius := clampf(offset.dot(lane) / lane.length_squared(), min_radius, start_radius)
		var arrival := origin + lane * radius
		if arrival.distance_to(start) > budget or not arena.has_point(arrival):
			continue
		if not start.is_equal_approx(arrival) and body.test_move(body.global_transform, arrival - start):
			continue
		var onward := origin + lane * (radius + 18.0)
		var pose := body.global_transform
		pose.origin = arrival
		if arena.has_point(onward) and not body.test_move(pose, onward - arrival):
			return {"angle": angle, "entry": arrival, "onward": onward}
	# A player pinned against a wall or stacked silk can keep their foothold.
	return {"angle": snappedf(initial, STEP), "entry": start, "onward": start}

static func protected_wedge(origin: Vector2, angle: float, radius: float) -> PackedVector2Array:
	return PackedVector2Array([origin, point_at(origin, angle - GAP_HALF, radius),
		point_at(origin, angle + GAP_HALF, radius)])

static func seal_spots(space: PhysicsDirectSpaceState2D, origin: Vector2, angle: float, start: Vector2,
		entry: Vector2, onward: Vector2, arena: Rect2) -> PackedVector2Array:
	var spots := PackedVector2Array()
	var wedge := protected_wedge(origin, angle, room_radius(origin, arena) * 1.1)
	for side in [-1.0, 1.0]:
		var spot := _seal_one_side(space, origin, angle, side, start, entry, onward, arena, wedge)
		if spot.is_finite():
			spots.append(spot)
	return spots

static func _seal_one_side(space: PhysicsDirectSpaceState2D, origin: Vector2, angle: float, side: float,
		start: Vector2, entry: Vector2, onward: Vector2, arena: Rect2, wedge: PackedVector2Array) -> Vector2:
	var clearance := SILK_RADIUS + FOOT_MARGIN
	for turn in [66.0, 80.0, 94.0, 112.0, 138.0]:
		for distance in [114.0, 144.0, 174.0]:
			var desired := point_at(origin, angle + deg_to_rad(turn) * side, distance)
			var spot := floor_point(space, origin, desired, arena.grow(-3.0), 2.0)
			if origin.distance_to(spot) < SILK_RADIUS or in_gap(origin, spot, angle):
				continue
			if _distance_to_segment(spot, wedge[0], wedge[1]) < clearance or _distance_to_segment(spot, wedge[0], wedge[2]) < clearance:
				continue
			if _distance_to_segment(spot, start, entry) >= clearance and _distance_to_segment(spot, entry, onward) >= clearance:
				return spot
	return Vector2.INF

static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var nearest := a if a.is_equal_approx(b) else Geometry2D.get_closest_point_to_segment(point, a, b)
	return nearest.distance_to(point)

static func _arena_point(from: Vector2, to: Vector2, arena: Rect2) -> Vector2:
	var step := to - from
	var fraction := 1.0
	for axis in range(2):
		if not is_zero_approx(step[axis]):
			var bound := arena.end[axis] if step[axis] > 0.0 else arena.position[axis]
			fraction = minf(fraction, (bound - from[axis]) / step[axis])
	return from + step * clampf(fraction, 0.0, 1.0)

static func floor_point(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, arena: Rect2,
		wall_inset := 0.5) -> Vector2:
	var end := _arena_point(from, to, arena)
	if end.is_equal_approx(from):
		return from
	var ray := PhysicsRayQueryParameters2D.create(from, end, WORLD)
	ray.hit_from_inside = true
	var hit := space.intersect_ray(ray)
	return end if hit.is_empty() else Vector2(hit.position).move_toward(from, wall_inset)

static func arena_limits(origin: Vector2, arena: Rect2,
		plane: Vector2, radius: float, slices: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var step := TAU / slices
	var last := _radial_limit(origin, arena, Vector2.RIGHT * plane * radius, plane)
	for i in range(slices):
		var edge := Vector2.from_angle((i + 1) * step) * plane * radius
		var middle := Vector2.from_angle((i + 0.5) * step) * plane * radius
		var next := _radial_limit(origin, arena, edge, plane)
		result.append(minf(last, minf(next, _radial_limit(origin, arena, middle, plane))))
		last = next
	return result

static func _radial_limit(origin: Vector2, arena: Rect2, offset: Vector2, plane: Vector2) -> float:
	return ((_arena_point(origin, origin + offset, arena) - origin) / plane).length()

static func covers(arena: Rect2, origin: Vector2, point: Vector2, limits: PackedFloat32Array, plane := PLANE) -> bool:
	if not arena.has_point(point) or limits.is_empty():
		return false
	var relative := (point - origin) / plane
	var slice := mini(int(fposmod(relative.angle(), TAU) / TAU * limits.size()), limits.size() - 1)
	return relative.length() <= limits[slice] + 0.00001
