extends RefCounted
## Local routes use the same solid geometry and clearance as CharacterBody2D.
const CELL_SIZE := 16.0
const MAX_PROBE_DISTANCE := 416.0
const SEARCH_MARGINS := [48.0, 128.0]
const NEIGHBORS := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]

static func find_route(body: CharacterBody2D, destination: Vector2, stop_distance: float) -> PackedVector2Array:
	var origin := body.global_position
	var local_goal := origin.move_toward(destination, MAX_PROBE_DISTANCE)
	var partial := not local_goal.is_equal_approx(destination)
	for margin: float in SEARCH_MARGINS:
		var route := _search(body, local_goal, 0.0 if partial else stop_distance, margin, partial)
		if not route.is_empty():
			return route
	return PackedVector2Array()

static func can_travel(body: CharacterBody2D, from: Vector2, to: Vector2) -> bool:
	var transform_at_start := body.global_transform
	transform_at_start.origin = from
	return not body.test_move(transform_at_start, to - from)

static func has_clear_line(body: CharacterBody2D, from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):
		return true
	var query := PhysicsRayQueryParameters2D.create(from, to, body.collision_mask)
	query.hit_from_inside = true
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

static func _search(body: CharacterBody2D, goal: Vector2, stop_distance: float, margin: float, partial: bool) -> PackedVector2Array:
	var origin := body.global_position
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO).expand(goal - origin).grow(margin)
	var first := Vector2i((bounds.position / CELL_SIZE).floor())
	var last := Vector2i((bounds.end / CELL_SIZE).ceil())
	var collider := body.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collider.shape
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	var space := body.get_world_2d().direct_space_state
	var graph := AStar2D.new()
	var grid := {}
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var point := origin + Vector2(cell) * CELL_SIZE
			var pose := body.global_transform
			pose.origin = point
			query.transform = pose * collider.transform
			if cell != Vector2i.ZERO and not space.intersect_shape(query, 1).is_empty():
				continue
			var id := graph.get_available_point_id()
			graph.add_point(id, point)
			grid[cell] = id
			for offset in NEIGHBORS:
				var neighbor: Vector2i = cell + offset
				if grid.has(neighbor) and can_travel(body, point, graph.get_point_position(grid[neighbor])):
					graph.connect_points(id, grid[neighbor])

	var goal_id := graph.get_available_point_id()
	graph.add_point(goal_id, goal)
	var goal_search_distance := stop_distance + 2.0 * CELL_SIZE
	for cell: Vector2i in grid:
		var id: int = grid[cell]
		var point := graph.get_point_position(id)
		if point.distance_squared_to(goal) > goal_search_distance * goal_search_distance:
			continue
		var approach := goal.move_toward(point, stop_distance)
		if not can_travel(body, point, approach):
			continue
		if stop_distance > 0.0 and not has_clear_line(body, approach, goal):
			continue
		var approach_id := graph.get_available_point_id()
		graph.add_point(approach_id, approach)
		graph.connect_points(id, approach_id, false)
		graph.connect_points(approach_id, goal_id, false)
	var raw := graph.get_point_path(grid[Vector2i.ZERO], goal_id, partial)
	if not raw.is_empty() and raw[-1].is_equal_approx(goal):
		raw.remove_at(raw.size() - 1) # The virtual goal may be beyond the melee stand-off.
	return _shortcut(body, raw)

static func _shortcut(body: CharacterBody2D, raw: PackedVector2Array) -> PackedVector2Array:
	var route := PackedVector2Array()
	var current := 0
	while current + 1 < raw.size():
		var next := raw.size() - 1
		while next > current + 1 and not can_travel(body, raw[current], raw[next]):
			next -= 1
		route.append(raw[next])
		current = next
	return route
