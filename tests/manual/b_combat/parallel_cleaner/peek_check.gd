extends "res://tests/manual/b_combat/parallel_cleaner/throw_check.gd"

const HOME := Vector2(746, 562)
const PEEK := Vector2(571, 608)
const HIDDEN := Vector2(566, 470)
var checks_passed := 0

func wait_for(boss: BOSS, predicate: Callable, steps: int) -> bool:
	for i in range(steps):
		if predicate.call():
			return true
		await tick(boss)
	return predicate.call()

func fire_at_boss(boss: BOSS) -> bool:
	var gun: PULSE = room.player.pulse_gun
	var origin: Vector2 = room.player.global_position
	var direction := origin.direction_to(boss.armor.global_position)
	var hp := boss.health
	gun.use_muzzle = false
	room.player.aim_at(boss.armor.global_position)
	if not gun.request_fire(direction):
		return false
	for i in range(70):
		gun.advance_time(STEP, origin, direction)
		if boss.health < hp:
			break
		await tick(boss)
	if boss.health == hp:
		print("PEEK_PULSE_MISS origin=%s aim=%s contact=%s" % [origin, boss.armor.global_position, gun.first_contact])
	gun.cancel()
	return boss.health == hp - 1

func check_observation(boss: BOSS) -> void:
	await stage(boss, HOME, HIDDEN - HOME, "")
	boss.health = BOSS.MAX_HP
	boss._switch(BOSS.Phase.RECOVER, 12.0)
	assert(not boss._can_see_player())
	boss.take_pulse_hit(1, room.player)
	assert(boss.peek_hits.is_empty())
	room.player.global_position = PEEK
	await tick(boss)
	assert(boss._visible_peek_corner(PEEK) == Vector2i(-1, 1))
	assert(await fire_at_boss(boss), "Pulse around the south corner must physically hit.")
	assert(boss.peek_response == BOSS.PeekResponse.NONE and boss.peek_hits.size() == 1)
	boss.global_position = Vector2(752, 376)
	room.player.global_position = Vector2(571, 335)
	await tick(boss)
	assert(await fire_at_boss(boss))
	assert(boss.peek_response == BOSS.PeekResponse.NONE and boss.peek_hits.size() == 2)
	for i in range(301):
		await tick(boss)
	boss.global_position = HOME
	room.player.global_position = PEEK
	await tick(boss)
	assert(await fire_at_boss(boss))
	assert(boss.peek_response == BOSS.PeekResponse.NONE)
	checks_passed += 1
	print("PEEK_OBSERVATION_PASS: occlusion, different corners, and expired memory never trigger")

func ready_queue(boss: BOSS, label: String) -> void:
	await stage(boss, HOME, PEEK - HOME, label)
	boss.health = BOSS.MAX_HP
	boss._switch(BOSS.Phase.RECOVER, 2.9)
	assert(await fire_at_boss(boss))
	room.player.global_position = HIDDEN
	for i in range(15):
		await tick(boss)
	room.player.global_position = PEEK
	await tick(boss)
	assert(await fire_at_boss(boss))
	assert(boss.peek_response == BOSS.PeekResponse.QUEUED and boss.peek_corner == Vector2i(-1, 1))
	assert(boss.phase == BOSS.Phase.RECOVER and boss.left > 0.5 and boss.global_position == HOME)

func check_counter(boss: BOSS) -> void:
	await ready_queue(boss, "露头两次 · 绕向另一侧")
	room.player.global_position = HIDDEN
	boss.web_cooldown = 0.0
	assert(await wait_for(boss, func(): return boss.web_close_peek, 110), "Open retreat should allow the cover shot.")
	var original_exit := boss.peek_route[-1]
	var entry := boss.peek_route[-2]
	assert(original_exit.y < boss.machine_bounds.position.y)
	room.player.global_position = original_exit
	await tick(boss)
	assert(not boss._can_see_player() and not boss._can_step(entry, original_exit))
	assert(boss._can_peek_step(entry, original_exit), "The route shouldn't infer the hidden player's collision position.")
	var barrier := obstacle(Vector2(boss.machine_bounds.get_center().x, original_exit.y), Vector2(8, 4))
	# Walk deeper behind the wall after the shot has committed.
	room.player.global_position = Vector2(514, 490)
	assert(not boss._can_see_player() and boss.peek_last_seen == PEEK)
	assert(await wait_for(boss, func(): return boss.leftover_silk.size() == 1, 35))
	assert(not boss.bound and boss.peek_response == BOSS.PeekResponse.CROSSING)
	assert(boss.leftover_silk[0].at.x > boss.machine_bounds.end.x)
	if not capture_dir.is_empty():
		await capture("peek-silk.png")
	boss.slam_cooldown = 8.0
	boss.sweep_cooldown = 8.0
	assert(await wait_for(boss, func(): return boss.peek_response == BOSS.PeekResponse.SEARCHING, 360))
	assert(boss.global_position.x < boss.machine_bounds.position.x)
	assert(boss.global_position.y < original_exit.y - 9.0)
	assert(boss._chassis_is_clear_at(boss.global_position))
	barrier.queue_free()
	checks_passed += 1
	print("PEEK_SWAP_PASS: web lands by the old corner, moving behind the wall keeps the same plan, blocked exit reroutes")

func check_skip_silk(boss: BOSS) -> void:
	await ready_queue(boss, "退路被挡 · 跳过封网")
	# Keep the last seen footing but block the sideways and inward steps.
	# The outward step already leaves the encounter at this corner.
	var side_block := obstacle(PEEK + Vector2(-22, 0), Vector2(6, 25))
	var inward_block := obstacle(PEEK + Vector2(0, -22), Vector2(25, 6))
	room.player.global_position = HIDDEN
	boss.web_cooldown = 0.0
	assert(await wait_for(boss, func(): return boss.phase == BOSS.Phase.FLANK, 115))
	assert(boss.peek_response == BOSS.PeekResponse.CROSSING and not boss.web_active and boss.leftover_silk.is_empty())
	side_block.queue_free()
	inward_block.queue_free()
	checks_passed += 1
	print("PEEK_ESCAPE_PASS: blocked retreat suppresses the cover shot")

func check_punish(boss: BOSS) -> void:
	await ready_queue(boss, "换边诱招 · 躲开重砸后反击")
	room.player.global_position = Vector2(800, 459)
	boss.web_cooldown = 8.0
	boss.sweep_cooldown = 0.0
	boss.slam_cooldown = 0.0
	assert(await wait_for(boss, func(): return boss.peek_response == BOSS.PeekResponse.SEARCHING, 350))
	assert(not boss._can_see_player(), "Across the compressor, do not wind up without a new sighting.")
	var end := boss.global_position
	for i in range(16):
		await tick(boss)
	assert(boss.global_position == end and boss.phase == BOSS.Phase.STALK)
	room.player.global_position = end + Vector2(-82, 28)
	assert(await wait_for(boss, func(): return boss.phase == BOSS.Phase.SLAM, 10))
	assert(boss.action_frame == 0 and boss.slam_clock == 0.0, "Reacquisition uses the whole windup.")
	assert(await wait_for(boss, func(): return boss.ground_visual.warning, 20))
	assert(room.player.move_and_collide(Vector2(-62, 52)) == null)
	assert(await wait_for(boss, func(): return boss.phase == BOSS.Phase.RECOVER, 100))
	assert(is_equal_approx(boss.left, 0.93) and not boss.slam_impact.hurt and room.player.health == room.player.max_health)
	assert(await fire_at_boss(boss), "A freshly charged pulse must still hit inside the missed-slam window.")
	assert(boss.phase == BOSS.Phase.RECOVER and boss.left > 0.0)
	checks_passed += 1
	print("PEEK_PUNISH_PASS: full slam warning after reacquisition, 0.93-second miss recovery still punishable")

func run() -> void:
	room = SCENE.instantiate()
	root.add_child(room)
	current_scene = room
	while not room.prototype_ready:
		await process_frame
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var boss := await make_boss()
	room.set_process(false)
	room.set_physics_process(false)
	room.set_combat_debug(false)
	await check_observation(boss)
	await check_counter(boss)
	await check_skip_silk(boss)
	await check_punish(boss)
	press(KEY_R)
	assert(not is_instance_valid(room.boss) and boss.peek_hits.is_empty() and boss.peek_route.is_empty())
	room.queue_free()
	await process_frame
	assert(checks_passed == 4)
	print("PEEK_RESPONSE_PASS")
	quit()
