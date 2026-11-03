extends SceneTree

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run")

func press(player: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	player._unhandled_input(event)

func run() -> void:
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = "user://test_main_auto_mode.cfg"
	root.add_child(level)
	current_scene = level
	await process_frame
	await physics_frame
	var player = level.player
	player.set_physics_process(false)
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	visual.set_physics_process(false)
	assert(visual.get_script() == load("res://tests/manual/b_combat/xiaoyi_aim_visual.gd"))
	assert(visual.enhanced_gait and visual.face_firing_beam)
	var enemies := get_nodes_in_group("combat_enemies")
	assert(not enemies.is_empty())
	for unit in enemies:
		unit.set_physics_process(false)
		unit.hide()
	var enemy = enemies[0]
	enemy.show()
	# Screen coordinates deliberately account for the production camera transform.
	var inverse := root.canvas_transform.affine_inverse()
	enemy.global_position = inverse * Vector2(576, 324)
	player.update_combat_mode()
	assert(player.enemies_on_screen and player.attack_mode == 2)
	assert(not player.can_fire_pulse()) # Seeing an enemy cannot bypass learning.
	player.pulse_gun_equipped = true
	player.update_combat_mode()
	assert(player.attack_mode == 1 and player.can_fire_pulse())
	press(player, KEY_2)
	assert(player.attack_mode == 1 and not player.scatter_unlocked)
	press(player, KEY_3)
	assert(player.attack_mode == 1) # Old scatter key is removed in production.
	player.scatter_unlocked = true # Simulate the future evolution point only here.
	press(player, KEY_2)
	assert(player.attack_mode == 3 and not player.can_fire_pulse())
	player.update_combat_mode()
	assert(player.attack_mode == 3) # Auto selection must not overwrite a chosen arm.
	press(player, KEY_1)
	assert(player.attack_mode == 1)
	player.pulse_gun.request_fire(Vector2.RIGHT)
	press(player, KEY_2)
	assert(player.attack_mode == 1) # Cannot bypass charge timing via switching.
	enemy.global_position = inverse * Vector2(-100, 324)
	player.update_combat_mode()
	assert(player.attack_mode == 1 and player.pulse_gun.state == player.pulse_gun.State.CHARGING)
	player.pulse_gun.cancel()
	player.advance_pose_time(2.1)
	player.update_combat_mode()
	assert(player.attack_mode == 2)
	assert(player.pulse_gun_equipped) # Holstering does not forget the learned ability.
	press(player, KEY_2)
	assert(player.attack_mode == 2 and player.selected_mode == 3)
	enemy.global_position = inverse * Vector2(576, 324)
	player.update_combat_mode()
	assert(player.attack_mode == 3)
	enemy.apply_damage(999)
	player.update_combat_mode()
	assert(player.attack_mode == 2) # Dead enemies on screen never keep an arm raised.
	player.restore_player(player.global_position, 3, ["pulse_gun"])
	assert(player.pulse_gun_equipped and player.attack_mode == 2)
	visual.update_animation(0.2, Vector2.LEFT*3, false)
	assert(visual.facing_row == 2)
	level.queue_free()
	await process_frame
	print("Main auto modes: acquisition, screen bounds, keys, unlock gate, charge, death and independent visual: PASS")
	quit()
