extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var trail = player.get_node("Facing/XiaoyiCombatVisual").trail
	player.sprint_active = true
	trail._physics_process(0.1)
	assert(trail.particles.is_empty()) # Held key against wall/stationary produces no trail.
	player.position.x += 4
	trail._physics_process(0.02)
	assert(not trail.particles.is_empty())
	var emitted_count: int = trail.particles.size()
	var origin: Vector2 = trail.particles[0].pos
	player.sprint_active = false
	player.position.x += 4
	trail._physics_process(0.02)
	assert(trail.particles.size() == emitted_count)
	assert(trail.particles[0].pos.x < origin.x) # World-space particle stays behind.
	trail._physics_process(0.5)
	assert(trail.particles.is_empty())
	player.sprint_active = true
	player.position.x += 4
	trail._physics_process(0.02)
	assert(not trail.particles.is_empty())
	room.reset_test_combat()
	assert(trail.particles.is_empty())
	assert(player.sprint_multiplier == 1.25)
	room.queue_free()
	await process_frame
	print("Sprint sparks: stationary suppression, emission, world space, release fade, reset, unchanged speed: PASS")
	quit()
