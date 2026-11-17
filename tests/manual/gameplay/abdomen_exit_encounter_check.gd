extends SceneTree

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = "/tmp/borrowed-light-exit-encounter-%d.cfg" % OS.get_process_id()
	root.add_child(level)
	current_scene = level
	while not level.is_entry_ready():
		await process_frame
	var player = level.player
	var west = level.exit_cleaners[0]
	var east = level.exit_cleaners[1]
	player.learn_pulse()
	level.pulse_learned = true
	player.set_physics_process(false)

	place_player(level, Vector2(640, 670))
	await physics_frame
	await physics_frame
	assert(not west.can_detect() and not east.can_detect(), "Sight from the approach does not start the encounter.")

	place_player(level, Vector2(640, 628))
	var silk_frame := -1
	var melee_frame := -1
	var passed_machine := false
	for frame in range(210):
		await physics_frame
		assert(west.engaged and east.engaged)
		assert(west.covers_retreat and not east.covers_retreat)
		assert(east.web_phase == 0)
		assert(not (west.web_phase == 1 and east.state == east.State.WARNING))
		if frame == 15:
			var warning_left: float = west.web_remaining
			var flank_position: Vector2 = east.global_position
			assert(west.web_phase == 1)
			paused = true
			await create_timer(0.06, true).timeout
			assert(west.web_remaining == warning_left and east.global_position == flank_position)
			paused = false
		if east.global_position.y < 544.0:
			assert(east.global_position.x > 672.0)
		elif east.global_position.x > 672.0:
			passed_machine = true
		if silk_frame < 0 and west.web_phase == 2:
			silk_frame = frame
			var aim_point: Vector2 = player.global_position.move_toward(west.retreat_point, west.RETREAT_LEAD)
			assert(west.web_direction.dot(west.eye_origin().direction_to(aim_point)) > 0.99)
		if east.state == east.State.ATTACK:
			melee_frame = frame
			break
	assert(passed_machine and not east.taking_side_route, "The flanker passed the machine before striking.")
	assert(silk_frame >= 0 and melee_frame - silk_frame >= 30, "The player gets at least half a second between strikes.")

	level._retry_level()
	await process_frame
	assert(not level.exit_encounter_active and not west.engaged and not east.engaged)
	assert(west.global_position == west.home and east.global_position == east.home)
	assert(get_nodes_in_group("b_cleaner_webs").is_empty())
	assert(player.pulse_gun_equipped and level._remaining_cleaners() == 3)

	# Enter again, then step into the retreat route during the visible warning.
	place_player(level, Vector2(640, 628))
	for frame in range(20):
		await physics_frame
		if west.web_phase == 1: break
	assert(west.web_phase == 1)
	place_player(level, Vector2(640, 684))
	for frame in range(120):
		await physics_frame
		if player.web_slow_remaining > 0.0: break
	assert(player.web_slow_remaining > 0.0 and player.health == player.max_health)
	level._retry_level()

	# Give the opposite pair roles by entering from the western edge of the doorway.
	place_player(level, Vector2(600, 630))
	await physics_frame
	await physics_frame
	assert(east.covers_retreat and west.taking_side_route)
	assert(west.side_waypoint.x < 608.0)
	place_player(level, Vector2(640, 700))
	await physics_frame
	await physics_frame
	assert(level.exit_encounter_active, "Backing into the approach does not split the encounter.")
	place_player(level, Vector2(640, 880))
	await physics_frame
	await physics_frame
	assert(not level.exit_encounter_active)
	for enemy in level.enemies:
		enemy.apply_damage(enemy.max_health)
	assert(level._remaining_cleaners() == 0 and level.terminal_gate.get_meta("is_open"))
	DirAccess.remove_absolute(level.achievement_save_path)
	level.queue_free()
	await process_frame
	print("Abdomen exit encounter: entry, paired roles, side route, staggered strikes, retreat and retry: PASS")
	quit()

func place_player(level: Node2D, point: Vector2) -> void:
	level.player.global_position = point
	level.camera.global_position = point
	level.camera.reset_smoothing()
