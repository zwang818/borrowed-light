extends SceneTree
var events: Array[StringName] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(scene)
	var audio = scene.get_node("CombatAudio")
	var player = audio.player
	var cleaner = audio.cleaner
	var sentry = audio.sentry
	for actor in [player, cleaner, sentry, audio]:
		actor.set_physics_process(false)
	audio.sound_played.connect(func(id): events.append(id))
	await physics_frame
	player.apply_damage(1)
	player.apply_damage(1)
	assert(events.count(&"player_hurt") == 1, "Iframe must suppress hurt audio")
	cleaner.apply_damage(1)
	sentry.apply_damage(1)
	assert(events.count(&"enemy_hit") == 1, "Simultaneous hits must be coalesced")
	cleaner.state = cleaner.State.WARNING
	audio._physics_process(0.1)
	assert(events.back() == &"cleaner_warning")
	cleaner.state = cleaner.State.ATTACK
	audio._physics_process(0.1)
	assert(events.back() == &"cleaner_attack")
	for voice in audio.voices:
		if voice.get_meta("sound_id") == &"cleaner_warning":
			assert(not voice.playing, "Warning must stop on attack")
	cleaner.apply_damage(10)
	assert(events.back() == &"enemy_shutdown")
	var count := events.size()
	cleaner.apply_damage(10)
	assert(events.size() == count, "Dead enemy must not emit again")
	sentry.state = sentry.State.WARNING
	audio._physics_process(0.1)
	assert(events.back() == &"sentry_warning")
	sentry.shot_fired.emit()
	assert(events.back() == &"sentry_fire")
	# Moved distance rather than input: stationary frames cannot create footsteps.
	count = events.count(&"player_step")
	for i in range(20):
		audio._physics_process(1.0/60)
	assert(events.count(&"player_step") == count)
	for i in range(20):
		player.position.x += 2
		audio._physics_process(1.0/60)
	assert(events.count(&"player_step") > count)
	player.invulnerability_remaining = 0
	player.apply_damage(10)
	assert(events.back() == &"player_shutdown")
	for voice in audio.voices:
		if voice.playing:
			assert(voice.get_meta("sound_id") == &"player_shutdown")
	count = events.size()
	sentry.shot_fired.emit()
	assert(events.size() == count, "No attacks audible after death")
	scene.reset_test_combat()
	assert(events.size() == count, "Retry must not emit repair or old damage")
	for voice in audio.voices:
		assert(not voice.playing)
	audio.play_sound(&"cleaner_warning")
	paused = true
	await process_frame
	for voice in audio.voices:
		assert(not voice.playing)
	count = events.size()
	paused = false
	await process_frame
	assert(events.size() == count, "Resume must not replay queued effects")
	assert(audio.voices.size() <= audio.LIMIT)
	await create_timer(0.15).timeout
	scene.queue_free()
	await create_timer(0.15).timeout
	print("Combat audio checks: PASS")
	quit()
