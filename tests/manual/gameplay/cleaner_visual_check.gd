extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(scene)
	scene.player.set_physics_process(false)
	for enemy in scene.enemies:
		enemy.set_physics_process(false)
		assert(enemy.get_node("Facing/CleanerModel").kind == "cleaner")
		assert(not enemy.get_node("Facing/Body").visible)
		assert(enemy.get_node("CollisionShape2D").shape.radius == 12)
	var cleaner = scene.enemies[0]
	scene.player.global_position = cleaner.global_position + Vector2(96, 96)
	scene.camera.position_smoothing_enabled = false
	scene.camera.global_position = cleaner.global_position
	scene.camera.force_update_scroll()
	cleaner.get_node("Facing").rotation = 0
	cleaner.state = cleaner.State.WARNING
	cleaner.update_visuals()
	assert(cleaner.get_node("Facing/AttackZone").visible)
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(4.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/main_cleaner_new.png")
	cleaner.apply_damage(1)
	assert(cleaner.get_node("Facing").modulate == Color(2,2,2))
	cleaner.apply_damage(100)
	assert(cleaner.state == cleaner.State.DEAD)
	assert(not cleaner.get_node("Facing/AttackZone").visible)
	assert(cleaner.get_node("Facing").modulate == Color(.3,.3,.3))
	await create_timer(.15).timeout
	scene.queue_free()
	await create_timer(.15).timeout
	print("Cleaner presentation checks: PASS")
	quit()
