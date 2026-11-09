extends SceneTree
func _initialize() -> void:
	root.size = Vector2i(1152,648)
	call_deferred("run")
func run() -> void:
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = "user://test_combat_integration.cfg"
	root.add_child(level)
	current_scene = level
	await physics_frame
	await process_frame
	var player = level.player
	player.set_physics_process(false)
	var visual = level.robot_visual
	visual.set_physics_process(false)
	for unit in level.enemies:
		unit.set_physics_process(false)
	assert(not player.pulse_gun_equipped and not player.scatter_unlocked)
	assert(visual._uses_rig() and visual.diagonal_legs.size() == 7)
	assert(player.has_node("PlayerModelHurtbox") and player.collision_mask == 1)
	assert(level._remaining_cleaners() == level.enemies.size())
	Input.action_press("move_right")
	Input.action_press("b_sprint")
	player._physics_process(0.01)
	assert(player.sprint_active and is_equal_approx(player.velocity.length(),200.0))
	Input.action_release("b_sprint")
	player._physics_process(0.01)
	assert(not player.sprint_active and is_equal_approx(player.velocity.length(),160.0))
	Input.action_release("move_right")
	var enemy = level.enemies[0]
	assert(enemy.combat_visual().name == "CleanerModel")
	var inverse := root.canvas_transform.affine_inverse()
	enemy.global_position = inverse*Vector2(900,320)
	assert(enemy.can_detect())
	enemy.global_position = inverse*Vector2(-200,320)
	assert(not enemy.can_detect())
	# Use a known clear spawn position to verify main-scene eye emission.
	enemy.global_position = player.global_position
	enemy.web_direction = Vector2.RIGHT
	enemy.fire_web()
	assert(not get_nodes_in_group("b_cleaner_webs").is_empty())
	var web = get_nodes_in_group("b_cleaner_webs")[0]
	web.set_physics_process(false)
	assert(web.global_position.distance_to(enemy.eye_origin())<0.01)
	player.apply_web_slow(2.0,0.6)
	paused = true
	var before: float = player.web_slow_remaining
	await create_timer(0.05,true).timeout
	assert(player.web_slow_remaining == before and not web.can_process())
	paused = false
	player.learn_pulse()
	level.pulse_learned = true
	level._retry_level()
	await process_frame
	assert(player.pulse_gun_equipped and not player.scatter_unlocked)
	assert(player.web_slow_remaining == 0.0 and not player.sprint_active)
	assert(get_nodes_in_group("b_cleaner_webs").is_empty())
	assert(level._remaining_cleaners() == level.enemies.size())
	for unit in level.enemies:
		unit.apply_damage(unit.max_health)
	assert(level._remaining_cleaners() == 0)
	assert(level.terminal_gate.get_meta("is_open"))
	# Exit callback recognizes the model's damage body rather than ignoring it.
	level.terminal_activated = true
	for obj in level.interactables_parent.get_children():
		if obj.get_meta("is_final_exit",false):
			level._on_exit_entered(player.get_node("PlayerModelHurtbox"),obj.get_meta("exit_id"))
			assert(level.is_level_complete)
			break
	level.queue_free()
	await process_frame
	if FileAccess.file_exists("user://test_combat_integration.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_combat_integration.cfg"))
	print("Main combat integration: unarmed gait/unlocks, sprint, model hitbox, screen detection, eye emission, pause, retry, cleaner gate and exit: PASS")
	quit()
