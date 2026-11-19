extends SceneTree

const SCENE := preload("res://tests/manual/b_combat/parallel_cleaner/abdomen_boss_playtest.tscn")
const BOSS := preload("res://tests/manual/b_combat/parallel_cleaner/boss.gd")
const PULSE := preload("res://tests/manual/b_combat/parallel_cleaner/test_pulse.gd")
var room
var capture_dir := OS.get_environment("PARALLEL_CLEANER_CAPTURE")

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func capture(file: String) -> void:
	if capture_dir.is_empty():
		return
	room.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(capture_dir.path_join(file)) == OK)

func until(predicate: Callable, limit := 120) -> bool:
	for i in range(limit):
		await physics_frame
		if predicate.call():
			return true
	return false

func obstacle(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "TuningWall"
	body.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	room.add_child(body)
	return body

func fire(boss: BOSS, from: Vector2, at: Vector2, expected: CollisionObject2D, should_hurt: bool, shot_file := "") -> void:
	var gun: PULSE = room.player.pulse_gun
	gun.use_muzzle = false
	room.player.global_position = from
	room.player.aim_at(at)
	var direction := from.direction_to(at)
	var hp := boss.health
	assert(gun.request_fire(direction))
	for i in range(70):
		await physics_frame
		gun.advance_time(1.0 / 60.0, from, direction)
		if not gun.first_contact.is_empty():
			break
	assert(gun.first_contact.get("collider") == expected,
		"Ray %s -> %s should hit %s, got %s." % [from, at, expected, gun.first_contact])
	var hit: Vector2 = gun.first_contact.position
	assert(gun.beam.to_global(gun.beam.points[-1]).is_equal_approx(hit))
	assert(gun.beam_core.to_global(gun.beam_core.points[-1]).is_equal_approx(hit))
	var facing: Node2D = room.player.facing
	var before_rotation := facing.rotation
	facing.rotation += 0.15 # Aim assist can turn Facing after the first firing tick.
	assert(gun.beam.to_global(gun.beam.points[-1]).is_equal_approx(hit))
	assert(gun.beam_core.to_global(gun.beam_core.points[-1]).is_equal_approx(hit))
	assert(gun.impact_fx.to_global(gun.impact_fx.to_local(hit)).is_equal_approx(hit))
	facing.rotation = before_rotation
	assert(boss.health == hp - int(should_hurt))
	print("RAY_PASS first=%s world=%s beam=%s core=%s damage=%s" % [
		expected.name, hit, gun.beam.to_global(gun.beam.points[-1]), gun.beam_core.to_global(gun.beam_core.points[-1]), hp - boss.health])
	if not shot_file.is_empty():
		await capture(shot_file)
	else:
		await frames(1)
	for i in range(5):
		await physics_frame
		gun.advance_time(1.0 / 60.0, from, direction)
	assert(boss.health == hp - int(should_hurt))
	gun.cancel()

func verify_sweep(boss: BOSS) -> void:
	var player: CharacterBody2D = room.player
	var home := Vector2(774, 476)
	var full: int = player.max_health
	player.restore_player(home + Vector2(49, 44), full, ["pulse_gun"])
	boss.set_physics_process(true)
	boss.global_position = home
	boss._switch(BOSS.Phase.STALK, 0.0)
	assert(await until(func(): return boss.phase == BOSS.Phase.SWEEP))
	var facing := boss.locked
	assert(await until(func(): return boss.action_frame == 2))
	assert(boss.sweep_visual.frame_index == 0 and player.health == full)
	var t := boss.sweep_clock
	paused = true
	await frames(8)
	assert(is_equal_approx(t, boss.sweep_clock) and boss.sweep_visual.frame_index == 0)
	paused = false
	assert(await until(func(): return boss.action_frame == 3))
	assert(boss.sweep_struck and boss.sweep_visual.frame_index == 3)
	assert(player.health == full - BOSS.SWEEP_DAMAGE and boss.locked == facing)
	boss.set_physics_process(false)
	await capture("05-sweep-contact-04.png")
	boss.set_physics_process(true)
	player.invulnerability_remaining = 0.0
	await frames(20)
	assert(player.health == full - BOSS.SWEEP_DAMAGE)

	player.restore_player(home + Vector2(49, 44), full, ["pulse_gun"])
	boss.sweep_cooldown = 0.0
	boss._switch(BOSS.Phase.STALK, 0.0)
	assert(await until(func(): return boss.phase == BOSS.Phase.SWEEP and boss.action_frame == 1))
	assert(player.move_and_collide(Vector2(57, -30)) == null)
	assert(await until(func(): return boss.sweep_struck))
	assert(player.health == full, "A sidestep beyond the sector should escape.")

	player.restore_player(home + Vector2(62, 0), full, ["pulse_gun"])
	boss.sweep_cooldown = 0.0
	boss._switch(BOSS.Phase.STALK, 0.0)
	assert(await until(func(): return boss.phase == BOSS.Phase.SWEEP and boss.action_frame == 1))
	var blocker := obstacle(home + Vector2(44, 0), Vector2(6, 90))
	await frames(3)
	assert(boss.sweep_limits[BOSS.SWEEP_SLICES / 2] < 42.0)
	assert(await until(func(): return boss.sweep_struck))
	assert(player.health == full and not boss._sweep_contains_point(player.global_position))
	boss.set_physics_process(false)
	await capture("06-sweep-wall-cut.png")
	blocker.queue_free()
	boss.set_physics_process(true)
	boss._drop_silk(player.global_position)
	await frames(2)
	assert(player.web_speed_factor < 1.0 and not boss.bound)
	player.apply_damage(full)
	assert(paused and boss.sweep_visual.frame_index == -1 and boss.leftover_silk.is_empty() and not boss.held)
	var retry: Button = room.game_menus.find_children("*", "Button", true, false).filter(func(button: Button): return button.text == "重试")[0]
	retry.pressed.emit()
	assert(not paused and not is_instance_valid(room.boss) and room.player.controls_enabled)
	print("SWEEP_PASS: action 04 == PixelFX 04 == one damage; pause, sidestep, clipped shutter, independent silk, death and menu retry clean-up")

func verify_pressure(boss: BOSS) -> void:
	var player: CharacterBody2D = room.player
	var home := Vector2(774, 476)
	boss.set_physics_process(true)
	var close_spot := home + Vector2(0, 27)
	player.global_position = close_spot
	boss.global_position = home
	boss._switch(BOSS.Phase.RECOVER, 0.15)
	assert(await until(func(): return boss.phase == BOSS.Phase.PINCH, 25))
	assert(boss.global_position.is_equal_approx(home), "An exposed target inside short pinch reach doesn't need a retreat.")
	assert(player.health == player.max_health)
	print("PRESSURE_PASS close-range pinch before repositioning")

	player.global_position = Vector2(915, 515)
	boss.global_position = home
	boss.web_cooldown = 3.0
	boss._switch(BOSS.Phase.RECOVER, 0.15)
	assert(await until(func(): return boss.global_position.distance_to(home) >= 8.0, 35))
	assert(boss.phase == BOSS.Phase.STALK, "Web cooldown must not freeze regular pursuit.")
	print("PRESSURE_PASS cooldown pursuit before 0.5s")
	# Ordinary player poses around the device; the boss continues on the same live map.
	for point in [Vector2(826, 542), Vector2(807, 574), Vector2(647, 586), Vector2(530, 566),
		Vector2(533, 422), Vector2(647, 353), Vector2(733, 393), Vector2(862, 461)]:
		player.global_position = point
		await frames(18)
		assert(boss._chassis_is_clear_at(boss.global_position) and boss._chassis_arena().has_point(boss.global_position))
		if player.health < player.max_health:
			player.restore_player(point, player.max_health, ["pulse_gun"])
	boss._recover(false, 0.0)
	boss.global_position = Vector2(818, 514)
	player.restore_player(Vector2(640, 683), player.max_health, ["pulse_gun"])
	await frames(40)
	assert(boss.phase == BOSS.Phase.STALK and not boss.web_active and not boss.bound and not boss.held)
	assert(boss.global_position.distance_to(home) < Vector2(818, 514).distance_to(home))
	room.camera.global_position = Vector2(630, 1050)
	room.camera.reset_smoothing()
	room.camera.force_update_scroll()
	player.global_position = Vector2(852, 506)
	await frames(32)
	assert(not boss._on_screen() and boss.phase == BOSS.Phase.STALK and not boss.web_active)
	room.camera.global_position = Vector2(764, 479)
	room.camera.reset_smoothing()
	room.camera.force_update_scroll()
	print("PRESSURE_PASS route around device, leaves arena -> guard instead of offscreen fire")
	boss.global_position = Vector2(525, 485)
	player.global_position = Vector2(640, 683)
	await frames(2)
	assert(not boss._can_step(boss.global_position, home))
	assert(await until(func(): return boss.global_position.distance_to(home) <= 8.0, 490), "A retreat blocked by the machine must go around it.")
	assert(boss.phase == BOSS.Phase.STALK and not boss.web_active)
	print("GUARD_PASS: returned around the device from the west side without attacking")

func capture_sweep_sequence(boss: BOSS) -> void:
	if capture_dir.is_empty():
		return
	var player: CharacterBody2D = room.player
	boss.set_physics_process(false)
	room.set_combat_debug(false)
	boss.global_position = Vector2(774, 439)
	player.restore_player(boss.global_position + Vector2(46, 46), player.max_health, ["pulse_gun"])
	await frames(2)
	boss._begin_sweep()
	for frame in range(33):
		await capture("sweep-sequence/frame-%03d.png" % frame)
		if frame == 9:
			await capture("08-wide-telegraph.png")
		await physics_frame
		boss._physics_process(1.0 / 60.0)
		boss._physics_process(1.0 / 60.0)
	player.restore_player(boss.global_position + Vector2(35, 33), player.max_health, ["pulse_gun"])
	boss._lock_at_player()
	boss._begin_action(BOSS.Phase.PINCH, BOSS.PINCH_TIME[0])
	for tick in range(15):
		await physics_frame
		boss._physics_process(1.0 / 60.0)
	assert(boss.action_frame == 1)
	await capture("09-short-telegraph.png")
	player.restore_player(player.global_position, player.max_health, ["pulse_gun"])
	room.set_combat_debug(true)

func run() -> void:
	room = SCENE.instantiate()
	root.add_child(room)
	current_scene = room
	while not room.prototype_ready:
		await process_frame
	room.player.set_physics_process(false)
	room.player.global_position = Vector2(852, 551)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.pressed = true
	room._input(key)
	var boss: BOSS = room.boss
	await frames(105)
	assert(boss.phase != BOSS.Phase.ASSEMBLE)
	boss.set_physics_process(false)
	room.set_physics_process(false)
	boss.global_position = Vector2(774, 476)
	boss._switch(BOSS.Phase.RECOVER, 2.0)
	boss._set_facing(Vector2.RIGHT)
	boss._update_frame()
	room.camera.global_position = Vector2(764, 479)
	room.camera.reset_smoothing()
	await frames(2)
	await capture("02-scale-85.png")
	if "--scale-only" in OS.get_cmdline_user_args():
		room.queue_free()
		await process_frame
		quit()
		return
	room.set_combat_debug(true)
	var gun: PULSE = room.player.pulse_gun
	gun.use_muzzle = false
	gun.visible = true
	gun.configure_space(gun.map_bounds, Callable())
	var space := boss.get_world_2d().direct_space_state
	var device_hit := PULSE.trace_contact(space, Vector2(894, 474), Vector2(624, 474))
	assert(not device_hit.is_empty() and device_hit.collider.get_parent().name == "ExitMachine")
	await fire(boss, Vector2(896, 480), Vector2(776, 445), boss.metal, true, "03-lower-metal-beam.png")
	await fire(boss, Vector2(906, 425), Vector2(763, 425), boss.armor, true)
	await fire(boss, Vector2(774, 565), Vector2(774, 423), boss.metal, true)
	await fire(boss, Vector2(894, 474), Vector2(624, 474), device_hit.collider, false, "04-gap-to-machine.png")
	var wall := obstacle(Vector2(835, 448), Vector2(8, 92))
	await frames(2)
	await fire(boss, Vector2(896, 480), Vector2(776, 445), wall, false)
	wall.queue_free()
	await frames(2)
	for pose: int in [4, 7, 11]:
		boss._set_pose(pose)
		await frames(2)
		var lower := boss.global_position + Vector2(0, -35) * boss.visual_scale
		var hit := PULSE.trace_contact(space, lower + Vector2(0, 100), lower - Vector2(0, 12))
		assert(hit.get("collider") == boss.metal, "Pose %d should expose the low metal, got %s" % [pose, hit])
	boss._set_pose(2)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("sweep-sequence"))
	await capture_sweep_sequence(boss)
	await verify_pressure(boss)
	await verify_sweep(boss)
	paused = false
	room.queue_free()
	await process_frame
	print("BOSS_TUNING_PASS")
	quit()
