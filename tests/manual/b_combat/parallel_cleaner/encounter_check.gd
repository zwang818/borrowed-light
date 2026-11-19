extends SceneTree

const SCENE := preload("res://tests/manual/b_combat/parallel_cleaner/abdomen_boss_playtest.tscn")
const ACTOR := preload("res://tests/manual/b_combat/parallel_cleaner/boss.gd")
const MISS := ACTOR.Phase.RECOVER
var level
var capture_dir := OS.get_environment("PARALLEL_CLEANER_CAPTURE")

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func until(predicate: Callable, limit := 200) -> bool:
	for i in range(limit):
		await physics_frame
		if predicate.call():
			return true
	return false

func capture(file: String, centre: Vector2) -> void:
	if capture_dir.is_empty():
		return
	level.set_physics_process(false)
	level.camera.global_position = centre
	level.camera.reset_smoothing()
	level.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(capture_dir.path_join(file)) == OK)
	level.set_physics_process(true)

func obstacle(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collider.shape = rectangle
	body.add_child(collider)
	level.add_child(body)
	return body

func drive_until_blocked(boss: ACTOR, goal: Vector2) -> bool:
	for i in range(115):
		if boss._move_chassis(goal, 150.0, 1.0 / 60.0):
			return true
		await physics_frame
	return false

func press(physical_key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	event.pressed = true
	level._input(event)

func verify_hull_and_flank(boss: ACTOR) -> void:
	var player: CharacterBody2D = level.player
	boss.set_physics_process(false)
	player.global_position = Vector2(831, 493)
	boss.global_position = Vector2(756, 510)
	boss._set_facing(Vector2.LEFT)
	boss._update_frame()
	await frames(2)
	assert(await drive_until_blocked(boss, Vector2(638, 476)), "Machine must stop a diagonal chassis sweep.")
	assert(absf(boss.global_position.x - 672.0 - boss._chassis_half().x) < 1.0)
	assert(boss._chassis_is_clear_at(boss.global_position))
	assert(player.health == player.max_health)
	await capture("01-chassis-blocked.png", Vector2(710, 462))
	var player_contact := player.move_and_collide(player.global_position.direction_to(boss.global_position) * 150.0)
	assert(player_contact != null and player_contact.get_collider() == boss)
	assert(player.health == player.max_health)
	var player_before := player.global_position
	await frames(2)
	assert(await drive_until_blocked(boss, player_before))
	assert(player.global_position == player_before and player.health == player.max_health)
	# Pin the player's feet against the cabinet edge. Contact must not push them.
	boss.global_position = Vector2(768, 492)
	player.global_position = Vector2(683, 492)
	await frames(2)
	assert(await drive_until_blocked(boss, player.global_position))
	assert(player.global_position == Vector2(683, 492) and player.health == player.max_health)

	player.global_position = Vector2(640, 679)
	var initial_arena := boss.arena
	boss.arena = initial_arena.grow(150.0) # Let the sweep reach a real arena wall.
	boss.global_position = Vector2(930, 482)
	await frames(2)
	assert(await drive_until_blocked(boss, Vector2(1080, 482)))
	assert(absf(1024.0 - boss.global_position.x - boss._chassis_half().x) < 1.0)
	var gate: StaticBody2D = level.terminal_gate
	boss.global_position = gate.global_position + Vector2(0, 72)
	await frames(2)
	assert(await drive_until_blocked(boss, gate.global_position - Vector2(0, 35)))
	assert(gate.collision_layer == ACTOR.WORLD and is_equal_approx(boss.global_position.x, gate.global_position.x))
	assert(absf(boss.global_position.y - gate.global_position.y - 8.0 - boss._chassis_half().y) < 1.0)
	boss.arena = initial_arena
	boss.global_position = Vector2(816, 519)
	var slit_a := obstacle(Vector2(773, 566), Vector2(30, 12))
	var slit_b := obstacle(Vector2(859, 566), Vector2(30, 12))
	await frames(2)
	assert(boss._line_clear(boss.global_position, Vector2(816, 603)))
	assert(not boss._can_step(boss.global_position, Vector2(816, 603)))
	assert(await drive_until_blocked(boss, Vector2(816, 603)))
	slit_a.queue_free()
	slit_b.queue_free()

	boss.global_position = Vector2(748, 500)
	player.global_position = Vector2(535, 486)
	var lower_gate := obstacle(Vector2(640, 576), Vector2(218, 12))
	await frames(2)
	var route := boss._route_around_machine(player.global_position)
	assert(Array(route).any(func(point: Vector2): return point.y < boss.machine_bounds.position.y), "Expected upper route, got %s." % [route])
	var upper_gate := obstacle(Vector2(640, 351), Vector2(218, 25))
	await frames(2)
	assert(boss._route_around_machine(player.global_position).is_empty(), "Both blocked paths must be rejected.")
	upper_gate.queue_free()
	await frames(2)
	boss.web_cooldown = 8.0
	boss.route_wait = 0.0
	boss._switch(ACTOR.Phase.STALK, 0.0)
	boss.set_physics_process(true)
	assert(await until(func(): return boss.phase == ACTOR.Phase.FLANK))
	var start := boss.global_position
	assert(await until(func(): return boss.action_frame == 2))
	assert(boss.global_position.is_equal_approx(start), "The first two poses must not translate the actor.")
	var lead := start.direction_to(boss.flank_goal)
	var block := obstacle(start + lead * 31.0, Vector2(70, 14))
	assert(await until(func(): return boss.phase != ACTOR.Phase.FLANK, 7), "A new obstacle must stop the committed step.")
	assert(boss.global_position.distance_to(start) > 2.0 and boss.global_position.distance_to(start) < 14.0)
	assert(boss._chassis_is_clear_at(boss.global_position))
	assert(boss.route_wait > 0.35 and boss.alternate_side == 1, "An interrupted upper flank must pause and try the lower side next.")
	block.queue_free()
	assert(await until(func(): return boss.phase == ACTOR.Phase.FLANK and boss.action_frame == 2))
	start = boss.global_position
	assert(await until(func(): return boss.phase == ACTOR.Phase.FLANK and boss.action_frame == 3))
	assert(boss.global_position.distance_to(start) > 10.0)
	var planted := boss.global_position
	await frames(7)
	assert(boss.global_position == planted)
	assert(await until(func(): return boss.global_position.x < 600.0, 340), "Boss must physically reach the opposite side by the open route.")
	lower_gate.queue_free()
	print("CHASSIS_PASS: fusion clearance, reciprocal solid bodies, machine, wall, closed gate, narrow gap, upper route, both sides blocked, interrupted flank")

func verify_pinch(boss: ACTOR) -> void:
	var player: CharacterBody2D = level.player
	boss.global_position = Vector2(756, 497)
	player.global_position = Vector2(806, 497)
	boss._lock_at_player()
	boss._begin_action(ACTOR.Phase.PINCH, ACTOR.PINCH_TIME[0])
	var full: int = player.max_health
	assert(await until(func(): return boss.phase == ACTOR.Phase.PINCH and boss.action_frame == 1))
	assert(player.health == full)
	await frames(7)
	boss.set_physics_process(false)
	await capture("02-low-pinch-warning.png", Vector2(784, 460))
	boss.set_physics_process(true)
	assert(await until(func(): return boss.action_frame == 2))
	assert(player.health == full - 1 and not boss.held and player.controls_enabled)
	player.invulnerability_remaining = 0.0
	await frames(10)
	assert(player.health == full - 1)
	player.restore_player(Vector2(806, 497), full, ["pulse_gun"])
	boss._lock_at_player()
	boss._begin_action(ACTOR.Phase.PINCH, ACTOR.PINCH_TIME[0])
	assert(await until(func(): return boss.phase == ACTOR.Phase.PINCH and boss.action_frame == 1))
	var locked := boss.locked
	assert(player.move_and_collide(Vector2(0, 55)) == null)
	assert(await until(func(): return boss.action_frame == 2))
	assert(player.health == full and boss.locked == locked)

	player.global_position = Vector2(806, 497)
	boss._lock_at_player()
	boss._begin_action(ACTOR.Phase.PINCH, ACTOR.PINCH_TIME[0])
	assert(await until(func(): return boss.phase == ACTOR.Phase.PINCH and boss.action_frame == 1))
	var shutter := obstacle(Vector2(795, 497), Vector2(4, 110))
	await frames(2)
	var mouth := boss._pinch_mouth()
	var ray := boss._world_ray(mouth, mouth + boss.locked * ACTOR.PINCH_REACH)
	assert(ray.get("collider") == shutter and not boss._pinch_contains(player.global_position))
	assert(await until(func(): return boss.action_frame == 2))
	assert(player.health == full)
	shutter.queue_free()
	print("PINCH_PASS: isolated legacy move, full warning, one hit, locked dodge, shutter stops preview and damage")

func run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	current_scene = level
	while not level.prototype_ready:
		await process_frame
	level.player.global_position = Vector2(774, 476)
	level.player.set_physics_process(false)
	var first = level.exit_cleaners[0]
	var second = level.exit_cleaners[1]
	assert(level.player.pulse_gun_equipped and level._remaining_cleaners() == 3)
	assert(not level.terminal_gate.get_meta("is_open"))
	first.apply_damage(first.health)
	assert(not is_instance_valid(level.boss) and not level.terminal_gate.get_meta("is_open"))
	second.apply_damage(second.health)
	var boss: ACTOR = level.boss
	assert(is_instance_valid(boss) and boss.phase == ACTOR.Phase.ASSEMBLE)
	assert(boss.collision_layer == 0 and not level.terminal_gate.get_meta("is_open"))
	boss.apply_damage(99)
	assert(boss.health == ACTOR.MAX_HP)
	await frames(90)
	assert(boss.phase == ACTOR.Phase.ASSEMBLE and boss.left == 0 and boss.chassis.disabled)
	assert(level.player.global_position == boss.global_position and level.player.health == level.player.max_health)
	level.player.global_position = Vector2(640, 679)
	assert(await until(func(): return boss.phase == ACTOR.Phase.STALK))
	assert(boss.collision_layer == ACTOR.CHASSIS_LAYER and boss.collision_mask == (ACTOR.WORLD | ACTOR.PLAYER_FEET_LAYER) and boss.armor.collision_layer == 4)
	assert(level.wrecks.is_empty() and boss.body_sprite.visible)
	await verify_hull_and_flank(boss)
	await verify_pinch(boss)

	# Firing locks the line immediately. A sidestep can still avoid the travelling silk.
	boss.global_position = Vector2(774, 476)
	boss._switch(ACTOR.Phase.STALK, 0.0)
	boss.web_cooldown = 0.0
	level.player.global_position = Vector2(927, 492)
	assert(await until(func(): return boss.phase == ACTOR.Phase.WEB_SHOT and boss.web_active, 3))
	var web_lock := boss.web_direction
	level.player.global_position = Vector2(920, 590)
	await frames(3)
	assert(boss.phase == ACTOR.Phase.WEB_SHOT and not boss.bound)
	assert(boss.web_direction == web_lock)
	assert(await until(func(): return boss.phase == MISS))
	assert(level.player.health == level.player.max_health)

	# A shot down a clear line binds and actually pulls. A wall breaks the silk.
	boss.global_position = Vector2(774, 476)
	boss._switch(ACTOR.Phase.STALK, 0.0)
	boss.web_cooldown = 0.0
	level.player.global_position = Vector2(925, 492)
	assert(await until(func(): return boss.bound))
	var before_pull: Vector2 = level.player.global_position
	await frames(26)
	assert(boss.bound and level.player.controls_enabled)
	assert(level.player.global_position.distance_to(before_pull) > 24.0)
	level.player.global_position = Vector2(585, 456)
	await frames(2)
	assert(not boss.bound and level.player.web_slow_remaining <= 0)
	assert(boss.phase == MISS and level.player.health == level.player.max_health)

	# Locked grab cannot track a sidestep; the miss creates a punish window.
	boss.global_position = Vector2(774, 476)
	level.player.global_position = Vector2(843, 483)
	boss._begin_grab_warning()
	var grab_lock := boss.locked
	level.player.global_position = Vector2(813, 574)
	assert(await until(func(): return boss.phase == MISS))
	assert(boss.miss_pose and boss.locked == grab_lock)
	assert(level.player.controls_enabled and level.player.health == level.player.max_health)

	# A legal grab disables control only until release. The existing machine
	# blocks the throw, and landing deals exactly one damage.
	boss.global_position = Vector2(780, 471)
	level.player.global_position = Vector2(713, 471)
	boss._begin_grab_warning()
	assert(await until(func(): return boss.phase == ACTOR.Phase.LIFT))
	assert(boss.held and not level.player.controls_enabled)
	assert(await until(func(): return boss.phase == ACTOR.Phase.THROW))
	assert(await until(func(): return boss.phase == MISS))
	assert(level.player.controls_enabled and not boss.held)
	assert(level.player.health == level.player.max_health - 1)
	assert(level.player.global_position.x >= 681.0 and level.player.global_position.x < 712.0)

	# A real pulse hits the large visible armor, not only the floor collider.
	boss._switch(MISS, 2.0)
	boss.miss_pose = false
	await frames(2)
	var gun: Node2D = level.player.pulse_gun
	level.player.global_position = boss.global_position + Vector2(136, -32)
	level.player.aim_at(boss.global_position + Vector2(0, -32))
	var hp := boss.health
	assert(gun.request_fire(Vector2.LEFT))
	for i in range(75):
		await physics_frame
		gun.advance_time(1.0 / 60.0, level.player.global_position, Vector2.LEFT)
	assert(boss.health == hp - 1, "A horizontal pulse through the armor must hit once.")

	# The inherited gate only opens after the real boss death callback.
	boss.apply_damage(boss.health)
	assert(level.boss_beat and level._remaining_cleaners() == 0)
	assert(level.terminal_gate.get_meta("is_open") and not level.terminal_activated)
	await frames(2)
	level.player.global_position = level._terminal_access_position()
	var use := InputEventAction.new()
	use.action = &"interact"
	use.pressed = true
	if not level.terminal.get_node("FacilityVisual").powered:
		level._input(use)
		assert(level.terminal.get_node("FacilityVisual").powered)
		level.player.global_position = level._terminal_access_position()
	level._input(use)
	assert(paused and not level.terminal_activated)
	level._submit_terminal_code(level.interaction_token, "0000")
	assert(not level.terminal_activated)
	level._submit_terminal_code(level.interaction_token, "0417")
	assert(level.terminal_activated and level.interactables_parent.get_node("Door_p1_door_01").get_meta("is_open"))
	await create_timer(2.0).timeout
	level.player.global_position = level.final_exit.global_position
	await frames(3)
	assert(level.is_level_complete)
	level._retry_level()
	assert(not is_instance_valid(level.boss) and not level.boss_beat)
	assert(first.health > 0 and second.health > 0 and level._remaining_cleaners() == 3)
	assert(level.wrecks.is_empty() and not level.terminal_gate.get_meta("is_open"))
	assert(level.player.controls_enabled and level.player.pulse_gun_equipped)
	# Reverse the order on a retry; the gate still stays closed at assembly.
	second.apply_damage(second.health)
	first.apply_damage(first.health)
	assert(is_instance_valid(level.boss) and not level.terminal_gate.get_meta("is_open"))
	level._retry_level()
	assert(level.wrecks.is_empty())
	press(KEY_B)
	boss = level.boss
	assert(is_instance_valid(boss) and await until(func(): return boss.phase == ACTOR.Phase.STALK))
	level.player.global_position = Vector2(921, 492)
	level.camera.global_position = level.player.global_position
	level.camera.reset_smoothing()
	level.camera.force_update_scroll()
	boss.web_cooldown = 0.0
	boss._switch(ACTOR.Phase.STALK, 0.0)
	assert(await until(func(): return boss.bound))
	press(KEY_R)
	assert(not is_instance_valid(level.boss) and level.player.web_slow_remaining == 0.0)
	assert(level.player.controls_enabled and first.health > 0 and second.health > 0)
	press(KEY_B)
	boss = level.boss
	assert(is_instance_valid(boss) and await until(func(): return boss.phase == ACTOR.Phase.STALK))
	level.player.global_position = Vector2(727, 471)
	boss._begin_grab_warning()
	assert(await until(func(): return boss.held))
	level.player.apply_damage(level.player.max_health)
	assert(paused and level.player.is_dead)
	var retry: Button = level.game_menus.find_children("*", "Button", true, false).filter(func(button: Button): return button.text == "重试")[0]
	retry.pressed.emit()
	assert(not paused and not is_instance_valid(level.boss) and level.player.controls_enabled)
	assert(level.player.health == level.player.max_health and not level.terminal_gate.get_meta("is_open"))
	print("RETRY_PASS: B fuses, R clears active reel, death-menu retry releases a grab and restores the room")
	print("PARALLEL_CLEANER_PASS: both kill orders, gate, swept silk, pull, wall release, grab dodge, wall-safe throw, real pulse, proper terminal code, retry")
	level.queue_free()
	await process_frame
	quit()
