extends SceneTree

class Dummy extends StaticBody2D:
	var hits := 0
	func apply_damage(_amount: int) -> void:
		hits += 1

var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func key(player: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	player._unhandled_input(event)
func _run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	var gun = player.pulse_gun
	player.set_physics_process(false)
	visual.set_process(false)
	visual.set_physics_process(false)
	for enemy in get_nodes_in_group("combat_enemies"):
		enemy.set_physics_process(false)
	key(player, KEY_2)
	check(player.attack_mode == 2 and not player.pulse_gun_equipped, "2 selects unarmed.")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	check(gun.state == gun.State.IDLE and not player.fire_scatter(Vector2.RIGHT), "Unarmed blocks both attacks.")
	visual.update_animation(0.2, Vector2.LEFT * 3, false)
	check(visual.facing_row == 2, "Unarmed faces movement.")
	key(player, KEY_1)
	player.mouse_facing = Vector2.UP
	visual.update_animation(0.2, Vector2.DOWN * 3, false)
	check(visual.facing_row == 4, "Laser body faces mouse while moving opposite.")
	check(str(visual.frames[0].get_meta("source_path")).ends_with("xiaoyi_laser_8dir.png"), "Laser selects raised left arm art.")
	gun.request_fire(Vector2.RIGHT)
	key(player, KEY_2)
	check(player.attack_mode == 1, "Cannot switch out of charge to bypass timing.")
	gun.cancel()
	key(player, KEY_3)
	visual.update_animation(0.2, Vector2.ZERO, false)
	check(str(visual.frames[0].get_meta("source_path")).ends_with("xiaoyi_scatter_8dir.png"), "Scatter selects raised right arm art.")
	check(player.fire_scatter(Vector2.RIGHT), "Scatter mode can fire.")
	check(get_nodes_in_group("b_scatter_pellets").size() == 3, "One click spawns exactly three pellets.")
	check(not player.fire_scatter(Vector2.RIGHT) and not player.set_attack_mode(1), "Cooldown blocks repeat and switching.")
	player.scatter_remaining = 0.001
	player._physics_process(0.001)
	check(player.set_attack_mode(2), "Switching works after full cooldown.")
	player.restore_player(Vector2(160, 320), 3, [&"pulse_gun"])
	await process_frame
	check(get_nodes_in_group("b_scatter_pellets").is_empty(), "Reset cleans projectiles.")
	var sentry = room.get_node("SpawnPoints/SentrySpawn/Sentry")
	var cleaner = room.get_node("SpawnPoints/CleanerSpawn/Cleaner")
	sentry.global_position = Vector2(200, 320)
	cleaner.global_position = Vector2(300, 320)
	visual.update_nearest_enemy()
	check(visual.nearest_enemy == sentry and visual.arrow_direction.is_equal_approx(Vector2.RIGHT), "Arrow selects closest enemy independent of cursor.")
	sentry.apply_damage(100)
	visual.update_nearest_enemy()
	check(visual.nearest_enemy == cleaner, "Arrow skips dead enemy.")
	cleaner.apply_damage(100)
	visual.update_nearest_enemy()
	check(visual.nearest_enemy == null and visual.arrow_direction == Vector2.ZERO, "No living enemies hides arrow.")
	var dummy := Dummy.new()
	dummy.collision_layer = 4
	dummy.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 80)
	shape.shape = box
	dummy.add_child(shape)
	room.add_child(dummy)
	dummy.global_position = Vector2(240, 500)
	await physics_frame
	player.global_position = Vector2(160, 500)
	player.set_attack_mode(3)
	player.fire_scatter(Vector2.RIGHT)
	for pellet in get_nodes_in_group("b_scatter_pellets"):
		pellet.set_physics_process(false)
		pellet._physics_process(0.3)
		pellet._physics_process(0.3)
	check(dummy.hits == 3, "Three pellets independently damage same target exactly once each.")
	await process_frame
	player.scatter_remaining = 0.0
	player.global_position = Vector2(350, 224)
	player.fire_scatter(Vector2.RIGHT)
	for pellet in get_nodes_in_group("b_scatter_pellets"):
		pellet.set_physics_process(false)
		pellet._physics_process(0.3)
		check(pellet.spent and pellet.global_position.x <= 400.1, "Pellets stop at wall without tunnelling.")
	await process_frame
	player.scatter_remaining = 0.0
	player.global_position = Vector2(160, 500)
	player.fire_scatter(Vector2.LEFT)
	for pellet in get_nodes_in_group("b_scatter_pellets"):
		pellet.set_physics_process(false)
		pellet._physics_process(1.0)
		check(pellet.spent, "Pellets expire at short range.")
	player.set_protocol_active(true)
	player.scatter_remaining = 0.0
	check(not player.fire_scatter(Vector2.RIGHT), "Protocol blocks scatter.")
	player.set_protocol_active(false)
	player.apply_damage(100)
	check(not player.fire_scatter(Vector2.RIGHT) and not player.set_attack_mode(2), "Death blocks attacks and switches.")
	room.queue_free()
	await process_frame
	print("Attack mode checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
