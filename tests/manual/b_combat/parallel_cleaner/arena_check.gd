extends "res://tests/manual/b_combat/parallel_cleaner/throw_check.gd"

func walk_into_wall(boss: BOSS, start: Vector2, push: Vector2, label: String) -> Vector2:
	await stage(boss, Vector2(774, 476), start - Vector2(774, 476), label)
	assert(room.player.move_and_collide(push) != null, "Expected physical wall contact: " + label)
	await frames(2)
	return room.player.global_position

func check_warning(boss: BOSS, label: String, feet: Vector2, boss_at: Vector2) -> void:
	boss.global_position = boss_at
	room.camera.global_position = feet.lerp(boss_at, 0.5)
	room.camera.reset_smoothing()
	room.camera.force_update_scroll()
	boss.sweep_cooldown = 0.0
	boss.slam_cooldown = 0.0
	boss.web_cooldown = 8.0
	boss._recover(false, 0.12)
	await frames(2)
	print("ARENA %s %s" % [label, boss._diagnose()])
	assert(boss._can_see_player(), label)
	for i in range(24):
		await tick(boss)
		if boss.phase in [BOSS.Phase.SWEEP, BOSS.Phase.SLAM, BOSS.Phase.PINCH]:
			assert(boss.action_frame == 0 and boss.left > 0.0)
			print("ARENA_WARNING %s %s feet=%s" % [label, BOSS.Phase.keys()[boss.phase], feet])
			return
	assert(false, "Boss failed to warn by " + label)

func run() -> void:
	room = SCENE.instantiate()
	root.add_child(room)
	current_scene = room
	while not room.prototype_ready:
		await process_frame
	var boss := await make_boss()
	room.set_physics_process(false)
	room.set_process(false)
	press(KEY_O)
	assert(room.combat_debug and boss.combat_debug)
	var left := await walk_into_wall(boss, Vector2(325, 470), Vector2.LEFT * 110.0, "left")
	assert(room.player.move_and_collide(Vector2.DOWN * 28.0) == null)
	assert(is_equal_approx(left.x, room.player.global_position.x))
	left = room.player.global_position
	await check_warning(boss, "left", left, left + Vector2(72, 0))
	var bottom := await walk_into_wall(boss, Vector2(478, 590), Vector2.DOWN * 110.0, "bottom")
	await check_warning(boss, "bottom", bottom, bottom - Vector2(0, 72))
	var corner := await walk_into_wall(boss, Vector2(326, 585), Vector2(-120, 83), "corner")
	room.player.move_and_collide(Vector2.DOWN * 90.0)
	corner = room.player.global_position
	await check_warning(boss, "corner", corner, corner + Vector2(59, -55))
	await stage(boss, Vector2(720, 474), Vector2(-140, 0), "behind solid cover")
	assert(boss._can_warn_at_target() and not boss._can_see_player())
	boss._recover(false, 0.1)
	boss.web_cooldown = 0.0
	for i in range(60):
		await tick(boss)
		assert(boss.phase not in [BOSS.Phase.SWEEP, BOSS.Phase.SLAM, BOSS.Phase.PINCH] and not boss.bound)
	assert(room.player.health == room.player.max_health)
	await stage(boss, Vector2(640, 590), Vector2(0, 87), "entrance corridor")
	assert(not boss._can_warn_at_target() and boss._line_clear(boss.global_position, room.player.global_position))
	boss.web_cooldown = 0.0
	boss._recover(false, 0.1)
	for i in range(50):
		await tick(boss)
		assert(boss.phase == BOSS.Phase.STALK or boss.phase == BOSS.Phase.RECOVER)
		assert(boss._chassis_arena().has_point(boss.global_position))
	assert(not boss.web_active and room.player.health == room.player.max_health)
	print("ARENA_COVER_PASS: wall blocks attacks; entrance corridor remains outside")
	room.queue_free()
	await process_frame
	print("ARENA_PASS")
	quit()
