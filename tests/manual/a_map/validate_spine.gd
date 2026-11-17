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

func check_hazard_prototype() -> void:
	var hazards: Node2D = preview.get_node("EntranceHazards")
	check(hazards.emitters.size() == 8 and hazards.electrodes.size() == 7, "Missing entry devices")
	var axis := Vector2.from_angle(-0.43633231)
	var across := Vector2(-axis.y, axis.x)
	var center: Vector2 = map.get_node("Markers/DefenseElectrode05").position + across * 48.0
	var left := center - across * 109.0
	var right := center + across * 109.0
	var ray := PhysicsRayQueryParameters2D.create(left, right, 1)
	check(map.is_walkable_point(left) and map.is_walkable_point(right) and
		root.world_2d.direct_space_state.intersect_ray(ray).is_empty(), "Former narrow deck still blocks lateral movement")

	var start := actor.position
	var hits := {}
	var record_hit := func(device: String) -> void:
		hits[device] = true
	hazards.actor_hit.connect(record_hit)
	var emitter: Marker2D = hazards.emitters[0]
	actor.position = emitter.position + Vector2.from_angle(emitter.rotation) * 96.0
	hazards.reset_motion()
	for frame in range(255):
		if hits.has("激光球"):
			break
		await physics_frame
	check(hits.has("激光球"), "The wall emitter never hits the preview actor")
	var electrode: Marker2D = hazards.electrodes[0]
	actor.position = electrode.position + axis * 40.0
	hazards.reset_motion()
	for frame in range(120):
		if hits.has("扩散电圈"):
			break
		await physics_frame
	check(hits.has("扩散电圈"), "The spreading ring never hits the preview actor")
	actor.position = map.get_node("Markers/DefenseSafePocket").position
	hazards.reset_motion()
	hits.clear()
	for frame in range(300):
		await physics_frame
	check(hits.is_empty(), "Prototype attacks hit inside the safe observation bay")
	hazards.actor_hit.disconnect(record_hit)
	await press_key(KEY_R)
	actor.position = start

func check_entrance_defense(ids: Dictionary) -> void:
	var art: Node2D = map.get_node("SpineArt/ServicePassageArt")
	var catwalk: Node2D = map.get_node("Floors/ServiceCatwalk")
	var seals := map.get_node("EntranceDefense/ServiceSeals").get_children()
	var shutter: Node2D = preview.doors[preview.TestDoor.ISOLATION]
	var pocket: Vector2 = ids["p2_defense_safe_pocket"].position
	var window: Vector2 = ids["p2_maintenance_window"].position
	var service := route("ServiceRoute")
	var start := actor.position
	check(map.get_node("Boundaries").get_child_count() == 2, "Service route lost an edge contour")
	check(art.get_node("ArmorCovers").visible and not art.get_node("Open").visible and not catwalk.visible,
		"Concealed passage art is visible")
	check(not art.get_node("HatchHint").visible, "Hatch reveals itself before dialogue")
	check(not reachable(pocket, service[-1]), "Closed hatch and shutter allow a bypass")
	check(not reachable(pocket, window), "Closed hatch fails to seal the service entry")
	check(not reachable(service[-1], window), "Hidden exit allows entry from the far side")
	await walk(service.slice(0, 4))
	await press_key(KEY_E)
	check(map.service_passage_state == map.ServicePassage.CONCEALED, "Hatch opened before dialogue")
	await press_key(KEY_K)
	check(map.service_passage_state == map.ServicePassage.REVEALED and art.get_node("HatchHint").visible,
		"Dialogue simulation did not reveal the hatch")
	check(art.get_node("ArmorCovers").visible and not catwalk.visible, "Reveal opened the tunnel early")
	for seal in seals:
		check(not seal.get_node("Collision").disabled and seal.get_node("Occluder").visible,
			"Reveal removed a closed seal")
	await press_key(KEY_E)
	await physics_frame
	await physics_frame
	check(map.service_passage_state == map.ServicePassage.OPEN and not shutter.is_open,
		"Opening the hatch did not leave the isolation gate closed")
	check(art.get_node("Open").visible and not art.get_node("ArmorCovers").visible and catwalk.visible,
		"Passage did not reveal its interior")
	for seal in seals:
		check(seal.get_node("Collision").disabled and not seal.get_node("Occluder").visible,
			"An opened seal still blocks its entrance")
	var axis := Vector2.from_angle(shutter.rotation) * 70.0
	var direct := PhysicsRayQueryParameters2D.create(shutter.position - axis, shutter.position + axis, 1)
	var stopped := root.world_2d.direct_space_state.intersect_ray(direct)
	check(not stopped.is_empty() and stopped.collider == shutter.get_node("Body"), "Closed isolation gate does not block the main route")
	await walk(service.slice(4))
	check(reachable(actor.position, window), "Service route cannot be revisited from the safe rejoin")
	check(not reachable(actor.position, ids["p2_scatter_evolution"].position), "Service route bypasses protocol")
	var ray := PhysicsRayQueryParameters2D.create(ids["p2_defense_electrode_02"].position, window, 1)
	var hit := root.world_2d.direct_space_state.intersect_ray(ray)
	check(not hit.is_empty(), "Inspection slit does not stop shots across the shaft")
	for marker in ids.values():
		if marker.get_meta("role", "") != "wall_emitter":
			continue
		ray.from = marker.position
		ray.to = pocket
		var shield := root.world_2d.direct_space_state.intersect_ray(ray)
		check(not shield.is_empty(), "Unshielded story return point from " + marker.object_id)
		if marker.name in [&"DefenseEmitter01", &"DefenseEmitter02"]:
			check(not shield.is_empty() and shield.collider.get_parent().name == &"DefenseBayShield",
				"Safe bay partition does not screen " + marker.object_id)
	for wall in map.get_node("EntranceDefense/ServiceWalls").get_children():
		var shadow: LightOccluder2D = wall.get_node("Occluder")
		check(shadow.occluder.polygon == wall.polygon, "Service wall shadow is misaligned")
	await press_key(KEY_R)
	await physics_frame
	await physics_frame
	check(map.service_passage_state == map.ServicePassage.CONCEALED and not catwalk.visible,
		"Preview reset did not hide the passage")
	for seal in seals:
		check(not seal.get_node("Collision").disabled and seal.get_node("Occluder").visible,
			"Preview reset did not reseal the passage")
	shutter.set_open(true)
	await physics_frame
	await physics_frame
	actor.position = start

func check_first_sentry_cover(sentry: Node2D) -> void:
	var body: StaticBody2D = map.get_node("Covers/Valve0/Body")
	var shape: CollisionPolygon2D = body.get_node("Collision")
	var center := (shape.polygon[0] + shape.polygon[2]) * 0.5
	var axis := Vector2(0.9063078, -0.4226183)
	var shelter := center - axis * 96.0
	check(map.is_walkable_point(shelter), "First valve has no approach-side shelter")
	var shot := PhysicsRayQueryParameters2D.create(sentry.position + Vector2(0, -78), shelter, 1)
	var hit := root.world_2d.direct_space_state.intersect_ray(shot)
	check(not hit.is_empty() and hit.collider == body, "First valve does not screen the sentry approach")
	var shadow: LightOccluder2D = map.get_node("Covers/Valve0/Occluder")
	check(shadow.occluder.polygon == shape.polygon, "First valve collision and shadow have drifted")

func check_protocol_bay(ids: Dictionary) -> void:
	var start := actor.position
	var approach := route("ProtocolBayRoute")
	actor.position = approach[0]
	await walk(approach)
	var terminal: Node2D = ids["p2_protocol_terminal"]
	check(actor.position.distance_to(terminal.position) < float(terminal.get_meta("interaction_range")),
		"Operator cannot reach the three-dial console")
	var observer: Node2D = ids["p2_protocol_observation"]
	var spider: Node2D = ids["p2_cleaner_01"]
	var crossing := PhysicsRayQueryParameters2D.create(observer.position, spider.position, 1)
	var hit := root.world_2d.direct_space_state.intersect_ray(crossing)
	check(not hit.is_empty() and hit.collider == map.get_node("Covers/ProtocolBayScreen/Body"),
		"Observation pane does not separate the spider lane")
	approach.reverse()
	await walk(approach)
	actor.position = start

func check_gate_shelter(ids: Dictionary) -> void:
	var start := actor.position
	var door: Node2D = ids["p2_authorized_door"]
	var exit: Node2D = ids["p2_protocol_exit"]
	var axis := Vector2.from_angle(door.rotation)
	var threshold: Vector2 = exit.position - axis * (exit.position - door.position).dot(axis)
	actor.position = threshold - axis * 45.0
	await walk(PackedVector2Array([threshold, exit.position]))
	var zone: Node2D = map.get_node("Reservations/ProtocolZone")
	var region := Rect2(Vector2.ZERO, zone.size)
	check(region.has_point(zone.to_local(threshold + axis * 25.0)),
		"Protocol range ends before clearing the gate")
	check(not region.has_point(zone.to_local(exit.position)), "Protocol exit remains inside the range")
	var sentry: Node2D = ids["p2_protocol_gate_sentry"]
	var shot := PhysicsRayQueryParameters2D.create(sentry.position + Vector2(0, -78), exit.position, 1)
	var stop := root.world_2d.direct_space_state.intersect_ray(shot)
	check(not stop.is_empty() and stop.collider == map.get_node("Covers/ProtocolGateCover/Body"),
		"Protocol exit is exposed to the proposed sentry")
	for id in ["p2_protocol_yield_rear", "p2_protocol_yield_front"]:
		var point: Vector2 = ids[id].position
		check(point.distance_to(threshold) >= 43.0, "Cleaner yield pad intrudes on the approach lane")
	actor.position = start

func check_upper_spine(ids: Dictionary) -> void:
	var start := actor.position
	var tap_route := route("FluidReturnRoute")
	actor.position = ids["p2_scatter_return_entry"].position
	await walk(tap_route.slice(0, 5))
	var tap: Node2D = ids["p2_spinal_fluid_tap"]
	check(actor.position.distance_to(tap.position) <= float(tap.get_meta("interaction_range")),
		"Return route does not reach the spinal fluid tap")
	await walk(tap_route.slice(5))
	check(actor.position.distance_to(tap_route[-1]) < 3.0,
		"Cannot return to the main deck from the tap")

	var laser := route("UpperLaserRoute")
	var cover := route("UpperCoverRoute")
	var ray := PhysicsRayQueryParameters2D.create(laser[0], laser[-1], 1)
	var space := root.world_2d.direct_space_state
	check(space.intersect_ray(ray).is_empty(), "Upper laser lane is obstructed")
	actor.position = laser[0]
	await walk(laser)
	actor.position = cover[0]
	await walk(cover)
	var sentries := ["p2_sentry_03", "p2_sentry_04", "p2_sentry_05", "p2_sentry_06"]
	var axis := Vector2(0.9063078, -0.4226183)
	for index in range(sentries.size()):
		var body: StaticBody2D = map.get_node("Covers/Valve%d/Body" % (index + 1))
		var shape: CollisionPolygon2D = body.get_node("Collision")
		var center := (shape.polygon[0] + shape.polygon[2]) * 0.5
		ray.from = ids[sentries[index]].position + Vector2(0, -78)
		ray.to = center - axis * 61.0
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider == body, "Upper shelter does not screen " + sentries[index])
	var exit: Vector2 = ids["p2_exit_to_thorax"].position
	check(not map.is_walkable_point(exit + axis * 72.0), "Recessed receiver adds a false walking surface")
	actor.position = start

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
		var fixture_role: String = marker.get_meta("role", "")
		if marker.object_type != "door":
			check(map.is_walkable_point(marker.position), "Marker off terrain: " + marker.object_id)
		if marker.object_type != "door" and fixture_role not in ["wall_emitter", "isolation_gate", "service_hatch", "service_rejoin", "spinal_fluid_tap"]:
			query.transform = Transform2D(0,marker.position)
			check(root.world_2d.direct_space_state.intersect_shape(query,1).is_empty(), "Blocked marker: " + marker.object_id)
	for marker in ids.values():
		for link in marker.linked_ids: check(ids.has(link), "Missing linked ID")
	check(ids.size()==56 and counts.sentry==6 and counts.cleaner==6, "Marker reservations mismatch")
	check(not ids["p2_scatter_evolution"].get_meta("grants_ability"), "Blueprint grants scatter")
	check(ids["duct_spine_blueprint"].target_entry_id=="duct_arrival", "Wrong return destination")
	check(ids["p2_shortcut_door"].get_meta("role")=="blocked_maintenance_end", "Branch is still a forward shortcut")
	await check_hazard_prototype()
	await check_entrance_defense(ids)
	check_first_sentry_cover(ids["p2_sentry_01"])
	await check_protocol_bay(ids)
	check(not reachable(actor.position,ids["p2_scatter_evolution"].position), "Protocol gate bypass")
	check(reachable(actor.position,ids["p2_maintenance_record"].position), "Record unavailable before protocol")
	preview.doors[0].set_open(true)
	await physics_frame; await physics_frame
	await check_gate_shelter(ids)
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
	# Check the physical stop behind the console as well as the missing onward floor.
	var end: Vector2 = ids["p2_shortcut_door"].position
	var beyond := end + Vector2(160, -75)
	var record_stop := PhysicsRayQueryParameters2D.create(ids["p2_maintenance_record"].position, beyond, 1)
	var stop_hit := root.world_2d.direct_space_state.intersect_ray(record_stop)
	check(not stop_hit.is_empty() and stop_hit.collider == map.get_node("Covers/BlockedRecordEnd/Body"),
		"Record branch no longer has its physical end stop")
	check(not map.is_walkable_point(beyond), "Record branch connects forward")
	points = PackedVector2Array()
	var found := false
	for point in route("MainRoute"):
		if point.distance_to(route("RecordRoute")[0])<1: found=true
		if found: points.append(point)
		if point.distance_to(route("DuctRoute")[0])<1: break
	await walk(points)
	var duct := route("DuctRoute")
	await walk(duct); duct.reverse(); await walk(duct)
	await check_upper_spine(ids)
	for i in range(preview.doors.size()):
		preview.selected_door = i
		actor.position = preview.doors[i].position
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
	var hazards: Node2D = preview.get_node("EntranceHazards")
	var clock: float = hazards.elapsed
	for i in range(3):
		await process_frame
	check(is_equal_approx(hazards.elapsed, clock), "Entrance hazards ignore pause")
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
	print("SPINE_DIAGONAL: %s | 56 IDs, fluid station and upper routes, protocol bay and sheltered gate, wide entry hazards, inspection route and first sentry cover, 6 sentries/6 cleaners reserved, main return walk, dead-end out/back, duct walk, gate isolation, rotated door safety, raised 2D camera, circulation art toggle and paused hazards" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
