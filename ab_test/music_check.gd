extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://ab_test/ab_combat.tscn").instantiate()
	root.add_child(scene)
	var music = scene.get_node("BackgroundMusic")
	var player = scene.player
	for actor in [player] + music.enemies:
		actor.set_physics_process(false)
	assert(music.playing)
	assert(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(abs(music.stream.get_length() - 32.0) < 0.001)
	await create_timer(0.9).timeout
	assert(abs(music.volume_db - music.BASE_DB) < 0.1)
	for enemy in music.enemies:
		enemy.state = enemy.State.WARNING
		await create_timer(0.2).timeout
		assert(music.volume_db < music.BASE_DB - 5)
		enemy.state = enemy.State.PATROL
		await create_timer(1.2).timeout
	player.apply_damage(1)
	await create_timer(0.2).timeout
	assert(music.volume_db < music.BASE_DB - 5)
	paused = true
	await process_frame
	assert(music.stream_paused)
	paused = false
	await process_frame
	assert(not music.stream_paused)
	player.invulnerability_remaining = 0
	player.apply_damage(10)
	await create_timer(0.4).timeout
	assert(not music.playing)
	scene.retry()
	assert(music.playing)
	await create_timer(0.2).timeout
	scene.queue_free()
	await create_timer(0.2).timeout
	print("AB background music checks: PASS")
	quit()
