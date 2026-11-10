extends SceneTree
## A geometry only; no combat, protocol, crafting, save or cross-level acceptance.
const METRICS = preload("res://scenes/levels/graybox/graybox_metrics.gd")
var failures: Array[String] = []
var preview: Node2D
var map: Node2D
var actor: CharacterBody2D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame

func route(name: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in map.get_node("RouteWaypoints/" + name).get_children():
		points.append(point.global_position)
	return points

func walk(points: PackedVector2Array) -> void:
	for point in points:
		for frame in range(240):
			if actor.global_position.distance_to(point) < 3:
				break
			await physics_frame
			actor.velocity = actor.global_position.direction_to(point) * minf(900, actor.global_position.distance_to(point) * 60)
			actor.move_and_slide()
			if not map.is_walkable_point(actor.global_position):
				check(false, "Actor left a crown/flap: %s" % actor.global_position)
				return
		if actor.global_position.distance_to(point) >= 3:
			check(false, "Blocked route: target=%s actual=%s" % [point, actor.global_position])
			return

func reachable(start: Vector2, target: Vector2) -> bool:
	# Restrict search to top faces; sweep the body between cells so thin gates cannot be skipped.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = actor.get_node("Collision").shape
	query.collision_mask = 1
	var first := Vector2i((start / 16).round())
	var queue: Array[Vector2i] = [first]
	var visited := {first: true}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if (Vector2(cell) * 16).distance_to(target) < 20:
			return true
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			var point := Vector2(next) * 16
			if visited.has(next) or not map.is_walkable_point(point):
				continue
			visited[next] = true
			query.transform = Transform2D(0, Vector2(cell) * 16)
			query.motion = Vector2(direction) * 16
			var safe := root.world_2d.direct_space_state.cast_motion(query)
			if safe[0] >= 0.999:
				query.transform = Transform2D(0, point)
				query.motion = Vector2.ZERO
				if root.world_2d.direct_space_state.intersect_shape(query, 1).is_empty():
					queue.append(next)
	return false

func run() -> void:
	preview = load("res://tests/manual/a_map/spine_preview.tscn").instantiate()
	root.add_child(preview)
	map = preview.map; actor = preview.actor
	actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(not map.has_node("Environment"), "Rejected 3D environment still attached")
	var bounds: Rect2 = map.get_meta("map_bounds")
	check(actor.get_node("Collision").shape.radius == METRICS.BODY_RADIUS, "Actor scale changed")
	var ids := {}; var counts := {"sentry":0,"cleaner":0}
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = actor.get_node("Collision").shape; query.collision_mask = 1
	for marker in map.get_node("Markers").get_children():
		check(not marker.object_id.is_empty() and not ids.has(marker.object_id), "Duplicate ID")
		ids[marker.object_id] = marker
		if counts.has(marker.object_type): counts[marker.object_type] += 1
		if marker.object_type != "door":
			check(map.is_walkable_point(marker.position), "Marker off terrain: " + marker.object_id)
			query.transform = Transform2D(0,marker.position)
			check(root.world_2d.direct_space_state.intersect_shape(query,1).is_empty(), "Blocked marker: " + marker.object_id)
	for marker in ids.values():
		for link in marker.linked_ids: check(ids.has(link), "Missing linked ID")
	check(ids.size()==26 and counts.sentry==6 and counts.cleaner==6, "Enemy reservations mismatch")
	check(not ids["p2_scatter_evolution"].get_meta("grants_ability"), "Blueprint grants scatter")
	check(ids["duct_spine_blueprint"].target_entry_id=="duct_arrival", "Wrong return destination")
	check(ids["p2_shortcut_door"].get_meta("role")=="blocked_maintenance_end", "Branch is still a forward shortcut")
	check(not reachable(actor.position,ids["p2_scatter_evolution"].position), "Protocol gate bypass")
	check(reachable(actor.position,ids["p2_maintenance_record"].position), "Record unavailable before protocol")
	preview.doors[0].set_open(true)
	await physics_frame; await physics_frame
	check(reachable(actor.position,ids["p2_scatter_evolution"].position), "Blueprint unreachable after open")
	check(not reachable(actor.position,ids["p2_thorax_entry"].position), "Exit gate bypass")
	preview.doors[1].set_open(true)
	await physics_frame; await physics_frame
	var main := route("MainRoute")
	var main_length := 0.0
	for i in range(1, main.size()):
		main_length += main[i - 1].distance_to(main[i])
	check(main_length >= 5408.0 * 2.0, "Main route is shorter than twice the revision 3 route")
	for point in main:
		check(bounds.has_point(point), "Main route outside overview bounds")
	print("MAIN_ROUTE_LENGTH: %.1f world units" % main_length)
	await walk(main)
	main.reverse(); await walk(main)
	var points := PackedVector2Array()
	for point in route("MainRoute"):
		points.append(point)
		if point.distance_to(route("RecordRoute")[0])<1: break
	await walk(points)
	var branch := route("RecordRoute")
	await walk(branch); branch.reverse(); await walk(branch)
	# The dead-end must block direct continuation beyond its record console.
	var end: Vector2 = ids["p2_shortcut_door"].position
	check(not map.is_walkable_point(end + Vector2(160,-75)), "Record branch connects forward")
	points = PackedVector2Array()
	var found := false
	for point in route("MainRoute"):
		if point.distance_to(route("RecordRoute")[0])<1: found=true
		if found: points.append(point)
		if point.distance_to(route("DuctRoute")[0])<1: break
	await walk(points)
	var duct := route("DuctRoute")
	await walk(duct); duct.reverse(); await walk(duct)
	for i in range(2):
		preview.selected_door=i; actor.position=preview.doors[i].position
		check(not preview.toggle_selected_door(), "Rotated door crush protection failed")
	actor.position = route("MainRoute")[4]
	for i in range(30):
		await physics_frame
		actor.velocity = Vector2(.422618,.906308) * 600
		actor.move_and_slide()
	check(map.is_walkable_point(actor.position), "Actor escaped outer edge")
	var art: Node2D = map.get_node("SpineArt")
	var pumps := art.get_node("CirculationPumps")
	check(pumps.get_child_count() == 8, "Missing authored circulation pumps")
	var machine: Node2D = pumps.get_child(0)
	var clock_before: float = machine.clock
	check(not map.get_node("BackgroundMachines").visible and not map.get_node("DeepStructure").visible,
		"Graybox machines or background show through the circulation artwork")
	paused = true
	for i in range(3): await process_frame
	check(is_equal_approx(machine.clock,clock_before), "Background motion ignores pause")
	var seam: Node2D
	for fixture in art.get_node("Fittings").get_children():
		if fixture.kind == "seam":
			seam = fixture
	check(is_instance_valid(seam) and seam.arc_preview, "Missing visual electric seam")
	if is_instance_valid(seam):
		var arc_before: float = seam.seconds
		for i in range(3):
			await process_frame
		check(is_equal_approx(seam.seconds, arc_before), "Electric arc ignores pause")
	paused = false
	var sample_top: Polygon2D = map.get_node("Floors/SpineSegment00/Top")
	var finish: ShaderMaterial = sample_top.material
	check(is_instance_valid(finish) and finish.get_shader_parameter("pixel_world") == 1.0,
		"Environment pixel scale differs from the abdomen baseline")
	await press_key(KEY_F)
	check(not art.enabled and sample_top.material == null and not preview.door_skins[0].visible,
		"F did not restore the blockout")
	check(map.get_node("BackgroundMachines").visible and not pumps.visible,
		"F did not restore the original machine guides")
	await press_key(KEY_F)
	check(art.enabled and sample_top.material == finish and preview.door_skins[0].visible,
		"F did not restore the environment")
	await press_key(KEY_H)
	check(not art.get_node("CopperBundle").visible and not art.get_node("RolledRims").visible,
		"H did not hide the shell depth layers")
	await press_key(KEY_H)
	check(art.get_node("CopperBundle").visible and art.get_node("RolledRims").visible,
		"H did not restore the shell depth layers")
	await press_key(KEY_V)
	check(map.get_node("BoundaryDebug").visible, "V collision view failed")
	preview.set_overview(false)
	check(preview.get_node("Camera").zoom.is_equal_approx(Vector2(.55,.55)), "Raised viewpoint not applied")
	preview.set_overview(true)
	check(preview.get_node("Camera").zoom.x<.65, "Overview failed")
	for top in map.get_walk_surfaces(): check(not Geometry2D.triangulate_polygon(top.polygon).is_empty(), "Invalid terrain")
	preview.queue_free(); await process_frame
	print("SPINE_DIAGONAL: %s | 26 IDs, 6 sentries/6 cleaners reserved, main return walk, dead-end out/back, duct walk, gate isolation, rotated door safety, raised 2D camera, circulation art toggle and paused arc" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
