extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	var gun = player.pulse_gun
	player.set_physics_process(false)
	visual.set_physics_process(false)
	visual.set_process(false)
	for enemy in get_nodes_in_group("combat_enemies"):
		enemy.set_physics_process(false)
	player.global_position = Vector2(200, 500)
	await physics_frame
	for row in range(8):
		for column in range(4):
			visual.facing_row = row
			visual.current_column = column
			for mode in [1, 3]:
				var corrected: bool = (mode == 1 and row == 5) or (mode == 3 and row in [6, 7])
				var source: String = visual.mode_frames[mode][row * 4 + column].get_meta("source_path")
				check(source.contains("handedness") == corrected, "Only the three requested directions use corrected artwork.")
				var point: Vector2 = visual.get_muzzle_world_position(mode)
				check(point.distance_to(player.global_position) > 10.0, "Muzzle must not stay at body center.")
				check(point.distance_to(player.global_position) < 70.0, "Muzzle must stay on the robot sprite.")
	visual.facing_row = 6
	visual.current_column = 0
	visual._show_frame()
	var muzzle: Vector2 = visual.get_muzzle_world_position(1)
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.8, player.global_position, Vector2.RIGHT)
	gun.advance_time(0.03, player.global_position, Vector2.RIGHT)
	check(gun.beam_points.size() >= 2 and gun.beam_points[0].is_equal_approx(muzzle), "Laser begins at animated left-arm lens.")
	var before: Vector2 = gun.beam_points[0]
	player.global_position += Vector2(8, 4)
	gun.advance_time(0.01, player.global_position)
	check(gun.beam_points[0].is_equal_approx(before + Vector2(8, 4)), "Laser muzzle follows movement.")
	visual.current_column = 1
	gun.refresh_muzzle_visuals()
	check(gun.beam_points[0].is_equal_approx(visual.get_muzzle_world_position(1)), "Laser follows the changed walk frame.")
	gun.cancel()
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.2, player.global_position)
	check(gun.charge_glow.global_position.is_equal_approx(visual.get_muzzle_world_position(1)), "Charge glow follows left muzzle.")
	gun.cancel()
	player.set_attack_mode(3)
	visual.current_column = 0
	var scatter_muzzle: Vector2 = visual.get_muzzle_world_position(3)
	check(player.fire_scatter(Vector2.RIGHT), "Scatter fires from right arm.")
	for pellet in get_nodes_in_group("b_scatter_pellets"):
		pellet.set_physics_process(false)
		check(pellet.global_position.is_equal_approx(scatter_muzzle), "All pellets start at right muzzle.")
	player.restore_player(Vector2(390, 224), 3, [&"pulse_gun"])
	await physics_frame
	visual.facing_row = 6
	visual.current_column = 0
	var obstruction: Dictionary = player.get_shot_origin(1)
	check(obstruction.blocked, "Wall between body and muzzle must block firing.")
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.8, player.global_position, Vector2.RIGHT)
	gun.advance_time(0.04, player.global_position)
	check(not gun.beam.visible and gun.contact_remaining >= 0.0, "Occluded muzzle cannot send laser through wall.")
	gun.cancel()
	player.set_attack_mode(3)
	player.fire_scatter(Vector2.RIGHT)
	for pellet in get_nodes_in_group("b_scatter_pellets"):
		check(pellet.spent and pellet.global_position.x <= 400.1, "Blocked scatter muzzle consumes pellets at wall.")
	room.queue_free()
	await process_frame
	print("Muzzle checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
