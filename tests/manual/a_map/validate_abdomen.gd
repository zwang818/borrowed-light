extends SceneTree
## Actual physics/data checks for the approved vertical map, not P1 combat acceptance.
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _walk(actor: CharacterBody2D, points: PackedVector2Array) -> void:
	for target in points:
		var count := 0
		while actor.position.distance_to(target) > 3 and count < 180:
			await physics_frame
			actor.velocity = actor.position.direction_to(target) * minf(900, actor.position.distance_to(target) * 60)
			actor.move_and_slide()
			count += 1
		_check(actor.position.distance_to(target) <= 3, "Route blocked at " + str(target) + "; actor=" + str(actor.position))
		if count >= 180:
			return

func _route(group: Node2D, map: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for waypoint in group.get_children():
		points.append(map.to_local(waypoint.global_position))
	return points

func _can_bypass_gun(actor: CharacterBody2D, map: Node2D, target: Vector2, gun: Vector2) -> bool:
	# Explore legal body centers on a fine grid while excluding the reference pickup range.
	# This checks that the weapon sits on a compulsory route rather than on a skippable desk.
	var space := root.world_2d.direct_space_state
	var bounds: Rect2 = map.get_meta("map_bounds")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = actor.get_node("Collision").shape
	query.collision_mask = 1
	var start := Vector2i(actor.position / 16)
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var point := Vector2(cell) * 16
		if point.distance_to(target) < 20:
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			var next_point := Vector2(next) * 16
			if seen.has(next) or not bounds.has_point(next_point) or next_point.distance_to(gun) <= 40:
				continue
			seen[next] = true
			query.transform = Transform2D(0, map.to_global(next_point))
			if space.intersect_shape(query).is_empty():
				queue.append(next)
	return false

func _run() -> void:
	var packed := load("res://tests/manual/a_map/abdomen_preview.tscn") as PackedScene
	if packed == null:
		quit(1)
		return
	var preview := packed.instantiate()
	root.add_child(preview)
	var map: Node2D = preview.get_node("Map")
	var actor: CharacterBody2D = preview.get_node("Actor")
	var door: Node2D = preview.get_node("TestDoor")
	actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	_check(map.get_meta("layout_revision") == 2, "Old horizontal map is still active")
	var ids := {}
	var rooms := {}
	var cleaners: Array[Node] = []
	for room in map.get_node("Rooms").get_children():
		var rid: String = room.get_meta("room_id")
		_check(not rooms.has(rid), "Duplicate room: " + rid)
		rooms[rid] = room
	for marker in map.get_node("Markers").get_children():
		_check(not marker.object_id.is_empty() and not ids.has(marker.object_id), "Missing/duplicate object ID: " + marker.object_id)
		ids[marker.object_id] = marker
		_check(rooms.has(marker.room_id), "Unknown room: " + marker.object_id)
		if rooms.has(marker.room_id):
			_check(Geometry2D.is_point_in_polygon(map.to_local(marker.global_position), rooms[marker.room_id].polygon), "Marker outside its room: " + marker.object_id)
		if marker.object_type == "cleaner":
			cleaners.append(marker)
		_check(marker.object_type != "sentry", "Discarded sentry marker remains")
	for marker in ids.values():
		for linked_id in marker.linked_ids:
			_check(ids.has(linked_id), "Broken object link: " + linked_id)
		if marker.object_type == "exit":
			_check(ids.has(marker.target_entry_id), "Broken exit: " + marker.object_id)
			if ids.has(marker.target_entry_id):
				var entry = ids[marker.target_entry_id]
				_check(entry.room_id == marker.target_room_id and entry.object_type == "spawn", "Wrong exit target: " + marker.object_id)
	_check(cleaners.size() == 3, "Concept requires exactly three cleaner markers")
	var first_count := 0
	var final_count := 0
	for cleaner in cleaners:
		if cleaner.position.y >= 1440 and cleaner.position.y < 1728:
			first_count += 1
		if cleaner.position.y >= 256 and cleaner.position.y < 640:
			final_count += 1
		_check(not Geometry2D.is_point_in_polygon(cleaner.position, map.get_node("Rooms/Workshop").polygon), "Cleaner is inside safe workshop")
	_check(first_count == 1 and final_count == 2, "Enemy placement must be one first + two at exit")
	_check(map.get_node("Rooms/Workshop").get_meta("safe_zone") and map.get_node("Rooms/Workshop").get_meta("no_enemy_spawn"), "Workshop safety data missing")
	_check(ids["p1_record_01"].room_id == "p1_workshop_01", "Blueprint is not in workshop")
	var area_ids := {}
	for area in map.get_node("ExplorationRegions").get_children():
		var aid: String = area.get_meta("area_id")
		_check(not area_ids.has(aid) and rooms.has(area.get_meta("room_id")), "Invalid exploration region: " + aid)
		area_ids[aid] = true
	var rectangles := 0
	var chamfers := 0
	for wall in map.get_node("Walls").get_children():
		var shadow: OccluderPolygon2D = wall.get_node("Occluder").occluder
		if wall is Polygon2D:
			chamfers += 1
			_check(wall.get_node("Body/Collision").polygon == wall.polygon and shadow.polygon == wall.polygon, "Chamfer collision/shadow mismatch: " + str(wall.name))
		else:
			rectangles += 1
			var shape: RectangleShape2D = wall.get_node("Body/Collision").shape
			_check(shape.size == wall.size and shadow.polygon == PackedVector2Array([Vector2.ZERO, Vector2(wall.size.x, 0), wall.size, Vector2(0, wall.size.y)]), "Rectangle collision/shadow mismatch: " + str(wall.name))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = actor.get_node("Collision").shape
	query.collision_mask = 1
	for marker in ids.values():
		if marker.object_type in ["door", "exit"]:
			continue
		query.transform = Transform2D(0, marker.global_position)
		_check(root.world_2d.direct_space_state.intersect_shape(query).is_empty(), "No body clearance: " + marker.object_id)
	_check(actor.test_move(Transform2D(0, Vector2(608, 2400)), Vector2(0, -128)), "Teaching baffle allows passage")
	_check(actor.test_move(Transform2D(0, Vector2(224, 2496)), Vector2(-64, 0)), "Outer wall allows passage")
	_check(actor.test_move(Transform2D(0, Vector2(640, 288)), Vector2(0, -160)), "Closed exit door allows passage")
	_check(actor.test_move(Transform2D(0, Vector2(928, 1536)), Vector2(-160, 0)), "Workshop can be entered through a solid side wall")
	var ray := PhysicsRayQueryParameters2D.create(ids["abdomen_cleaner_01"].position, ids["p1_record_01"].position, 1)
	_check(not root.world_2d.direct_space_state.intersect_ray(ray).is_empty(), "First cleaner has direct sightline to blueprint table")
	_check(not _can_bypass_gun(actor, map, Vector2(640, 1568), ids["p1_pulse_pickup"].position), "Weapon pickup can be bypassed on route to first fight")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	key.pressed = true
	preview._unhandled_key_input(key)
	_check(preview._overview and preview.get_node("Camera").zoom.x < 1.1, "Overview shortcut does not fit vertical map")
	preview._unhandled_key_input(key)
	_check(not preview._overview and preview.get_node("Camera").zoom.is_equal_approx(Vector2.ONE * 1.1), "Follow camera did not restore")
	print("A_MAP_V2: data, safe-room placement, compulsory weapon threshold and collision checks finished")
	# Visit the side room at its junction, resume the main route, then return from the landing.
	var main_points := _route(map.get_node("RouteWaypoints/MainRoute"), map)
	var branch := _route(map.get_node("RouteWaypoints/WorkshopRoute"), map)
	door.set_open(true)
	await physics_frame
	await physics_frame
	var before := PackedVector2Array()
	var after := PackedVector2Array()
	var reached_junction := false
	for point in main_points:
		if not reached_junction:
			before.append(point)
		else:
			after.append(point)
		if point == branch[0]:
			reached_junction = true
	_check(reached_junction, "Workshop branch has no main-route junction")
	await _walk(actor, before)
	await _walk(actor, branch)
	branch.reverse()
	await _walk(actor, branch)
	await _walk(actor, after)
	main_points.reverse()
	await _walk(actor, main_points)
	var spawn_position := actor.position
	actor.position = door.position
	key.physical_keycode = KEY_P
	preview._unhandled_key_input(key)
	_check(door.is_open, "Test door closed on actor")
	actor.position = spawn_position
	preview._unhandled_key_input(key)
	await physics_frame
	await physics_frame
	_check(not door.is_open and not door.get_node("Body/Collision").disabled, "Test door did not close away from actor")
	# Descriptor positions stay map-local even when C instances the map away from the origin.
	map.position = Vector2(240, -96)
	for marker in map.get_node("Markers").get_children():
		_check(map.to_local(marker.global_position).is_equal_approx(marker.position), "Descriptor is not map-local: " + marker.object_id)
	print("A_MAP_V2: ", ids.size(), " objects, ", rooms.size(), " rooms, ", area_ids.size(), " regions, ", rectangles, " rectangular walls + ", chamfers, " chamfers")
	print("A_MAP_V2: ", "PASS (concept placement, IDs, links, safe workshop, gun threshold, collisions, complete route + branch + return)" if _failures.is_empty() else "FAIL " + str(_failures))
	preview.free()
	quit(0 if _failures.is_empty() else 1)
