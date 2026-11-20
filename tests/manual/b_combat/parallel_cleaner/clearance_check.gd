extends "res://tests/manual/b_combat/parallel_cleaner/throw_check.gd"
## Runs the actual F6 room and optionally captures two 60 FPS playthroughs.
const MOVE := preload("res://scenes/enemies/parallel_cleaner/clearance.gd")
const GEO := MOVE.GEO
const HOME := Vector2(774, 476)
const OPEN := Vector2(774, 467)
var watched_id := 0
var cuts: Array[StringName] = []
var impulses: Array[Vector2] = []
var cut_frames: Dictionary = {}

func watch(boss: BOSS) -> void:
	if watched_id != boss.get_instance_id():
		watched_id = boss.get_instance_id()
		boss.clearance.event_reached.connect(func(event: StringName):
			cuts.append(event)
			cut_frames[event] = [boss.clearance.clock, boss.clearance.pose_index(), boss.clearance.quake_index(), boss.clearance.foot()]
		)
		boss.clearance.shake_requested.connect(func(offsets: PackedVector2Array):
			if not offsets.is_empty():
				impulses.append(offsets[0])
		)
	cuts.clear()
	impulses.clear()
	cut_frames.clear()

func tick(boss: BOSS) -> void:
	await physics_frame
	boss._physics_process(STEP)
	room._process(STEP)

func wait_for(boss: BOSS, finished: Callable, limit := 240) -> bool:
	for i in range(limit):
		if finished.call():
			return true
		await tick(boss)
	return finished.call()

func trigger(boss: BOSS) -> void:
	boss.health = BOSS.RAGE_HP + 1
	boss._switch(BOSS.Phase.STALK, 0.0)
	boss.take_pulse_hit(1, room.player)
	assert(boss.clearance_pending and not boss.clearance_used)
	await tick(boss)
	assert(boss.phase == BOSS.Phase.CLEARANCE and boss.clearance.active and boss.clearance_used)

func position_for(boss: BOSS, radius: float) -> Vector2:
	var special := boss.clearance
	for slice in range(0, 24):
		var point := GEO.point_at(special.origin, slice * TAU / 24.0, radius)
		if special._floor_covers(point) and boss._line_clear(special.origin, point) and not GEO.in_gap(special.origin, point, special.gap_angle):
			return point
	return Vector2.INF

func verify_queue(boss: BOSS) -> void:
	await stage(boss, HOME, Vector2(26, 190), "")
	boss.health = 13
	boss.web_cooldown = 2.0
	boss._switch(BOSS.Phase.STALK, 0.0)
	boss.take_pulse_hit(1, room.player)
	assert(boss.health == 12 and not boss.clearance_pending)
	boss.take_pulse_hit(3, room.player)
	assert(boss.health == 9 and boss.clearance_pending)
	await tick(boss)
	assert(boss.clearance_pending and not boss.clearance.active and not boss._in_arena(room.player.global_position))
	room.player.global_position = HOME + Vector2(115, 70)
	room.player.controls_enabled = false
	await tick(boss)
	assert(boss.clearance_pending and not boss.clearance.active)
	room.player.controls_enabled = true
	await tick(boss)
	assert(boss.clearance.active)
	print("CLEARANCE_QUEUE: multi-hit threshold crossing, waits outside ExitCombat and for restored control")

	await stage(boss, Vector2(435, 586), Vector2(255, 0), "")
	boss.health = 11
	boss.web_cooldown = 0.0
	assert(boss._try_fire_web(false))
	boss.take_pulse_hit(1, room.player)
	await tick(boss)
	assert(boss.clearance_pending and boss.phase == BOSS.Phase.WEB_SHOT)
	assert(await wait_for(boss, func(): return boss.phase == BOSS.Phase.REEL))
	assert(boss.clearance_pending and boss.bound and not boss.clearance.active)
	assert(await wait_for(boss, func(): return boss.phase == BOSS.Phase.CLEARANCE))
	assert(not boss.bound and room.player.controls_enabled)
	print("CLEARANCE_WEB: queued during flight, completed the tether before starting")

	await stage(boss, HOME, Vector2(70, 8), "")
	boss.health = 11
	boss._begin_grab_warning()
	assert(await wait_for(boss, func(): return boss.phase == BOSS.Phase.LIFT))
	boss.take_pulse_hit(1, room.player)
	await tick(boss)
	assert(boss.clearance_pending and boss.held and not room.player.controls_enabled)
	assert(await wait_for(boss, func(): return boss.phase == BOSS.Phase.THROW))
	assert(not boss.clearance.active)
	assert(await wait_for(boss, func(): return boss.clearance.active))
	assert(room.player.controls_enabled and not boss.held)
	print("CLEARANCE_GRAB: queued during lift, full throw and recovery before starting")

func make_safe(boss: BOSS) -> void:
	var special := boss.clearance
	var player: CharacterBody2D = room.player
	var motion := (special.gap_entry - player.global_position).limit_length(player.move_speed * player.web_movement_factor() * STEP)
	if not motion.is_zero_approx():
		assert(player.move_and_collide(motion) == null)

func verify_hit(boss: BOSS, expected: StringName, invulnerable_first := false) -> void:
	await stage(boss, OPEN, Vector2(124, 55), "")
	watch(boss)
	await trigger(boss)
	var special := boss.clearance
	var player: CharacterBody2D = room.player
	var near := position_for(boss, 145.0)
	var outer := position_for(boss, 292.0)
	assert(near.is_finite() and outer.is_finite(), "Need clear test points in each newly covered band.")
	var full: int = player.health
	var stops := 0
	var hit_clock := -1.0
	var held_ticks := 0
	var moved_during_hold := false
	var start_radius := 0.0
	var finisher_edge := Vector2.INF
	for frame in range(205):
		var before := special.clock
		var held_before := special.hitstop
		var body_before := special.pose_index()
		var quake_before := special.quake_index()
		var impact_age: float = boss.ground_visual.impact.get("age", -1.0)
		if not boss.clearance.active:
			break
		if expected == &"ground_contact" and before < 1.82:
			player.global_position = special.gap_entry
		elif before >= 1.82:
			if not finisher_edge.is_finite():
				for direction in range(16):
					var point := special.finisher_at + Vector2.from_angle(direction * TAU / 16.0) * 72.0
					if special._finisher_contains(point):
						finisher_edge = point
						break
				assert(finisher_edge.is_finite(), "Need a clear point inside the new finisher radius.")
			player.global_position = finisher_edge
		elif before >= 1.32 and expected != &"ground_contact":
			player.global_position = outer
		elif before >= 0.4:
			player.global_position = near if (expected == &"inner_sweep_contact" or invulnerable_first) else outer
		if invulnerable_first:
			player.invulnerability_remaining = 0.5 if before < 1.31 else 0.0
		if is_equal_approx(before, 0.95):
			start_radius = ((player.global_position - special.origin) / GEO.PLANE).length()
		if held_before >= STEP and expected == &"inner_sweep_contact" and not moved_during_hold:
			var from := player.global_position
			Input.action_press(&"move_down")
			player._physics_process(STEP)
			Input.action_release(&"move_down")
			moved_during_hold = player.global_position.distance_to(from) > 0.5
		var encounter_before := boss.encounter_time
		await tick(boss)
		assert(boss.encounter_time > encounter_before)
		if special.hitstop > 0.0 and held_before <= 0.0:
			stops += 1
			hit_clock = special.clock
			assert(special.confirmed_hit == expected and absf(special.hitstop - 0.067) < 0.001)
			assert(player.health == full - room.clearance_damage)
		elif special.active and held_before >= STEP:
			held_ticks += 1
			assert(special.clock == before and special.pose_index() == body_before and special.quake_index() == quake_before)
			assert(is_equal_approx(float(boss.ground_visual.impact.get("age", -1.0)), impact_age))
		if stops > 0:
			assert(player.health == full - room.clearance_damage)
		else:
			assert(player.health == full)
	assert(stops == 1 and held_ticks >= 3 and not special.active)
	assert(cuts.count(&"inner_sweep_contact") == 1 and cuts.count(&"outer_sweep_contact") == 1 and cuts.count(&"ground_contact") == 1)
	assert(impulses.size() == 3 and impulses[0] == Vector2(0, -2) and impulses[1] == Vector2(-4, 5))
	assert(absf(float(cut_frames[&"inner_sweep_contact"][0]) - 1.0) <= STEP + MOVE.EPS and cut_frames[&"inner_sweep_contact"][2] == 6)
	assert(absf(float(cut_frames[&"outer_sweep_contact"][0]) - 1.35) <= STEP + MOVE.EPS and cut_frames[&"outer_sweep_contact"][2] == 27)
	assert(absf(float(cut_frames[&"ground_contact"][0]) - 2.0) <= STEP + MOVE.EPS and cut_frames[&"ground_contact"][1] == 3)
	if expected == &"inner_sweep_contact":
		assert(start_radius > 137.5 and hit_clock > 1.0 and hit_clock < 1.30 and moved_during_hold)
	elif expected == &"outer_sweep_contact":
		assert(hit_clock > 1.35 and hit_clock < 1.80)
	else:
		assert(is_equal_approx(hit_clock, 2.0) and is_equal_approx(finisher_edge.distance_to(special.finisher_at), 72.0))
	assert(room.camera.offset == room.shake_base and boss.phase == BOSS.Phase.STALK)
	boss.take_pulse_hit(1, player)
	assert(not boss.clearance_pending and boss.clearance_used)
	print("CLEARANCE_HIT %s at %.3fs held=%d invulnerable_inner=%s" % [expected, hit_clock, held_ticks, invulnerable_first])

func verify_wall_penetration(boss: BOSS, expected: StringName) -> void:
	await stage(boss, OPEN, Vector2(0, 120), "")
	boss.face_right = true
	var shutter := obstacle(OPEN + Vector2(48, 0), Vector2(6, 122))
	await frames(2)
	await trigger(boss)
	var player: CharacterBody2D = room.player
	var special := boss.clearance
	var point := OPEN + Vector2(158, 3) if expected == &"outer_sweep_contact" else OPEN + Vector2(77, 3)
	assert(not GEO.in_gap(OPEN, point, special.gap_angle))
	assert(not boss._line_clear(OPEN, point) and special._floor_covers(point))
	assert(not special._floor_covers(OPEN + Vector2(252, 0)))
	if expected == &"ground_contact":
		player.global_position = special.gap_entry
		assert(await wait_for(boss, func(): return special.clock > 1.82))
		assert(not boss._line_clear(special.finisher_at, point) and special._finisher_contains(point))
	player.global_position = point
	assert(await wait_for(boss, func(): return special.confirmed_hit != &""))
	assert(special.confirmed_hit == expected and player.health == player.max_health - room.clearance_damage)
	shutter.queue_free()
	await frames(2)
	print("CLEARANCE_WALL_PASS: %s hit through a solid shutter" % expected)

func verify_random_gap(boss: BOSS) -> void:
	var angles := {}
	var side := 0
	var rear := 0
	for offset in [Vector2(124, 55), Vector2(-78, 38)]:
		angles.clear()
		for attempt in range(12):
			await stage(boss, OPEN, offset, "")
			boss.face_right = true
			await trigger(boss)
			var special := boss.clearance
			var player: CharacterBody2D = room.player
			var step := special.gap_entry - player.global_position
			assert(boss._in_arena(special.gap_entry) and GEO.in_gap(OPEN, special.gap_entry, special.gap_angle))
			assert(step.length() <= player.move_speed * (MOVE.INNER_TIME - MOVE.REACTION_MARGIN))
			assert(not player.test_move(player.global_transform, step))
			assert(special.face_right)
			var separation := absf(wrapf(special.gap_angle, -PI, PI))
			assert(separation >= GEO.FRONT_HALF, "An accessible side or rear must outrank the frontal sector.")
			if separation >= deg_to_rad(120.0):
				rear += 1
			else:
				side += 1
			var selected := special.gap_angle
			angles[roundi(selected / GEO.STEP)] = true
			await tick(boss)
			assert(special.gap_angle == selected)
		assert(angles.size() >= 2, "Repeated casts should vary the gap from the same starting position.")
	assert(side > 0 and rear > 0)
	var start: Vector2 = room.player.global_position
	var fallback := GEO.path_to_gap(room.player, OPEN, boss.arena, 0.0, true)
	assert(fallback.entry.is_equal_approx(start) and GEO.in_gap(OPEN, start, fallback.angle))
	print("CLEARANCE_RANDOM_GAP_PASS: %d side and %d rear placements in 24 reachable casts" % [side, rear])

func verify_full_room(boss: BOSS) -> void:
	await stage(boss, OPEN, Vector2(124, 55), "")
	await trigger(boss)
	var special := boss.clearance
	var gap := special.gap_angle
	assert(is_equal_approx(rad_to_deg(GEO.GAP_HALF) * 2.0, 20.0))
	for sign in [-1.0, 1.0]:
		assert(GEO.in_gap(OPEN, GEO.point_at(OPEN, gap + deg_to_rad(9.5) * sign, 90.0), gap))
		assert(not GEO.in_gap(OPEN, GEO.point_at(OPEN, gap + deg_to_rad(10.5) * sign, 90.0), gap))
	assert(special.wave_slices.filter(func(slice: Dictionary): return slice.safe).size() == 8)
	assert(is_equal_approx(GEO.atlas_quake_radius(150.0, special.outer_radius), GEO.ATLAS_INNER_RADIUS))
	assert(is_equal_approx(GEO.atlas_quake_radius(special.outer_radius, special.outer_radius), GEO.ATLAS_OUTER_RADIUS))
	for corner in GEO.arena_corners(special.arena.grow(-1.0)):
		assert(special._floor_covers(corner))
		assert(GEO.atlas_quake_radius(((corner - OPEN) / GEO.PLANE).length(), special.outer_radius) < GEO.ATLAS_OUTER_RADIUS)
	var mesh_area := 0.0
	for slice in special.wave_slices:
		for polygon: PackedVector2Array in [slice.near, slice.far]:
			var twice_area := 0.0
			for i in range(polygon.size()):
				var a := polygon[i]
				var b := polygon[(i + 1) % polygon.size()]
				twice_area += a.cross(b)
				assert(special.arena.grow(0.01).has_point(a + OPEN))
			mesh_area += absf(twice_area) * 0.5
	assert(absf(mesh_area - special.arena.get_area()) < 5.0)
	var far_floor := Vector2(435, 586)
	assert(((far_floor - OPEN) / GEO.PLANE).length() > 370.0)
	assert(not GEO.in_gap(OPEN, far_floor, gap))
	room.player.global_position = far_floor
	assert(await wait_for(boss, func(): return special.confirmed_hit != &""))
	assert(special.confirmed_hit == &"outer_sweep_contact")
	assert(room.player.health == room.player.max_health - room.clearance_damage)
	assert(not special._floor_covers(Vector2(435, 641)))
	print("CLEARANCE_FULL_ROOM_PASS: 20-degree gap, warning mesh covers all four ExitCombat corners, outer wave hit beyond 370 units; hallway excluded")

func verify_radial_retreat(boss: BOSS) -> void:
	await stage(boss, HOME, Vector2(133, -58), "")
	await trigger(boss)
	var player: CharacterBody2D = room.player
	var special := boss.clearance
	var start := player.global_position
	var radial := (start - HOME) / GEO.PLANE
	var destination := GEO.point_at(HOME, radial.angle(), 184.0)
	assert(not GEO.in_gap(HOME, start, special.gap_angle) and not GEO.in_gap(HOME, destination, special.gap_angle))
	for i in range(40):
		var step := (destination - player.global_position).limit_length(player.move_speed * player.web_movement_factor() * STEP)
		if not step.is_zero_approx():
			assert(player.move_and_collide(step) == null)
		await tick(boss)
	assert(player.global_position.is_equal_approx(destination) and player.health == player.max_health)
	assert(await wait_for(boss, func(): return special.confirmed_hit != &""))
	assert(special.confirmed_hit == &"outer_sweep_contact")
	assert(player.health == player.max_health - room.clearance_damage)
	print("CLEARANCE_RADIAL: outward walking escaped the inner ring, then crossed the live outer front")


func capture_step(name: String, frame: int) -> void:
	if not capture_dir.is_empty():
		await capture("%s/frame-%04d.png" % [name, frame])

func dodge(boss: BOSS, start: Vector2, offset: Vector2, silk: bool, expected_right: bool, clip := "") -> void:
	await stage(boss, start, offset, "CLEARANCE PROTOCOL" if not clip.is_empty() else "")
	boss.face_right = expected_right
	var player: CharacterBody2D = room.player
	if silk:
		for i in range(4):
			boss._drop_silk(player.global_position)
		boss._update_ground_silk(0.0)
		assert(is_equal_approx(player.web_movement_factor(), 0.20))
	if not clip.is_empty() and not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join(clip))
	watch(boss)
	if not clip.is_empty():
		seed(4217)
	await trigger(boss)
	var special := boss.clearance
	var planted := boss.global_position
	var gap := special.gap_angle
	assert(boss._in_arena(special.gap_entry) and GEO.in_gap(planted, special.gap_entry, gap))
	if not clip.is_empty():
		assert(special.face_right == expected_right)
		assert(special.silk_spots.size() == 2)
	var expected_foot := Vector2(100, 122) if special.face_right else Vector2(124, 122)
	var expected_tip := planted + Vector2(70.0 if special.face_right else -70.0, 13.0) * boss.visual_scale
	assert(special.finisher_nominal.is_equal_approx(expected_tip))
	var gun: PULSE = player.pulse_gun
	var aim := Vector2.ZERO
	var charged := false
	var counter_at := -1.0
	var boss_hp := boss.health
	var full: int = player.health
	var recovered := false
	var frame := 0
	for i in range(163):
		if i > 6:
			make_safe(boss)
		if not clip.is_empty() and special.clock >= 1.67 and not charged:
			aim = player.global_position.direction_to(boss.armor.global_position)
			player.aim_at(boss.armor.global_position)
			assert(gun.request_fire(aim))
			charged = true
		await tick(boss)
		if charged:
			gun.advance_time(STEP, player.global_position, aim)
			if counter_at < 0.0 and boss.health < boss_hp:
				counter_at = special.clock
		if not clip.is_empty():
			await capture_step(clip, frame)
			frame += 1
		assert(player.health == full and boss.global_position == planted and not boss.bound)
		if special.clock >= 0.96 and special.active:
			assert(GEO.in_gap(planted, player.global_position, gap), "Player did not reach the gap from %s" % (start + offset))
		if not special.active:
			recovered = true
			break
		var foot := expected_foot + Vector2(0, 46) if special.clock >= special.time_to_finisher else expected_foot
		assert(boss.body_sprite.position.is_equal_approx(-foot * boss.visual_scale))
		assert(special.gap_angle == gap and boss.chassis.disabled == false)
	assert(recovered and impulses.size() == 3 and room.camera.offset == room.shake_base)
	assert(cuts.count(&"inner_sweep_contact") == 1 and cuts.count(&"outer_sweep_contact") == 1 and cuts.count(&"ground_contact") == 1)
	assert(boss.phase == BOSS.Phase.STALK and boss.clearance_used)
	if not clip.is_empty():
		assert(counter_at >= 2.0 and counter_at < 2.62 and boss.health == boss_hp - 1,
			"Counterattack after impact should land during recovery. At %.3f, from %s" % [counter_at, player.global_position])
		for i in range(28):
			await tick(boss)
			gun.advance_time(STEP, player.global_position, aim)
			await capture_step(clip, frame)
			frame += 1
		assert(not boss.clearance_pending)
	print("CLEARANCE_DODGE start=%s gap=%.1f right=%s silk=%s seals=%d counter=%.3fs clip=%s" % [
		start + offset, rad_to_deg(gap), expected_right, silk, boss.leftover_silk.size(), counter_at, clip])


func verify_retry(boss: BOSS, point: StringName) -> void:
	await stage(boss, OPEN, Vector2(120, 54), "")
	await trigger(boss)
	var special := boss.clearance
	if point == &"hold":
		room.player.global_position = position_for(boss, 80.0)
		assert(await wait_for(boss, func(): return special.hitstop > 0.0))
	elif point == &"shake":
		room.player.global_position = special.gap_entry
		assert(await wait_for(boss, func(): return not room.shake_offsets.is_empty()))
		assert(room.camera.offset != room.shake_base)
	else:
		room.player.global_position = special.gap_entry
		assert(await wait_for(boss, func(): return boss.ground_visual.warning))
	assert(not boss.leftover_silk.is_empty())
	press(KEY_R)
	assert(not is_instance_valid(room.boss) and not special.active and special.hitstop == 0.0
		and special.clock == 0.0 and special.quake_index() == -1 and boss.leftover_silk.is_empty())
	assert(room.camera.offset == room.shake_base and room.shake_offsets.is_empty() and room.player.controls_enabled)
	print("CLEARANCE_RETRY %s" % point)

func run() -> void:
	room = SCENE.instantiate()
	root.add_child(room)
	current_scene = room
	while not room.prototype_ready:
		await process_frame
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	assert(MOVE.FINISHER_RADIUS == 80.0)
	var boss := await make_boss()
	room.set_process(false)
	room.set_physics_process(false)
	seed(4217)
	await verify_random_gap(boss)
	await verify_queue(boss)
	await verify_hit(boss, &"inner_sweep_contact")
	await verify_hit(boss, &"outer_sweep_contact", true)
	await verify_hit(boss, &"ground_contact")
	await verify_wall_penetration(boss, &"inner_sweep_contact")
	await verify_wall_penetration(boss, &"outer_sweep_contact")
	await verify_wall_penetration(boss, &"ground_contact")
	await verify_full_room(boss)
	await verify_radial_retreat(boss)
	await dodge(boss, HOME, Vector2(133, -58), false, true, "01-right")
	await dodge(boss, HOME, Vector2(-142, 95), false, false, "02-left")
	await dodge(boss, HOME, Vector2(236, 130), false, true)
	await dodge(boss, HOME, Vector2(241, -38), false, true)
	await dodge(boss, HOME, Vector2(-82, 68), false, false)
	await dodge(boss, HOME, Vector2(108, 54), true, true)
	await verify_retry(boss, &"warning")
	boss = await make_boss()
	await verify_retry(boss, &"shake")
	boss = await make_boss()
	await verify_retry(boss, &"hold")
	boss = await make_boss()
	boss.health = 11
	boss.take_pulse_hit(11, room.player)
	assert(boss.phase == BOSS.Phase.OFFLINE and not boss.clearance_pending and not boss.clearance_used)
	assert(not boss.clearance.active and boss.leftover_silk.is_empty() and room.camera.offset == room.shake_base)
	print("CLEARANCE_FATAL: threshold kill goes straight to normal shutdown")
	room.queue_free()
	await process_frame
	print("CLEARANCE_PASS")
	quit()
