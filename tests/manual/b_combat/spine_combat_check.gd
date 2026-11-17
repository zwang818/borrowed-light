extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room = load("res://tests/manual/b_combat/spine_combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var source = load("res://scenes/levels/spine/spine_graybox.tscn").instantiate()
	root.add_child(source)
	source.process_mode = Node.PROCESS_MODE_DISABLED
	assert(room.map.transform == Transform2D.IDENTITY)
	assert(room.map.get_meta("map_bounds") == source.get_meta("map_bounds"))
	assert(room.map.get_walk_surfaces().size() == source.get_walk_surfaces().size())
	for i in range(source.get_walk_surfaces().size()):
		var a = room.map.get_walk_surfaces()[i]
		var b = source.get_walk_surfaces()[i]
		assert(a.polygon == b.polygon and a.global_transform == b.global_transform)
	assert(room.enemies.size() == 12)
	assert(room.map.z_index == -100)
	for unit in room.enemies:
		assert(unit.z_index == 10)
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	assert(player.global_position == room.map.get_node("Markers/PlayerSpawn").global_position)
	assert(not player.scatter_unlocked and not room.try_unlock_scatter())
	assert(room.map.is_walkable_point(player.global_position))
	assert(player.pulse_gun.get_script().resource_path.ends_with("muzzle_pulse_gun.gd"))
	assert(player.z_index == 10 and player.pulse_gun.z_index == 5)
	assert(player.pulse_gun.map_bounds == source.get_meta("map_bounds"))
	assert(not room.has_node("Walls") and not room.has_node("Floor"))
	for enemy in room.enemies:
		assert(room.map.is_walkable_point(enemy.global_position))
	room.enemies[0].apply_damage(999)
	player.global_position += Vector2(20,0)
	room.reset_test_combat()
	assert(room.enemies[0].health == room.enemies[0].max_health)
	assert(player.global_position == room.map.get_node("Markers/PlayerSpawn").global_position)
	player.global_position = room.map.get_node("Markers/ScatterEvolution").global_position+Vector2(0,40)
	await physics_frame
	assert(room.try_unlock_scatter())
	assert(player.scatter_unlocked and player.has_arm_module(1))
	assert(not room.try_unlock_scatter())
	room.reset_test_combat()
	assert(player.scatter_unlocked)
	room._set_art(true)
	room._set_art(false)
	room.overview = true
	assert(not room._test_enemy_readable(room.enemies[0]))
	room.queue_free()
	source.queue_free()
	await process_frame
	print("Spine B: 1:1 floor geometry, bounds, spawn, 12 enemy markers, reset and overview: PASS")
	quit()
