extends "res://tests/manual/b_combat/parallel_cleaner/throw_check.gd"

const OPEN := Vector2(785, 463)
const AIM := Vector2(49, 44)
const CAPTIONS := {
	"01-hit": "SWEEP / CONTACT",
	"02-dodge": "SWEEP / SIDESTEP",
	"03-wall": "SWEEP / WALL CLIP",
	"04-pressure": "OVERPRESSURE / PURSUIT",
}
var passed := 0

func tick(boss: BOSS) -> void:
	await physics_frame
	room.player._physics_process(STEP)
	boss._physics_process(STEP)
	room._process(STEP)

func record(name: String, step: int) -> void:
	if not capture_dir.is_empty():
		await capture("%s/frame-%04d.png" % [name, step])

func sweep_case(boss: BOSS, name: String, at: Vector2, aim: Vector2, dodge: bool, clipped: bool) -> void:
	await stage(boss, at, aim, CAPTIONS[name])
	boss.health = BOSS.MAX_HP
	boss._begin_sweep()
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join(name))
	var full: int = room.player.max_health
	var expected_hp := full if dodge else full - BOSS.SWEEP_DAMAGE
	var contact := false
	var held_ticks := 0
	var hang_ticks := 0
	var displaced := false
	var move_start := Vector2.ZERO
	var contact_clock := 0.0
	var contact_impact := 0.0
	var contact_pose: Texture2D
	var base_speed := boss._chase_speed()
	for step in range(75):
		if dodge and step == 6:
			Input.action_press(&"move_down")
		elif dodge and step == 31:
			Input.action_release(&"move_down")
		var before: float = boss.encounter_time
		await tick(boss)
		assert(boss.encounter_time > before)
		if not contact and boss.sweep_struck:
			contact = true
			assert(boss.action_frame == 3 and boss.sweep_visual.frame_index == 3)
			assert(boss.sweep_visual.mirror == (aim.x < 0.0))
			assert(room.player.health == expected_hp)
			assert(boss.sweep_visual.limits == boss.sweep_limits)
			assert(not clipped or Array(boss.sweep_limits).min() < BOSS.SWEEP_REACH - 10.0)
			assert(is_zero_approx(boss.sweep_hitstop) if dodge else absf(boss.sweep_hitstop - 0.067) < 0.001)
			contact_clock = boss.sweep_clock
			contact_impact = boss.impact_left
			contact_pose = boss.body_sprite.texture
			move_start = room.player.global_position
			if not dodge and not clipped:
				Input.action_press(&"move_right")
			if not capture_dir.is_empty():
				await capture(name + "-contact.png")
		elif contact and boss.sweep_hitstop > 0.0:
			held_ticks += 1
			assert(boss.sweep_clock == contact_clock and boss.impact_left == contact_impact)
			assert(boss.body_sprite.texture == contact_pose and boss.sweep_visual.frame_index == 3)
			assert(room.player.facing.modulate == BOSS.SWEEP_HIT_TINT)
		elif contact:
			Input.action_release(&"move_right")
		if boss.sweep_visual.frame_index in [3, 4, 5]:
			hang_ticks += 1
		if boss.sweep_visual.distortion.visible and boss.sweep_visual.frame_index == 4 and not displaced:
			displaced = true
			if not capture_dir.is_empty():
				await capture(name + "-distorted.png")
				boss.sweep_visual.distortion.hide()
				await capture(name + "-flat.png")
				boss.sweep_visual.distortion.show()
		if contact:
			assert(room.player.health == expected_hp, "The rift must not deal damage after the contact event.")
		if boss.pressure_left > 0.0:
			assert(boss.phase == BOSS.Phase.RECOVER and boss.pressure_lights.visible and boss.sweep_visual.frame_index == -1)
			assert(is_equal_approx(boss.pressure_left, BOSS.PRESSURE_TIME))
			assert(is_equal_approx(boss._chase_speed(), base_speed * BOSS.PRESSURE_MOVE_MULT))
			await record(name, step)
			break
		await record(name, step)
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	assert(contact and displaced and hang_ticks >= 4 and boss.pressure_left > 0.0)
	if not clipped and not dodge:
		assert(held_ticks >= 3 and room.player.global_position.x > move_start.x + 1.0)
	print("RIFT_CASE_PASS %s hold_ticks=%d hp=%d mask=%s pressure=%.2f" % [
		name, held_ticks, room.player.health, displaced, boss.pressure_left])
	passed += 1

func verify_widened_sector(boss: BOSS) -> void:
	for side in [-1.0, 1.0]:
		await stage(boss, OPEN, Vector2.DOWN * 62.0, "")
		boss._begin_sweep()
		assert(is_equal_approx(BOSS.SWEEP_HALF, PI * 0.5))
		var inside := OPEN + Vector2.DOWN.rotated(side * deg_to_rad(82.0)) * 96.0
		var outside := OPEN + Vector2.DOWN.rotated(side * deg_to_rad(94.0)) * 62.0
		assert(BOSS.SWEEP_REACH == 100.0 and boss._sweep_contains_point(inside))
		assert(not boss._sweep_contains_point(outside))
		assert(not boss._sweep_contains_point(OPEN + Vector2.DOWN * 103.0))
		room.player.global_position = inside
		var full: int = room.player.health
		for step in range(50):
			await tick(boss)
			if boss.sweep_struck:
				break
		assert(boss.sweep_struck and room.player.health == full - BOSS.SWEEP_DAMAGE)
		var visual := boss.sweep_visual
		assert(is_equal_approx(visual.half_angle, BOSS.SWEEP_HALF) and visual.radius == 100.0)
		var rect := visual.frames[visual.frame_index]
		var atlas_size := Vector2(visual.atlas.get_size())
		var sampled := visual._uv(side * BOSS.SWEEP_HALF, BOSS.SWEEP_REACH, rect, atlas_size)
		var source := Vector2.DOWN.rotated(side * visual.source_half_angle) * visual.source_radius
		if visual.mirror:
			source.x = -source.x
		assert((sampled * atlas_size - rect.position - visual.pivot).is_equal_approx(source))
	print("RIFT_WIDE_PASS: both 82-degree edges hit from 96 units, 94 degrees and 103 units excluded, visual radius 100")


func pressure_chase(boss: BOSS) -> void:
	var name := "04-pressure"
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join(name))
	room._show_notification(CAPTIONS[name], 5.0)
	room.player.restore_player(boss.global_position + Vector2(165, -20), room.player.max_health, ["pulse_gun"])
	boss.web_cooldown = 8.0
	var start := boss.global_position
	for step in range(40):
		await tick(boss)
		assert(boss.pressure_lights.visible and is_equal_approx(boss._melee_pace(), 1.18))
		await record(name, step)
	var moved := start.distance_to(boss.global_position)
	assert(moved > 60.0 and boss.pressure_left > 2.0)

	# A contact against active invulnerability must refresh pressure without a hit stop.
	var invulnerable: Vector2 = boss.global_position + AIM
	room.player.restore_player(invulnerable, room.player.max_health, ["pulse_gun"])
	room.player.invulnerability_remaining = 2.0
	boss._begin_sweep()
	assert(is_equal_approx(boss.attack_pace, 1.18))
	var refreshed := false
	for step in range(70):
		await tick(boss)
		assert(boss.sweep_hitstop == 0.0 and room.player.health == room.player.max_health)
		if is_equal_approx(boss.pressure_left, BOSS.PRESSURE_TIME):
			assert(boss.sweep_struck and is_equal_approx(boss._melee_pace(), 1.18))
			refreshed = true
			break
	assert(refreshed)

	boss.health = BOSS.RAGE_HP
	boss._begin_slam()
	assert(is_equal_approx(boss.attack_pace, 1.35) and is_equal_approx(boss.slam_warning_pace, BOSS.RAGE_ATTACK_PACE))
	boss._begin_sweep()
	assert(is_equal_approx(boss.attack_pace, 1.35))
	boss.pressure_left = 0.001
	await tick(boss)
	assert(boss.pressure_left == 0.0 and not boss.pressure_lights.visible and is_equal_approx(boss.attack_pace, 1.35))
	boss.apply_damage(boss.health)
	assert(boss.sweep_hitstop == 0.0 and not boss.sweep_visual.distortion.visible and not boss.pressure_lights.visible)
	print("RIFT_PRESSURE_PASS chase=%.1fu, attack cap 1.35, heavy tell preserved, snapshot on expiry, death cleanup" % moved)
	passed += 1

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
	await sweep_case(boss, "01-hit", OPEN, AIM, false, false)
	await sweep_case(boss, "02-dodge", Vector2(510, 470), Vector2(-49, 44), true, false)
	await sweep_case(boss, "03-wall", Vector2(790, 567), Vector2(39, 50), false, true)
	await verify_widened_sector(boss)
	# Record movement on the open right side without crossing the bottom chamfer.
	await stage(boss, OPEN, AIM, "")
	boss._begin_sweep()
	while boss.pressure_left <= 0.0:
		await tick(boss)
	await pressure_chase(boss)
	press(KEY_R)
	assert(not is_instance_valid(room.boss))
	room.queue_free()
	await process_frame
	assert(passed == 4)
	print("RIFT_SWEEP_PASS")
	quit()
