extends "res://tests/manual/b_combat/parallel_cleaner/tuning_check.gd"

const STEP := 1.0 / 60.0
const GRIP := preload("res://tests/manual/b_combat/parallel_cleaner/grab_visual.gd")
var frame_index := 0
var landing_count := 0
var landed_motion := Vector2.ZERO

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	room._input(event)

func tick(boss: BOSS) -> void:
	await physics_frame
	boss._physics_process(STEP)
	room._process(STEP)

func capture(file: String) -> void:
	room.camera.force_update_scroll()
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	assert(image.save_png(capture_dir.path_join(file)) == OK)

func film() -> void:
	if not capture_dir.is_empty():
		await capture("clip/frame-%04d.png" % frame_index)
		frame_index += 1

func make_boss() -> BOSS:
	press(KEY_B)
	var boss: BOSS = room.boss
	assert(await until(func(): return boss.phase == BOSS.Phase.STALK))
	boss.set_physics_process(false)
	boss.throw_landed.connect(func(direction: Vector2):
		landing_count += 1
		landed_motion = direction)
	return boss

func stage(boss: BOSS, at: Vector2, offset: Vector2, caption: String) -> void:
	boss.cancel_preview_actions()
	boss.global_position = at
	room.player.restore_player(at + offset, room.player.max_health, ["pulse_gun"])
	room.player.set_physics_process(false)
	room.camera.global_position = at + offset.normalized() * 34.0
	room.camera.reset_smoothing()
	room.camera.force_update_scroll()
	room._show_notification(caption, 5.0)
	await frames(2)

func throw_case(boss: BOSS, title: String, file: String, at: Vector2, direction: Vector2, row: int, early := false) -> void:
	await stage(boss, at, direction * 70.0, title)
	var player: CharacterBody2D = room.player
	var fx := boss.grab_visual
	var before_count := landing_count
	boss._begin_grab_warning()
	var released := false
	var last_grip := Vector2.ZERO
	var release_feet := Vector2.ZERO
	var took_lift := false
	var saw_return_pose_in_air := false
	var recorded_landing := false
	for step in range(134):
		await tick(boss)
		if fx.stage == GRIP.Stage.GRIPPED:
			took_lift = true
			last_grip = fx.visual_at
			assert(fx.front_jaw.visible and not room.robot_visual.visible)
			assert(player.health == player.max_health and boss.held)
		if not released and fx.stage == GRIP.Stage.FLIGHT:
			released = true
			release_feet = player.global_position
			assert(fx.visual_at.is_equal_approx(last_grip), "Release must start at the same visible torso point.")
			assert(fx.direction_row == row and not fx.front_jaw.visible)
			if not capture_dir.is_empty():
				await capture(file + "-flight.png")
		if fx.stage == GRIP.Stage.FLIGHT:
			assert(fx.direction_row == row)
			saw_return_pose_in_air = saw_return_pose_in_air or boss.body_sprite.texture == fx.boss_frames[3]
		if not recorded_landing and fx.stage == GRIP.Stage.GROUND:
			recorded_landing = true
			assert(fx.skid_at.is_equal_approx(player.global_position) and fx.visual_at.is_equal_approx(fx.skid_at))
			assert(fx.direction_row == row and player.controls_enabled and not boss.held)
			assert(player.health == player.max_health - 1 and landing_count == before_count + 1)
			assert(landed_motion.dot(direction) > 0.99)
			var length := release_feet.distance_to(fx.skid_at)
			assert(length < BOSS.THROW_DISTANCE - 12.0 if early else absf(length - BOSS.THROW_DISTANCE) < 1.0)
			if early:
				assert(fx.skid_scale.x < 0.60 and fx.skid_limits[GRIP.SKID_RAYS / 2] < 13.0)
			print("THROW %s pose=%d release=%s first_ground=%s swept=%.2f hp=%d" % [
				file, row, release_feet, fx.skid_at, length, player.health])
			if not capture_dir.is_empty():
				await capture(file + "-ground.png")
		if step >= 39 and step < 110 and step % 2 == 0:
			await film()
	assert(took_lift and released and recorded_landing and saw_return_pose_in_air)
	assert(landing_count == before_count + 1 and player.health == player.max_health - 1)
	assert(room.camera.offset == room.shake_base and not fx.override_player() and fx.skid_age < 0.0)

func verify_miss_and_reel(boss: BOSS) -> void:
	await stage(boss, Vector2(780, 471), Vector2(70, 0), "抓空 · 没有插槽火花或落地擦痕")
	var before_count := landing_count
	boss._begin_grab_warning()
	room.player.move_and_collide(Vector2(0, 100))
	for step in range(74):
		await tick(boss)
		if step >= 34 and step % 2 == 0:
			await film()
	assert(boss.phase == BOSS.Phase.RECOVER and boss.miss_pose and not boss.held)
	assert(landing_count == before_count and boss.grab_visual.skid_age < 0.0 and not boss.grab_visual.grip_flash.visible)

	await stage(boss, Vector2(774, 476), Vector2(147, 16), "实战收线 · 拉到位直接扣住")
	boss.web_cooldown = 0.0
	boss._switch(BOSS.Phase.STALK, 0.0)
	var reeled := false
	for step in range(180):
		await tick(boss)
		reeled = reeled or boss.bound
		if reeled and step % 2 == 0:
			await film()
		if boss.phase == BOSS.Phase.LIFT:
			break
	assert(reeled and boss.phase == BOSS.Phase.LIFT and not boss.bound and boss.held)
	assert(boss.drawn_pull >= BOSS.GRAB_MIN_PULL and room.player.global_position.distance_to(boss.global_position) <= BOSS.REEL_GRAB_REACH)
	assert(boss.grab_visual.front_jaw.visible)
	if not capture_dir.is_empty():
		await capture("06-reel-grip.png")
		for frame in range(8):
			await film()
	var hold := boss.left
	var age := boss.grab_visual.lock_age
	boss.set_physics_process(true)
	paused = true
	await frames(12)
	assert(boss.left == hold and boss.grab_visual.lock_age == age)
	paused = false
	boss.set_physics_process(false)
	var visuals := boss.grab_visual
	press(KEY_R)
	assert(not is_instance_valid(room.boss) and room.player.controls_enabled and room.robot_visual.visible)
	assert(not visuals.override_player() and not visuals.front_jaw.visible and not visuals.grip_flash.visible and visuals.trail.is_empty())
	assert(visuals.skid_age < 0.0 and room.camera.offset == room.shake_base)
	room._show_notification("R 重试 · 已解除抓取，恢复操作", 5.0)
	for frame in range(13):
		await film()
	print("GRAB_PASS: empty claw no impact, actual silk -> reel -> new grip, pause freezes, R clears all tracks")

func run() -> void:
	room = SCENE.instantiate()
	root.add_child(room)
	current_scene = room
	while not room.prototype_ready:
		await process_frame
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("clip"))
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
		room.notify_label.add_theme_font_override("font", font)
	var boss := await make_boss()
	room.set_process(false)
	room.set_physics_process(false)
	room.set_combat_debug(false)
	await throw_case(boss, "正上 · 飞出与擦地都看见背包", "01-north", Vector2(520, 493), Vector2.UP, 4)
	await throw_case(boss, "正下 · 飞出与擦地都看见正脸", "02-south", Vector2(782, 428), Vector2.DOWN, 0)
	await throw_case(boss, "左上 · 使用独立斜向帧", "03-northwest", Vector2(556, 488), Vector2(-1, -1).normalized(), 3)
	await throw_case(boss, "右下 · 使用独立斜向帧", "04-southeast", Vector2(760, 443), Vector2(1, 1).normalized(), 7)
	await throw_case(boss, "撞设备早停 · 朝向不变，擦痕留在近侧", "05-wall", Vector2(780, 471), Vector2.LEFT, 2, true)
	await verify_miss_and_reel(boss)
	room.queue_free()
	await process_frame
	print("THROW_VISUALS_PASS")
	quit()
