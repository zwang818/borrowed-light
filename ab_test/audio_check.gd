extends SceneTree
var events: Array[StringName] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://ab_test/ab_combat.tscn").instantiate()
	root.add_child(scene)
	var audio = scene.combat_audio
	var player = scene.player
	player.set_physics_process(false)
	audio.set_physics_process(false)
	for enemy in scene.cleaners:
		enemy.set_physics_process(false)
	audio.sound_played.connect(func(id): events.append(id))
	await physics_frame
	player.global_position = scene.pickup.global_position + Vector2(0, 30)
	await physics_frame
	assert(scene.try_pick_up())
	audio._physics_process(0.016)
	assert(events.count(&"weapon_pickup") == 1)
	for enemy in scene.cleaners:
		enemy.state = enemy.State.WARNING
	audio._physics_process(0.016)
	assert(events.count(&"cleaner_warning") == 3)
	scene.cleaners[0].state = scene.cleaners[0].State.RECOVERY
	audio._physics_process(0.016)
	var warnings := 0
	for voice in audio.voices:
		if voice.playing and voice.get_meta("sound_id") == &"cleaner_warning":
			warnings += 1
	assert(warnings == 2, "One cancellation must not silence other cleaners")
	for i in range(20):
		player.position.x += 2
		audio._physics_process(1.0/60)
	assert(&"player_step" in events)
	for voice in audio.voices:
		if voice.get_meta("sound_id") == &"player_step":
			assert(voice.volume_db == -22)
	player.apply_damage(1)
	player.apply_damage(1)
	assert(events.count(&"player_hurt") == 1)
	player.invulnerability_remaining = 0
	player.apply_damage(10)
	assert(events.back() == &"player_shutdown")
	for voice in audio.voices:
		if voice.playing:
			assert(voice.get_meta("sound_id") == &"player_shutdown")
	var count := events.size()
	scene.retry()
	audio._physics_process(0.016)
	assert(events.size() == count)
	assert(player.pulse_gun_equipped)
	audio.play_sound(&"cleaner_warning", scene.cleaners[0])
	paused = true
	await process_frame
	for voice in audio.voices:
		assert(not voice.playing)
	paused = false
	await process_frame
	await create_timer(0.15).timeout
	scene.queue_free()
	await create_timer(0.15).timeout
	print("AB audio checks: PASS")
	quit()
