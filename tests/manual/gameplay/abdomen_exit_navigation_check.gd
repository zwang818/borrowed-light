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
	var west = level.get_node("abdomen_cleaner_02")
	var east = level.get_node("abdomen_cleaner_03")
	player.set_physics_process(false)
	level.get_node("abdomen_cleaner_01").set_physics_process(false)
	east.set_physics_process(false)

	# Match the screenshot: the player's feet are east of the machine, the
	# cleaner is southwest. The second pass moves the target during its detour.
	for moving_target in [false, true]:
		level._reset_exit_encounter()
		west.restore_combat_state(level.enemy_baselines[west.entity_id])
		player.restore_player(Vector2(713, 537), player.max_health, [&"pulse_gun"])
		level.camera.global_position = player.global_position
		level.camera.reset_smoothing()
		level._update_exit_encounter()
		west.global_position = Vector2(574, 595)
		west.engage(false)
		west.taking_side_route = false # Reproduce a chase after the opening flank.
		var last_direction := 0.0
		var reversals := 0
		var reached_melee := false
		for frame in range(210):
			await physics_frame
			if moving_target and frame == 14:
				player.global_position = Vector2(716, 474)
			var direction := signf(west.velocity.x)
			if not is_zero_approx(direction):
				if not is_zero_approx(last_direction) and direction != last_direction:
					reversals += 1
				last_direction = direction
			if west.state == west.State.WARNING:
				reached_melee = true
				break
		assert(reached_melee, "The cleaner must reach melee on the opposite side of the exit machine.")
		assert(west.has_clear_line(west.global_position, player.global_position), "A swing must start from an unobstructed position.")
		assert(reversals <= 2, "The cleaner must not pace back and forth at the base.")

	level.queue_free()
	await process_frame
	print("Abdomen exit navigation: machine corner, stationary and moving player, unobstructed melee: PASS")
	quit()
