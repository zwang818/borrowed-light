extends SceneTree

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	while not level.is_entry_ready():
		await process_frame
	var player = level.player
	var enemy = level.get_node("abdomen_cleaner_01")
	player.set_physics_process(false)
	var cases := [
		{ "start": Vector2(528, 1610), "player": Vector2(555, 1727), "right_side": true },
		{ "start": Vector2(528, 1610), "player": Vector2(558, 1730), "right_side": true },
		{ "start": Vector2(460, 1610), "player": Vector2(438, 1714), "right_side": false },
	]
	for sample in cases:
		enemy.restore_combat_state(level.enemy_baselines[enemy.entity_id])
		enemy.global_position = sample.start
		player.restore_player(sample.player, player.max_health, [&"pulse_gun"])
		level.camera.global_position = sample.player
		level.camera.reset_smoothing()
		var cleared_side := false
		var last_direction := 0.0
		var reversals := 0
		for frame in range(180):
			await physics_frame
			var position: Vector2 = enemy.global_position
			if position.y >= 1632.0 and position.y <= 1664.0:
				cleared_side = position.x > 576.0 if sample.right_side else position.x < 416.0
			var direction := signf(enemy.velocity.x)
			if not is_zero_approx(direction):
				if not is_zero_approx(last_direction) and direction != last_direction:
					reversals += 1
				last_direction = direction
			if enemy.state == enemy.State.WARNING:
				break
		assert(cleared_side and enemy.global_position.y > 1664.0, "Cleaner must walk around the real screen before attacking.")
		assert(enemy.state == enemy.State.WARNING, "Cleaner must reach melee with a stationary player.")
		assert(reversals <= 2, "Cleaner must not reverse repeatedly at the screen.")
	level.queue_free()
	await process_frame
	print("Abdomen first cleaner: screen detour on both sides, doorway edge and melee approach: PASS")
	quit()
