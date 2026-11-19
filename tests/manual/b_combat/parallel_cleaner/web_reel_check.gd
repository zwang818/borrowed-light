extends "res://tests/manual/b_combat/parallel_cleaner/throw_check.gd"

const OPEN := Vector2(435, 586)
const FAR_TARGET := Vector2(738, 586)
const EAST := Vector2(774, 476)

func start_web(boss: BOSS) -> void:
	assert(boss._try_fire_web(false))
	assert(boss.phase == BOSS.Phase.WEB_SHOT and boss.web_active and boss.flown == 0.0)

func step_until(boss: BOSS, predicate: Callable, ticks := 180) -> bool:
	for i in range(ticks):
		if predicate.call():
			return true
		await tick(boss)
	return predicate.call()

func first_response(boss: BOSS) -> float:
	var at := boss.global_position
	for step in range(1, 25):
		await tick(boss)
		if at.distance_to(boss.global_position) > 0.7 or boss.phase in [BOSS.Phase.PINCH, BOSS.Phase.SWEEP, BOSS.Phase.SLAM]:
			return step * STEP
	return INF

func compare_lane(boss: BOSS) -> void:
	await stage(boss, OPEN, FAR_TARGET - OPEN, "吐丝 · 躲开已锁定的弹道")
	start_web(boss)
	var origin := boss.web_tip
	var aim := boss.web_direction
	assert(BOSS.WEB_RANGE == 400.0 and BOSS.WEB_CATCH_RADIUS == 25.0)
	var end := origin + aim * BOSS.WEB_RANGE
	end = boss._world_ray(origin, end).get("position", end)
	var normal := aim.orthogonal()
	var at := boss.global_position
	assert(room.player.move_and_collide(normal * 32.0) == null)
	await tick(boss)
	assert(boss.flown > 0.0 and boss.current_pose == 5)
	if not capture_dir.is_empty():
		await capture("launch.png")
	assert(await step_until(boss, func(): return boss.phase == BOSS.Phase.WEB_SHOT and boss.flown > 195.0))
	assert(boss.current_pose in [4, 5, 6] and boss.global_position == at)
	assert(await step_until(boss, func(): return boss.phase == BOSS.Phase.RECOVER))
	assert(not boss.bound and boss.leftover_silk.size() == 1 and boss.web_direction == aim)
	assert(boss.web_tip.is_equal_approx(end))
	if not capture_dir.is_empty():
		await capture("endpoint.png")
	print("WEB_LANE immediate launch origin=%s direction=%s catch_half_width=%.0f projectile_end=%s" % [origin, aim, BOSS.WEB_CATCH_RADIUS, boss.web_tip])
	var launched_at := boss.global_position
	var response := await first_response(boss)
	assert(response <= 0.1 and boss.web_cooldown > 0.0 and boss.retreat_reason == "无")
	assert((boss.global_position - launched_at).dot(launched_at.direction_to(room.player.global_position)) > 0.0)
	var retry := response
	while boss.phase != BOSS.Phase.WEB_SHOT and retry < 1.0:
		await tick(boss)
		retry += STEP
	assert(boss.phase == BOSS.Phase.WEB_SHOT and absf(retry - BOSS.WEB_MISS_COOLDOWN) <= STEP)
	print("WEB_MISS chase=%.3fs retry=%.3fs after landing" % [response, retry])

func compare_pull(boss: BOSS) -> void:
	await stage(boss, OPEN, FAR_TARGET - OPEN, "吐丝 · 中距离收线")
	start_web(boss)
	assert(await step_until(boss, func(): return boss.bound))
	assert(boss.web_cooldown > BOSS.WEB_MISS_COOLDOWN)
	var from: Vector2 = room.player.global_position
	assert(await step_until(boss, func(): return not boss.bound))
	var moved: float = from.distance_to(room.player.global_position)
	assert(is_equal_approx(moved, BOSS.REEL_MAX_PULL) and is_equal_approx(moved, boss.drawn_pull))
	assert(not boss.held and room.player.controls_enabled)
	assert(boss.reel_end == "达到拉距上限")
	if not capture_dir.is_empty():
		await capture("pull-190.png")
	print("WEB_PULL from=%s to=%s moved=%.2f duration_limit=%.2f" % [from, room.player.global_position, moved, BOSS.REEL_DURATION])

func device_cut(boss: BOSS) -> void:
	var corner := boss.machine_bounds.end
	var position := Vector2(corner.x + 105.0, corner.y - 6.0)
	var start := Vector2(boss.machine_bounds.position.x - 31.0, corner.y + 30.0)
	await stage(boss, position, start - position, "设备断丝 · 拉线中改走设备侧边")
	start_web(boss)
	assert(await step_until(boss, func(): return boss.bound), "Device setup should start with a clear throw: %s" % boss.machine_bounds)
	var player: CharacterBody2D = room.player
	assert(await step_until(boss, func(): return boss.drawn_pull > 1.0))
	for i in range(38):
		assert(player.move_and_collide(Vector2.UP * (player.move_speed * player.web_speed_factor * STEP)) == null)
		await tick(boss)
		if not boss.bound:
			break
	assert(not boss.bound and boss.reel_end == "丝线被遮挡" and player.controls_enabled)
	assert(player.web_slow_remaining <= 0.0 and not player.is_dead)
	var response := await first_response(boss)
	assert(response <= 0.4 and boss.retreat_reason == "无" and boss.phase == BOSS.Phase.FLANK,
		"Device response %s boss=%s player=%s machine=%s %s" % [response, boss.global_position, player.global_position, boss.machine_bounds, boss._diagnose()])
	assert(boss._chassis_is_clear_at(boss.global_position))
	print("WEB_DEVICE cut behind %s, flank displacement at %.3fs without retreat" % [boss.machine_bounds, response])

func check_blocked_step(boss: BOSS) -> void:
	await stage(boss, EAST, Vector2(153, 0), "实体阻挡 · 收线撞停立即解除")
	start_web(boss)
	assert(await step_until(boss, func(): return boss.bound))
	# This post is beside the centre line: the silk still has sight, but the feet cannot pass.
	var post := obstacle(Vector2(900, 484), Vector2(4, 6))
	await frames(2)
	assert(await step_until(boss, func(): return not boss.bound))
	assert(boss.reel_end == "小一撞到障碍" and boss.drawn_pull > 0.0 and not boss.held)
	assert(is_equal_approx(boss.drawn_pull, 927.0 - float(room.player.global_position.x)))
	post.queue_free()
	print("WEB_BLOCKED player body blocked after %.2fu, only actual displacement counted" % boss.drawn_pull)

func check_timeout(boss: BOSS) -> void:
	await stage(boss, OPEN, Vector2(234, 0), "收线超时 · 回到自由走位")
	start_web(boss)
	assert(await step_until(boss, func(): return boss.bound))
	assert(await step_until(boss, func(): return not boss.bound))
	assert(boss.reel_end == "超时" and not boss.held and room.player.controls_enabled)
	assert(absf(OPEN.distance_to(room.player.global_position) - BOSS.REEL_STOP) < 0.06)
	print("WEB_TIMEOUT detached at 48u before grab warning could finish")

func close_reel(boss: BOSS, sidestep: bool) -> void:
	await stage(boss, EAST, Vector2(149, 0), "近身收线 · 检查完整抓投预警")
	start_web(boss)
	assert(await step_until(boss, func(): return boss.reel_grab_warning))
	var warning := boss.locked
	var player: CharacterBody2D = room.player
	for count in range(55):
		if sidestep:
			var tangent := boss.global_position.direction_to(player.global_position).orthogonal()
			assert(player.move_and_collide(tangent * player.move_speed * player.web_speed_factor * STEP) == null)
		assert(not boss.held and boss.locked == warning)
		await tick(boss)
		if not boss.bound:
			assert(count * STEP >= BOSS.REEL_GRAB_WINDUP - STEP)
			break
	assert(not boss.bound)
	if not sidestep:
		assert(boss.held and boss.phase == BOSS.Phase.LIFT and boss.reel_end.contains("预警完成"))
		assert(absf(EAST.distance_to(player.global_position) - 48.0) <= 0.06)
		print("WEB_CLOSE grabbed at 48u after full %.2fs warning" % BOSS.REEL_GRAB_WINDUP)
		return
	assert(not boss.held and player.controls_enabled and player.health == player.max_health,
		"Side step angle %.1f°: %s" % [rad_to_deg(warning.angle_to(EAST.direction_to(player.global_position))), boss._diagnose()])
	assert(await first_response(boss) <= 0.4 and boss.phase in [BOSS.Phase.PINCH, BOSS.Phase.SWEEP])
	print("WEB_DODGE walking sidestep escaped the locked grab, follow-up chose %s" % BOSS.Phase.keys()[boss.phase])

func point_blank_and_retry(boss: BOSS) -> void:
	await stage(boss, EAST, Vector2.LEFT * 39.0, "贴身等出招 · 短夹")
	boss.web_cooldown = 2.0
	boss._switch(BOSS.Phase.STALK, 0.0)
	assert(await first_response(boss) <= 0.4 and boss.phase == BOSS.Phase.PINCH)
	assert(boss.global_position.is_equal_approx(EAST) and boss.retreat_reason == "无")
	await stage(boss, EAST, Vector2(149, 0), "重试 · 清除丝线与落地网")
	start_web(boss)
	assert(await step_until(boss, func(): return boss.bound))
	boss._drop_silk(Vector2(870, 525))
	assert(not boss.leftover_silk.is_empty())
	press(KEY_R)
	assert(not is_instance_valid(room.boss) and room.player.web_slow_remaining == 0.0)
	assert(room.player.controls_enabled and get_nodes_in_group("b_cleaner_webs").is_empty())
	var fresh := await make_boss()
	assert(not fresh.web_active and not fresh.bound and fresh.leftover_silk.is_empty())
	print("WEB_RETRY point-blank short pinch without backing off; R clears tether and patches")

func run() -> void:
	room = SCENE.instantiate()
	root.add_child(room)
	current_scene = room
	while not room.prototype_ready:
		await process_frame
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
		room.notify_label.add_theme_font_override("font", font)
	var boss := await make_boss()
	boss.combat_debug = capture_dir.is_empty()
	room.set_process(false)
	room.set_physics_process(false)
	await compare_lane(boss)
	await compare_pull(boss)
	await device_cut(boss)
	await check_blocked_step(boss)
	await check_timeout(boss)
	await close_reel(boss, false)
	await close_reel(boss, true)
	await point_blank_and_retry(boss)
	room.queue_free()
	await process_frame
	print("WEB_REEL_PASS")
	quit()
