extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var unit = room.get_node("SpawnPoints/SentrySpawn/Sentry")
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var bullets = room.get_node("EnemyProjectiles")
	unit.global_position = Vector2(750,300)
	player.global_position = Vector2(850,300)
	unit.configure(player,func(_enemy):return true,bullets)
	unit.alternating_attacks = true
	await physics_frame
	for mode in [0,1,0]:
		unit._physics_process(0.01)
		assert(unit.state == unit.State.WARNING and unit.attack_mode == mode)
		unit._physics_process(0.75)
		var count := 3 if mode == 0 else 6
		for i in range(1,count): unit._physics_process(0.2)
		assert(bullets.get_child_count() == count)
		assert(unit.state == unit.State.RECOVERY)
		var half := 12.0 if mode == 0 else 30.0
		for i in range(count):
			var angle: float = bullets.get_child(i).direction.angle()
			assert(absf(angle_difference(unit.attack_center+deg_to_rad(-half+12*i),angle))<0.001)
		for bullet in bullets.get_children(): bullet.free()
		unit._physics_process(1.25)
	unit.restore_combat_state({"entity_id":unit.entity_id,"health":3})
	assert(unit.next_attack_mode == 0)
	unit._physics_process(0.01)
	player.is_dead = true
	unit._physics_process(1.0)
	assert(unit.state == unit.State.IDLE and bullets.get_child_count() == 0)
	room.queue_free()
	await process_frame
	print("Alternating sentry: A/B/A, counts, spread, recovery, reset and lost-target cancellation: PASS")
	quit()
