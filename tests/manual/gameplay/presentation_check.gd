extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(scene)
	var player = scene.player
	player.set_physics_process(false)
	for enemy in scene.enemies:
		enemy.set_physics_process(false)
	await physics_frame
	assert(scene.map.get_node("Walls/GunRackBase").size == Vector2(64, 64))
	assert(scene.weapon_pickup.global_position == Vector2(432, 1888))
	assert(not scene.map.get_node("Markers/PulseGun").visible)
	assert(not player.pulse_gun_equipped)
	assert(scene.robot_visual.texture.resource_path == "res://assets/sprites/title/title_robot.svg")
	assert(player.pulse_gun.has_node("HeldGunModel"))
	assert(not scene.has_node("BackgroundMusic") and not scene.has_node("CombatAudio"))
	player.global_position = Vector2(576, 1888)
	player.aim_at(Vector2(432, 1888))
	scene.camera.position_smoothing_enabled = false
	scene.camera.global_position = player.global_position
	scene.camera.force_update_scroll()
	await process_frame
	await process_frame
	assert(is_zero_approx(scene.robot_visual.global_rotation))
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(4.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/main_robot_before.png")
	# The solid rack blocks the player, but the pickup is reachable at its south edge.
	player.global_position = Vector2(432, 1934)
	assert(not player.test_move(player.global_transform, Vector2.ZERO))
	assert(player.test_move(player.global_transform, Vector2(0, -20)))
	for i in range(4):
		await physics_frame
	assert(player.pulse_gun_equipped, "Must acquire from outside the solid rack")
	assert(not is_instance_valid(scene.weapon_pickup))
	player.set_physics_process(true)
	await physics_frame
	await physics_frame
	player.set_physics_process(false)
	assert(player.pulse_gun.visible)
	player.global_position = Vector2(576, 1888)
	player.aim_at(player.global_position + Vector2.RIGHT*100)
	scene.camera.global_position = player.global_position
	scene.camera.force_update_scroll()
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(4.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/main_robot_after.png")
	player.apply_damage(10)
	assert(player.is_dead and not player.pulse_gun_equipped)
	assert(not player.pulse_gun.visible)
	assert(is_instance_valid(scene.weapon_pickup))
	assert(scene.weapon_pickup.global_position == Vector2(432,1888))
	await create_timer(2.2).timeout
	assert(not player.is_dead and not player.pulse_gun_equipped)
	assert(player.global_position == scene._find_spawn_position())
	assert(scene.current_objective == scene.Objective.GET_WEAPON)
	player._unhandled_input(InputEventAction.new())
	assert(player.pulse_gun.state == player.pulse_gun.State.IDLE)
	player.global_position = Vector2(432,1934)
	for i in range(4):
		await physics_frame
	assert(player.pulse_gun_equipped, "Weapon must be collectible again after death")
	player.invulnerability_remaining = 0
	player.apply_damage(10)
	await create_timer(2.2).timeout
	var pickups := 0
	for obj in scene.interactables_parent.get_children():
		if obj.has_meta("is_weapon"):
			pickups += 1
	assert(pickups == 1, "Repeated deaths must leave exactly one weapon")
	await create_timer(0.15).timeout
	scene.queue_free()
	await create_timer(0.15).timeout
	print("Main presentation and rack pickup: PASS")
	quit()
