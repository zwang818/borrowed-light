extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	player.set_physics_process(false)
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	visual.set_physics_process(false)
	var cleaner = room.get_node("SpawnPoints/CleanerSpawn/Cleaner")
	assert(cleaner.has_node("ModelHurtbox"))
	assert(visual.display_height == 60.0)
	assert(player.pulse_gun_equipped and player.scatter_unlocked)
	for enemy in get_nodes_in_group("combat_enemies"):
		enemy.set_physics_process(false)
		enemy.hide()
	player.update_combat_mode()
	assert(player.attack_mode == 2)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.pressed = true
	player._unhandled_input(key)
	assert(player.selected_mode == 3 and player.attack_mode == 2)
	var click := InputEventAction.new()
	click.action = &"shoot"
	click.pressed = true
	player._unhandled_input(click)
	assert(player.attack_mode == 3 and get_nodes_in_group("b_scatter_pellets").size() == 3)
	player.scatter_remaining = 0.0
	player.advance_pose_time(2.1)
	player.update_combat_mode()
	assert(player.attack_mode == 2 and player.selected_mode == 3)
	visual._show_frame()
	assert(visual.arm_nodes[0].visible and visual.arm_nodes[1].visible)
	key.physical_keycode = KEY_1
	player._unhandled_input(key)
	player._unhandled_input(click)
	assert(player.pulse_gun.state == player.pulse_gun.State.CHARGING)
	room.reset_test_combat()
	assert(player.pulse_gun.state == player.pulse_gun.State.IDLE and player.health == player.max_health)
	assert(player.inspection_remaining == 0 and player.scatter_unlocked)
	await process_frame
	assert(get_nodes_in_group("b_scatter_pellets").is_empty())
	room.queue_free()
	await process_frame
	print("Graybox sync: main visual/hurtbox, 1/2 selection, idle attack, holster, modules and reset: PASS")
	quit()
