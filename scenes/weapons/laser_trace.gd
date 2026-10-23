extends RefCounted

static func distance_to_boundary(origin: Vector2, direction: Vector2, bounds: Rect2) -> float:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	if origin.x < bounds.position.x or origin.y < bounds.position.y or origin.x > bounds.end.x or origin.y > bounds.end.y:
		return 0.0
	var distance := INF
	if absf(direction.x) > 0.000001:
		var edge_x := bounds.end.x if direction.x > 0.0 else bounds.position.x
		distance = minf(distance, (edge_x - origin.x) / direction.x)
	if absf(direction.y) > 0.000001:
		var edge_y := bounds.end.y if direction.y > 0.0 else bounds.position.y
		distance = minf(distance, (edge_y - origin.y) / direction.y)
	return maxf(0.0, distance) if is_finite(distance) else 0.0


static func trace(space: PhysicsDirectSpaceState2D, origin: Vector2, direction: Vector2, length: float) -> Dictionary:
	var points := PackedVector2Array([origin])
	var result := {"points": points, "target": null, "hit": false}
	if direction.is_zero_approx() or length <= 0.0:
		return result
	var end := origin + direction.normalized() * length
	var query := PhysicsRayQueryParameters2D.create(origin, end, 5)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		points.append(end)
	else:
		result.hit = true
		points.append(hit.position)
		var collider := hit.collider as CollisionObject2D
		if collider != null and (collider.collision_layer & 1) == 0:
			result.target = collider
	result.points = points
	return result
