extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var sentry = room.get_node("SpawnPoints/SentrySpawn/Sentry")
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var model = sentry.model
	var bullets = room.get_node("EnemyProjectiles")
	sentry.global_position = Vector2(750,300)
	player.global_position = Vector2(850,300)
	sentry.configure(player,func(_unit): return true,bullets)
	await physics_frame
	var pedestal_transform: Transform2D = model.pedestal.transform
	for i in range(16):
		model.aim_angle = i*PI/8.0
		model.update_pose()
		assert(model.head.frame == i)
		assert(model.pedestal.transform == pedestal_transform)
		assert(model.muzzle_origin().distance_to(model.head_origin()) < 25)
	# Negative angles and the full-circle seam must select the same frame.
	model.aim_angle = -PI/8.0
	model.update_pose()
	assert(model.head.frame == 15)
	model.aim_angle = TAU
	model.update_pose()
	assert(model.head.frame == 0)
	model.aim_angle = PI
	sentry.state = sentry.State.WARNING
	model._physics_process(0.1)
	assert(absf(angle_difference(model.aim_angle,PI)) > 0.01)
	sentry.shots_left = sentry.PARAMETERS.SENTRY_BURST_COUNT
	sentry.state = sentry.State.BURST
	sentry.fire_one()
	assert(bullets.get_child_count() == 1)
	var bullet = bullets.get_child(0)
	assert(bullet.global_position.distance_to(model.muzzle_origin()) < 0.01)
	var locked: Vector2 = bullet.direction
	player.global_position += Vector2(-30,40)
	sentry.fire_one()
	assert(bullets.get_child(1).direction.is_equal_approx(locked))
	room.reset_test_combat()
	assert(model.recoil == 0.0 and sentry.state == sentry.State.IDLE)
	await process_frame
	assert(bullets.get_child_count() == 0)
	room.queue_free()
	await process_frame
	print("Floating sentry: sixteen headings, fixed pedestal, tracking, muzzle origin, burst lock and reset: PASS")
	quit()
