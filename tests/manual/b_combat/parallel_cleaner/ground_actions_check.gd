extends "res://tests/manual/b_combat/parallel_cleaner/tuning_check.gd"

const DT := 1.0 / 60.0
const HOME := Vector2(774, 465)
var clip_frame := 0
var contact_count := 0
var contact_shake := Vector2.ZERO
var contact_pose := -1
var contact_clock := -1.0

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	room._input(event)

func film() -> void:
	if not capture_dir.is_empty():
		await capture("clip/frame-%04d.png" % clip_frame)
		clip_frame += 1

func stage(boss: BOSS, at: Vector2, player_at: Vector2, title: String, view: Vector2) -> void:
	boss.cancel_preview_actions()
	boss.set_physics_process(false)
	boss.global_position = at
	room.player.restore_player(player_at, room.player.max_health, ["pulse_gun"])
	room.player.set_physics_process(false)
	room.camera.global_position = view
	room.camera.reset_smoothing()
	room.camera.force_update_scroll()
	room._show_notification(title, 8.0)
	await frames(2)

func tick(boss: BOSS) -> void:
	await physics_frame
	boss._physics_process(DT)
	room._process(DT)

func ray_case(boss: BOSS, origin: Vector2, endpoint: Vector2, should_hurt: bool, label: String, record := false) -> void:
	var gun: PULSE = room.player.pulse_gun
	room.player.global_position = origin
	room.player.aim_at(endpoint)
	boss.health = BOSS.MAX_HP
	var direction := origin.direction_to(endpoint)
	assert(gun.request_fire(direction))
	for step in range(70):
		await physics_frame
		gun.advance_time(DT, origin, direction)
		if record and step >= 44 and step % 2 == 0:
			await film()
		if not gun.first_contact.is_empty():
			break
	assert(not gun.first_contact.is_empty(), label)
	var contact: Vector2 = gun.first_contact.position
	var collider: CollisionObject2D = gun.first_contact.collider
	assert(gun.beam.to_global(gun.beam.points[-1]).is_equal_approx(contact))
	assert(gun.beam_core.to_global(gun.beam_core.points[-1]).is_equal_approx(contact))
	assert((collider in [boss.armor, boss.metal]) == should_hurt)
	print("RAY %s first=%s hit=%s end=%s damage=%d" % [label, collider.get_path(), contact, gun.beam.to_global(gun.beam.points[-1]), BOSS.MAX_HP - boss.health])
	assert(boss.health == BOSS.MAX_HP - int(should_hurt))
	if record:
		for i in range(12):
			await film()
	for i in range(5):
		await physics_frame
		gun.advance_time(DT, origin, direction)
	assert(boss.health == BOSS.MAX_HP - int(should_hurt))
	gun.cancel()

func verify_rays(boss: BOSS) -> void:
	await stage(boss, HOME, HOME + Vector2(120, 20), "脉冲 · 实心下缘截断 / 腿间空隙穿过", Vector2(776, 469))
	room.set_combat_debug(true)
	var gun: PULSE = room.player.pulse_gun
	gun.visible = true
	gun.use_muzzle = false
	gun.configure_space(gun.map_bounds, Callable())
	boss.face_right = true
	for pose in ["idle", "crouched", "contact", "recover"]:
		if pose in ["crouched", "contact"]:
			boss._switch(BOSS.Phase.SLAM, 2.0)
			boss.action_frame = 0 if pose == "crouched" else 5
		else:
			boss._switch(BOSS.Phase.RECOVER, 2.0)
			boss.miss_pose = pose == "recover"
			boss.left = 0.80 if boss.miss_pose else 2.0
		boss._update_frame()
		boss.debug_shapes.queue_redraw()
		await frames(2)
		await ray_case(boss, HOME + Vector2(131, -52), HOME + Vector2(-8, -52), true, pose + "-side")
		await ray_case(boss, HOME + Vector2(122, 4), HOME + Vector2(2, -31), true, pose + "-lower-right", pose == "idle")
	boss.miss_pose = false
	boss._switch(BOSS.Phase.RECOVER, 2.0)
	boss._update_frame()
	await frames(2)
	await ray_case(boss, HOME + Vector2(120, -2), HOME + Vector2(-120, -2), false, "leg-gap", true)
	# The real machine is just in front of the player on the west side.
	await ray_case(boss, Vector2(594, 425), Vector2(805, 425), false, "wall-first", true)
	room.set_combat_debug(false)
	boss.health = BOSS.MAX_HP

func verify_crossing(boss: BOSS) -> void:
	await stage(boss, HOME, HOME + Vector2(48, -12), "横扫 · 连续横穿触发，随后侧移脱离扇面", Vector2(776, 469))
	var player: CharacterBody2D = room.player
	for repetition in range(2):
		boss._switch(BOSS.Phase.STALK, 0.0)
		boss.sweep_cooldown = 0.0
		boss.slam_cooldown = 10.0
		if repetition > 0:
			player.restore_player(HOME + Vector2(48, -12), player.max_health, ["pulse_gun"])
		boss.previous_target = player.global_position
		assert(player.move_and_collide(Vector2(0, 2)) == null)
		await tick(boss)
		assert(boss.phase == BOSS.Phase.SWEEP and boss.target_lateral_speed >= BOSS.SWEEP_LATERAL_SPEED)
		var lock := boss.locked
		assert(boss.sweep_cooldown == BOSS.SWEEP_COOLDOWN_TIME and not boss._can_begin_sweep(53.0))
		for step in range(58):
			if step < 29:
				player.move_and_collide(Vector2(0, 3.25))
			await tick(boss)
			if repetition == 0 and step % 2 == 0:
				await film()
		assert(boss.sweep_struck and player.health == player.max_health and boss.locked == lock)
	# Keep the old short pinch as an isolated fixture. Regular combat resumes with a sweep.
	player.restore_player(HOME + Vector2(48, 0), player.max_health, ["pulse_gun"])
	boss.previous_target = player.global_position
	boss.sweep_cooldown = 0.0
	boss._lock_at_player()
	boss._begin_action(BOSS.Phase.PINCH, BOSS.PINCH_TIME[0])
	await tick(boss)
	assert(boss.phase == BOSS.Phase.PINCH)
	var start := player.global_position
	player.move_and_collide(Vector2(0, 50))
	for i in range(28):
		await tick(boss)
	assert(boss.sweep_after_dodge > 0.0)
	boss._switch(BOSS.Phase.STALK, 0.0)
	player.global_position = start
	boss.previous_target = start
	await tick(boss)
	assert(boss.phase == BOSS.Phase.SWEEP)
	print("CROSS_PASS: two transverse crossings trigger sweep at 49u; locked dodge, separate cooldown, sweep resumes after isolated legacy pinch")

func verify_silk(boss: BOSS) -> void:
	await stage(boss, Vector2(854, 431), Vector2(985, 525), "残丝 · 撞墙在近侧落网，踩中减速后走出", Vector2(900, 474))
	var player: CharacterBody2D = room.player
	boss.web_tip = Vector2(902, 485)
	boss.web_direction = Vector2.RIGHT
	boss._fire_web()
	for i in range(54):
		if i in range(28, 42):
			player.move_and_collide(Vector2(1.35, -2.5))
		await tick(boss)
		if i % 2 == 0:
			await film()
	assert(boss.leftover_silk.size() == 1)
	var patch := boss.leftover_silk[0]
	var centre: Vector2 = patch.at
	assert(centre.is_equal_approx(Vector2(1022, 485)) and patch.age > BOSS.GROUND_FX.SILK_TRANSITION)
	assert(not BOSS.GROUND_FX.covers(boss.get_world_2d().direct_space_state, centre, Vector2(1027, 485), patch.limits))
	player.global_position = centre + Vector2(-12, 0)
	await tick(boss)
	assert(is_equal_approx(player.web_speed_factor, BOSS.GROUND_WEB_FACTOR))
	# A tether releasing while standing in overlapping silk must not clear slow.
	boss._drop_silk(centre + Vector2(-4, 1))
	boss.bound = true
	boss._release_tether()
	assert(boss.slam_grace > 0.0)
	await tick(boss)
	assert(not boss.bound and is_equal_approx(player.web_speed_factor, BOSS.GROUND_WEB_FACTOR))
	await capture("silk-patch.png")
	for i in range(ceili((BOSS.GROUND_WEB_RADIUS + 10.0) / 2.1)):
		player.move_and_collide(Vector2(-2.1, 0))
		await tick(boss)
		if i % 2 == 0:
			await film()
	player.set_physics_process(true)
	await frames(8)
	player.set_physics_process(false)
	assert(is_equal_approx(player.web_speed_factor, 1.0))
	boss._update_ground_silk(BOSS.GROUND_WEB_LIFETIME + DT)
	assert(boss.leftover_silk.is_empty())
	# Clean-air endpoint stays on the actual range boundary.
	boss.web_tip = Vector2(395, 586)
	boss.web_direction = Vector2.RIGHT
	boss._fire_web()
	for i in range(ceili(BOSS.WEB_RANGE / (BOSS.WEB_SPEED * DT)) + 1):
		await tick(boss)
	assert(boss.leftover_silk.size() == 1 and boss.leftover_silk[0].at.is_equal_approx(Vector2(395 + BOSS.WEB_RANGE, 586)))
	print("SILK_PASS: wall and range endpoints, splat -> patch, wall clip, enter/exit, tether release, overlap, expiry")

func verify_slam(boss: BOSS, dodge: bool, shutter_test := false) -> void:
	var player: CharacterBody2D = room.player
	var normal_max: int = player.max_health
	var expected_damage := BOSS.SLAM_DAMAGE if not dodge and not shutter_test else 0
	# The direct-hit fixture needs to survive contact to inspect the entire FX.
	if expected_damage > 0:
		player.max_health = maxi(normal_max, BOSS.SLAM_DAMAGE + 1)
	var title := "重砸 · 提前离圈，地面仍然震动" if dodge else "重砸 · 留在圈内，只在第 6 帧扣一次"
	await stage(boss, HOME, HOME + Vector2(82, 18), title, Vector2(776, 469))
	boss.slam_cooldown = 0.0
	boss.slam_grace = 0.0
	boss.previous_target = player.global_position
	boss._switch(BOSS.Phase.STALK, 0.0)
	var initial_contacts := contact_count
	await tick(boss)
	assert(boss.phase == BOSS.Phase.SLAM and not boss.ground_visual.warning)
	var centre := boss.slam_point
	assert(centre.is_equal_approx(boss.global_position + Vector2(84, 19) * boss.visual_scale))
	assert(boss._slam_landing(false).is_equal_approx(boss.global_position + Vector2(-84, 19) * boss.visual_scale))
	var wall: StaticBody2D
	for step in range(63):
		if dodge and step >= 14 and step < 37:
			player.move_and_collide(Vector2(0, 2.9))
		if shutter_test and step == 10:
			wall = obstacle(centre + Vector2(15, 0), Vector2(4, 81))
			player.global_position = centre + Vector2(24, 0)
		await tick(boss)
		if step == 12:
			assert(boss.ground_visual.warning and boss.ground_visual.warning_point == centre)
		if boss.action_frame == boss.slam_contact_frame and contact_count > initial_contacts and is_zero_approx(float(boss.slam_impact.get("age", -1.0))):
			assert(not boss.ground_visual.warning and boss.slam_impact.at == centre and boss.slam_hitstop == BOSS.SLAM_HITSTOP)
			assert(boss.body_sprite.to_global((boss.slam_anchor + boss.slam_touch) * 1.0).is_equal_approx(centre))
			if not shutter_test:
				await capture("slam-dodge.png" if dodge else "slam-hit.png")
		if not shutter_test and step % 2 == 0:
			await film()
	assert(contact_count == initial_contacts + 1 and contact_pose == boss.slam_contact_frame and is_zero_approx(contact_clock))
	assert(contact_shake.length() > 2.0 and contact_shake.length() < 4.0)
	assert(room.camera.offset == room.shake_base and is_zero_approx(room.shake_left))
	assert(player.health == player.max_health - expected_damage and boss.global_position == HOME)
	if dodge or shutter_test:
		assert(boss.phase == BOSS.Phase.RECOVER and boss.left > 0.8)
	if is_instance_valid(wall):
		wall.queue_free()
	print("SLAM_PASS dodge=%s wall=%s pose=%d fx=01 point=%s shake=%.2f damage=%d" % [
		dodge, shutter_test, contact_pose + 1, centre, contact_shake.length(), player.max_health - player.health])
	if not shutter_test and not capture_dir.is_empty():
		for step in range(26):
			await tick(boss)
			if step % 2 == 0:
				await film()
	if player.max_health != normal_max:
		player.max_health = normal_max
		player.restore_player(player.global_position, normal_max, ["pulse_gun"])

func _on_contact(_at: Vector2) -> void:
	contact_count += 1
	contact_pose = room.boss.action_frame
	contact_clock = room.boss.slam_impact.age
	contact_shake = room.camera.offset - room.shake_base

func run() -> void:
	room = SCENE.instantiate()
	room.achievement_save_path = OS.get_temp_dir().path_join("parallel-ground-%d.cfg" % OS.get_process_id())
	root.add_child(room)
	current_scene = room
	while not room.prototype_ready:
		await process_frame
	if not capture_dir.is_empty():
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
		room.notify_label.add_theme_font_override("font", font)
	press(KEY_B)
	var boss: BOSS = room.boss
	boss.slammed.connect(_on_contact)
	assert(await until(func(): return boss.phase == BOSS.Phase.STALK))
	room.player.set_physics_process(false)
	room.set_physics_process(false)
	room.set_process(false)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("clip"))
	await verify_rays(boss)
	await verify_crossing(boss)
	await verify_silk(boss)
	await verify_slam(boss, true)
	await verify_slam(boss, false)
	await verify_slam(boss, false, true)
	boss._drop_silk(HOME)
	boss.sweep_visual.frame_index = 3
	room._on_slammed(boss.slam_point)
	press(KEY_R)
	assert(not is_instance_valid(room.boss) and boss.leftover_silk.is_empty() and boss.slam_impact.is_empty() and boss.sweep_visual.frame_index == -1)
	assert(room.camera.offset == room.shake_base and room.player.controls_enabled)
	press(KEY_B)
	boss = room.boss
	assert(await until(func(): return boss.phase == BOSS.Phase.STALK))
	room._on_slammed(HOME + Vector2(50, 15))
	boss._drop_silk(HOME)
	room.player.invulnerability_remaining = 0.0
	room.player.apply_damage(room.player.max_health)
	assert(paused and boss.leftover_silk.is_empty() and room.camera.offset == room.shake_base)
	var retry: Button = room.game_menus.find_children("*", "Button", true, false).filter(func(button: Button): return button.text == "重试本房间")[0]
	retry.pressed.emit()
	assert(not paused and not is_instance_valid(room.boss) and room.camera.offset == room.shake_base)
	DirAccess.remove_absolute(room.achievement_save_path)
	room.queue_free()
	await process_frame
	print("GROUND_ACTIONS_PASS")
	quit()
