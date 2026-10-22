extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(scene)
	var music = scene.get_node("BackgroundMusic")
	var player = scene.get_node("SpawnPoints/PlayerSpawn/Player")
	for actor in [player] + music.enemies:
		actor.set_physics_process(false)
	assert(music.playing)
	assert(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(abs(music.stream.get_length() - 32.0) < 0.001)
	await create_timer(0.9).timeout
	assert(abs(music.volume_db - music.BASE_DB) < 0.1)
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
	scene.reset_test_combat()
	assert(music.playing)
	await create_timer(0.2).timeout
	scene.queue_free()
	await create_timer(0.2).timeout
	print("Background music checks: PASS")
	quit()
