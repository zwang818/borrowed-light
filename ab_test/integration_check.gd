extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://ab_test/ab_combat.tscn").instantiate()
	root.add_child(scene)
	var player = scene.player
	player.set_physics_process(false)
	for enemy in scene.cleaners:
		enemy.set_physics_process(false)
	await physics_frame
	await process_frame
	assert(scene.cleaners.size() == 3)
	assert(player.global_position == scene.spawn_position)
	assert(not player.pulse_gun_equipped)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	assert(player.pulse_gun.state == player.pulse_gun.State.IDLE, "Unarmed click must not attack")
	assert(not scene.try_pick_up(), "Distant pickup must fail")
	for enemy in scene.cleaners:
		assert(enemy.home == enemy.global_position)
		assert(not enemy.test_move(enemy.global_transform, Vector2.ZERO), "Enemy spawned in wall")
		assert(not enemy.test_move(enemy.global_transform, Vector2(-48, 0)), "Patrol crosses wall")
	player.global_position = scene.pickup.global_position + Vector2(0, 30)
	await physics_frame
	assert(scene.try_pick_up(), "Nearby weapon pickup failed")
	assert(not scene.pickup.visible and player.pulse_gun_equipped)
	assert(not scene.try_pick_up(), "Cannot acquire twice")
	player._unhandled_input(click)
	assert(player.pulse_gun.state == player.pulse_gun.State.CHARGING)
	player.pulse_gun.cancel()
	# Actual laser and melee inside the first map combat clearing.
	var enemy = scene.cleaners[0]
	player.global_position = enemy.home + Vector2(0, 90)
	scene.camera.force_update_scroll()
	await physics_frame
	await process_frame
	assert(scene._enemy_readable(enemy))
	assert(player.pulse_gun.request_fire(Vector2.UP))
	player.pulse_gun.advance_time(0.799, player.global_position, Vector2.UP)
	assert(player.pulse_gun.state == player.pulse_gun.State.CHARGING)
	player.pulse_gun.advance_time(0.001, player.global_position, Vector2.UP)
	assert(player.pulse_gun.state == player.pulse_gun.State.FIRING)
	assert(player.pulse_gun.get_node("Audio/Laser").stream.resource_path == "res://ab_test/audio/pulse_biu.wav")
	player.pulse_gun.advance_time(0.3, player.global_position, Vector2.UP)
	assert(enemy.health == enemy.max_health - 1, "Map laser must damage cleaner")
	assert(is_equal_approx(player.pulse_gun.contact_remaining, 0.15))
	player.pulse_gun.advance_time(0.149, player.global_position, Vector2.UP)
	assert(player.pulse_gun.state == player.pulse_gun.State.FIRING)
	assert(enemy.health == enemy.max_health - 1, "One beam cannot damage twice")
	player.pulse_gun.advance_time(0.001, player.global_position, Vector2.UP)
	assert(player.pulse_gun.state == player.pulse_gun.State.IDLE)
	assert(not player.pulse_gun.get_node("Audio/Laser").playing)
	player.pulse_gun.cancel()
	player.global_position = enemy.global_position + Vector2(0, 32)
	await physics_frame
	await physics_frame
	enemy.state = enemy.State.ATTACK
	enemy.locked_direction = Vector2.DOWN
	enemy.try_melee_hit()
	assert(player.health == player.max_health - 1, "Map melee must damage player")
	player.invulnerability_remaining = 0
	player.apply_damage(10)
	assert(player.is_dead)
	scene.retry()
	assert(not player.is_dead and player.health == player.max_health)
	assert(player.pulse_gun_equipped and not scene.pickup.visible, "Retry retains acquired gun")
	for other in scene.cleaners:
		assert(other.health == other.max_health and other.global_position == other.home)
	assert(scene.get_node("Map/Markers/Terminal").visible)
	assert(scene.get_node("Map/Markers/Record").visible)
	if "--capture" in OS.get_cmdline_user_args():
		player.global_position = Vector2(576, 1620)
		scene.pickup.show()
		player.pulse_gun.show()
		scene.camera.zoom = Vector2.ONE * 1.6
		scene.camera.force_update_scroll()
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/borrowed_light_ab.png")
	await create_timer(0.15).timeout
	scene.queue_free()
	await create_timer(0.15).timeout
	print("PASS: AB spawn, patrol clearance, unarmed gate, pickup, laser, melee, retained weapon retry and untouched markers")
	quit()
