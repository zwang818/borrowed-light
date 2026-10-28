extends SceneTree
## Run with --headless --path <project> --script tests/manual/a_map/web_break_check.gd.
const TRACE = preload("res://scenes/weapons/laser_trace.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.player.set_physics_process(false)
	game.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	var env = game.map.get_node("Environment")
	assert(env.webs.size() == 442, "10 placed webs plus 9 regions on 48 background tiles")
	var enemy_count: int = game.total_enemies
	var foreground_count := 0
	for web in env.webs:
		assert(not web.is_in_group("combat_enemies"))
		assert(web.collision_mask == 0)
		if web.background_region.has_area():
			# Every remaining hit polygon must be outside floors, including its center.
			for shape in web.get_children():
				var center := Vector2.ZERO
				for point in shape.polygon:
					center += point
				center /= shape.polygon.size()
				for floor_polygon in env._floor_polygons:
					assert(not Geometry2D.is_point_in_polygon(web.to_global(center), floor_polygon))
			continue
		foreground_count += 1
		var shot := find_shot(env, web)
		assert(not shot.is_empty(), "Cannot shoot web from floor: " + str(web.name))
		web.apply_damage(0)
		assert(not web.broken)
		var from: Vector2 = shot[0]
		var to: Vector2 = shot[1]
		var direction := (to - from).normalized()
		var gun = game.player.pulse_gun
		gun.cancel()
		assert(gun.request_fire(direction))
		gun.advance_time(0.8, from, direction)
		gun.advance_time(0.3, from, direction)
		assert(web.broken, "Actual pulse must break web: " + str(web.name))
		assert(TRACE.trace(web.get_world_2d().direct_space_state, from, direction, from.distance_to(to) + 20).target == web, "Broken web must still stop the same beam's contact window")
		web.apply_damage(1)
		await process_frame
		await process_frame
		var spiders := get_nodes_in_group("ambient_spiders")
		assert(spiders.size() == 1, "One spider per web, even after duplicate damage")
		var spider = spiders[0]
		assert(not spider.is_in_group("combat_enemies") and spider.collision_layer == 0)
		assert(env._free_floor(spider.global_position), "Spider must land outside solid walls")
		var spider_age: float = spider.age
		paused = true
		await create_timer(0.15, true).timeout
		assert(spider.age == spider_age, "Pause must freeze the drop/run")
		paused = false
		gun.cancel()
		await create_timer(0.24).timeout
		assert(web.collision_layer == 0)
		env.reset_breakable_webs()
		await process_frame
		assert(not web.broken and web.collision_layer == 4)
		assert(get_nodes_in_group("ambient_spiders").is_empty())
	assert(foreground_count == 10 and game.total_enemies == enemy_count and game.dead_enemies == 0)
	# Directly exercise a visible background target; no enemy or player state changes.
	var background_web: Area2D
	for web in env.webs:
		if web.background_region.has_area() and web.get_child_count() > 0:
			background_web = web
			break
	background_web.apply_damage(1)
	await process_frame
	await process_frame
	assert(get_nodes_in_group("ambient_spiders").size() == 1)
	await create_timer(2.0).timeout
	assert(get_nodes_in_group("ambient_spiders").is_empty(), "Spiders must leave and clean themselves up")
	game._retry_level()
	await process_frame
	for web in env.webs:
		assert(not web.broken, "C retry must restore all webs")
	assert(game.total_enemies == enemy_count and game.dead_enemies == 0)
	await create_timer(4.1).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("WEBS: 10 reachable pulse targets, 432 background patches, one spider per hit, pause, cleanup, retry, enemy counts: PASS")
	quit()

func find_shot(env: Node2D, web: Area2D) -> Array:
	var polygon: PackedVector2Array = web.hit_polygon()
	for radius in [72.0, 112.0, 160.0, 220.0]:
		for i in range(24):
			var from: Vector2 = web.global_position + Vector2.from_angle(float(i) * TAU / 24) * radius
			if not env._free_floor(from):
				continue
			for x in range(-3, 4):
				for y in range(-3, 4):
					var local: Vector2 = Vector2(x, y) * web.draw_size / 8
					if not Geometry2D.is_point_in_polygon(local, polygon):
						continue
					var to := web.to_global(local)
					var hit := TRACE.trace(web.get_world_2d().direct_space_state, from, (to - from).normalized(), from.distance_to(to) + 2)
					if hit.target == web:
						return [from, to]
	return []
