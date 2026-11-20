extends SceneTree

const ROOM := preload("res://scenes/gameplay/abdomen_level.tscn")
const LEVEL := preload("res://scenes/gameplay/abdomen_boss_level.gd")
const BOSS := preload("res://scenes/enemies/parallel_cleaner/boss.gd")
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const PATH := "user://abdomen-boss-journey-check.json"
const BATTLE_ENTRY := Vector2(855, 533)
const INSIDE_BOSS_DOOR := Vector2(640, 626)
const STEP := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")


func until(predicate: Callable, frames := 180) -> bool:
	for i in range(frames):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func load_room(data: Dictionary = {}, resume := false) -> LEVEL:
	if not data.is_empty():
		set_meta("journey_session", {"path": PATH, "data": data, "resume_at_checkpoint": resume})
	var level := ROOM.instantiate() as LEVEL
	assert(level != null)
	root.add_child(level)
	current_scene = level
	assert(await until(func(): return level.entry_ready))
	level.game_menus.bind_achievement_journey(PATH)
	level.player.set_physics_process(false)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	return level


func clear_cleaners(level: LEVEL) -> void:
	for enemy in level.enemies:
		if enemy.is_in_group("cleaners"):
			enemy.apply_damage(enemy.health)


func enter_exit_room(level: LEVEL) -> void:
	level.player.global_position = BATTLE_ENTRY
	level.camera.global_position = BATTLE_ENTRY
	level.camera.reset_smoothing()


func check_boss_door(level: LEVEL, open: bool) -> void:
	assert(level.boss_gate.get_meta("is_open") == open)
	assert(level.boss_gate.get_node("FacilityVisual").open_amount == (1.0 if open else 0.0))
	var outside := level.boss_retry_point.global_position
	var query := PhysicsRayQueryParameters2D.create(INSIDE_BOSS_DOOR, outside, BOSS.WORLD)
	var hit := level.get_world_2d().direct_space_state.intersect_ray(query)
	if open:
		assert(hit.is_empty(), "Open door must allow crossing the threshold")
	else:
		assert(hit.get("collider") == level.boss_gate, "The new door must physically block the threshold")


func check_exit_duct(level: LEVEL, boss: BOSS) -> void:
	const ARRIVAL_DUCT := &"duct_arrival"
	const EXIT_DUCT := &"duct_exit"
	var original := boss.global_position
	var preferred_landing: Variant = level._duct_landing(EXIT_DUCT)
	assert(preferred_landing is Vector2)
	boss.global_position = preferred_landing
	await physics_frame
	var safe_landing: Variant = level._duct_landing(EXIT_DUCT)
	assert(safe_landing is Vector2 and safe_landing != preferred_landing)
	level.unlocked_ducts[ARRIVAL_DUCT] = true
	level.unlocked_ducts[EXIT_DUCT] = true
	level.player.global_position = level.ducts[ARRIVAL_DUCT].point.global_position
	level._try_interact()
	assert(paused and level.pending_interaction == ARRIVAL_DUCT)
	level._travel_duct(level.interaction_token, EXIT_DUCT)
	assert(level.player.global_position.is_equal_approx(safe_landing))
	assert(await until(func(): return not paused))
	var hatch = level.ducts[EXIT_DUCT].point
	boss.global_position = hatch.global_position + Vector2(0, -55)
	level.player.global_position = hatch.global_position
	level.camera.global_position = hatch.global_position
	level.camera.reset_smoothing()
	await physics_frame
	boss._lock_at_player()
	boss._resolve_grab()
	assert(boss.held and not level.player.controls_enabled)
	level._try_interact()
	assert(not paused and level.pending_interaction.is_empty())
	boss.cancel_actions()
	boss._switch(BOSS.Phase.STALK, 0.0)
	level._try_interact()
	assert(paused and level.pending_interaction == EXIT_DUCT)
	level.finish_interaction(level.interaction_token, false)
	assert(await until(func(): return not paused))
	boss.global_position = original
	enter_exit_room(level)
	print("BOSS_JOURNEY_DUCT_PASS: solid chassis blocks pipe landing and a held player cannot interact")


func fight_and_save(level: LEVEL) -> Dictionary:
	assert(not level.pulse_learned and not is_instance_valid(level.boss))
	check_boss_door(level, true)
	assert(level._remaining_cleaners() == 4 and level.terminal_gate.collision_layer == 1)
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_B
	shortcut.pressed = true
	level._input(shortcut)
	assert(level._remaining_cleaners() == 4 and not is_instance_valid(level.boss))
	level.blueprint_known = true
	level.pulse_learned = true
	level.player.learn_pulse()
	level.exit_cleaners[0].apply_damage(level.exit_cleaners[0].health)
	assert(not is_instance_valid(level.boss))
	clear_cleaners(level)
	assert(level._remaining_cleaners() == 1 and not is_instance_valid(level.boss))
	assert(level.terminal_gate.collision_layer == 1)
	enter_exit_room(level)
	assert(await until(func(): return is_instance_valid(level.boss)))
	var boss := level.boss
	assert(boss.phase == BOSS.Phase.ASSEMBLE)
	await physics_frame
	check_boss_door(level, false)
	level.player.global_position = INSIDE_BOSS_DOOR
	var crossing := level.player.move_and_collide(Vector2(0, 80))
	assert(crossing != null and crossing.get_collider() == level.boss_gate)
	enter_exit_room(level)
	assert(await until(func(): return not boss.chassis.disabled))
	boss.set_physics_process(false)
	await check_exit_duct(level, boss)
	boss.apply_damage(BOSS.MAX_HP - 11)
	boss._switch(BOSS.Phase.STALK, 0.0)
	for i in range(3):
		await physics_frame
	var player := level.player
	player.apply_web_slow(0.30, 0.60)
	boss._update_ground_silk(STEP)
	assert(is_equal_approx(player.web_movement_factor(), 0.60), "Boss ticks must preserve ordinary cleaner silk.")
	player.web_slow_remaining = 0.0
	player.web_speed_factor = 1.0
	var target := boss.armor.global_position
	var direction := player.global_position.direction_to(target)
	player.aim_at(target)
	var gun = player.pulse_gun
	assert(gun.request_fire(direction))
	for i in range(70):
		await physics_frame
		gun.advance_time(STEP, player.global_position, direction)
		if boss.health == 10:
			break
	assert(boss.health == 10 and gun.damaged_targets.has(boss.get_instance_id()))
	assert(boss.clearance_pending)
	boss.set_physics_process(true)
	assert(await until(func(): return boss.clearance.active))
	assert(await until(func(): return boss.clearance.clock >= 0.42))
	assert(not boss.leftover_silk.is_empty() and level.terminal_gate.collision_layer == 1)
	level.checkpoint_beacon.activated = true
	level.journey_save_path = PATH
	assert(level._save_journey() == OK)
	var data := SAVE.read_save(PATH)
	assert(data.snapshot.room.parallel_cleaner.health == 10 and data.snapshot.room.parallel_cleaner.clearance_pending)
	print("BOSS_JOURNEY_FIGHT_PASS: normal route locks terminal, fuses actual pair, production pulse enters clearance, save records active encounter")
	return data


func defeat_player_after_resume(level: LEVEL) -> Dictionary:
	assert(level.player.global_position.is_equal_approx(level.checkpoint_beacon.global_position))
	assert(not is_instance_valid(level.boss) and level.boss_resume.health == 10)
	check_boss_door(level, true)
	enter_exit_room(level)
	assert(await until(func(): return is_instance_valid(level.boss)))
	var boss := level.boss
	assert(boss.health == 10 and boss.clearance_pending and boss.leftover_silk.is_empty())
	assert(await until(func(): return boss.clearance.active))
	check_boss_door(level, false)
	level.player.invulnerability_remaining = 0.0
	assert(boss._apply_feedback_hit(level.player.health))
	assert(await until(func(): return paused, 60))
	assert(level.retry_at_boss_gate and level.game_menus.death_retry_hint == "重试将回到出口房门外")
	assert(not boss.clearance.active and boss.leftover_silk.is_empty() and level.camera.offset == level.shake_base)
	assert(level._save_journey() == OK)
	var saved := SAVE.read_save(PATH)
	assert(saved.snapshot.room.parallel_cleaner.retry_at_entrance)
	return saved


func retry_boss_death(level: LEVEL) -> void:
	assert(paused and level.player.is_dead and level.retry_at_boss_gate)
	level.game_menus.retry_requested.emit()
	assert(not paused and not is_instance_valid(level.boss))
	assert(level.player.global_position.is_equal_approx(level.boss_retry_point.global_position))
	assert(level.player.health == level.player.max_health and level.player.pulse_gun_equipped)
	assert(level.exit_cleaners[0].health == 0 and level.exit_cleaners[1].health == 0)
	assert(level._remaining_cleaners() == 1 and level.dead_enemies == 3)
	assert(level.terminal_gate.collision_layer == 1)
	await physics_frame
	check_boss_door(level, true)
	print("BOSS_JOURNEY_RETRY_PASS: death retry returns to the open Boss entrance with the pair already defeated")


func finish_room(level: LEVEL) -> Dictionary:
	assert(level.player.move_and_collide(INSIDE_BOSS_DOOR - level.player.global_position) == null)
	assert(level.player.global_position.is_equal_approx(INSIDE_BOSS_DOOR))
	assert(await until(func(): return is_instance_valid(level.boss)))
	assert(level.boss.health == BOSS.MAX_HP)
	assert(await until(func(): return level.boss.phase != BOSS.Phase.ASSEMBLE))
	check_boss_door(level, false)
	level.boss.apply_damage(level.boss.health)
	await physics_frame
	check_boss_door(level, true)
	assert(level.boss_beat and level._remaining_cleaners() == 0 and level.terminal_gate.collision_layer == 0)
	assert(level._save_journey() == OK)
	var won := SAVE.read_save(PATH)
	level.player.global_position = level._terminal_access_position()
	level._try_interact()
	assert(level.terminal.get_node("FacilityVisual").powered)
	level.player.global_position = level._terminal_access_position()
	level._try_interact()
	assert(paused and level.pending_interaction == level.TERMINAL_REQUEST)
	level.interaction_sheet._code_input.text = level.TERMINAL_CODE
	level.interaction_sheet._advance_or_finish()
	assert(await until(func(): return not paused and level.terminal_activated, 240))
	var final_door := level.interactables_parent.get_node("Door_p1_door_01") as StaticBody2D
	assert(final_door.collision_layer == 0)
	level.player.global_position = level.final_exit.global_position
	assert(await until(func(): return level.is_level_complete))
	assert(SAVE.read_save(PATH).first_level_cleared)
	var transition: Node
	for child in root.get_children():
		if "NEXT_SCENE" in child and child.NEXT_SCENE == "res://scenes/gameplay/spine_level.tscn":
			transition = child
			break
	assert(is_instance_valid(transition))
	var entry: Dictionary = get_meta("spine_entry")
	assert(entry.path == PATH and entry.health == level.player.health)
	transition.video.stop()
	transition._finish()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == SAVE.SPINE \
			and current_scene.is_entry_ready() and not paused and not root.has_node("EntryLoading"):
			break
	assert(current_scene != null and current_scene.scene_file_path == SAVE.SPINE
		and current_scene.is_entry_ready() and not paused and not root.has_node("EntryLoading"))
	print("BOSS_JOURNEY_EXIT_PASS: defeating Boss opens terminal, 0417 opens exit, save and real transition reach Spine")
	return won


func dispose_room(level: Node) -> void:
	set_deferred("current_scene", null)
	level.queue_free()
	await process_frame
	await process_frame


func run() -> void:
	SAVE.erase(PATH)
	var level := await load_room()
	var active := await fight_and_save(level)
	if active.is_empty():
		quit(1)
		return
	await dispose_room(level)
	level = await load_room(active, true)
	var dead := await defeat_player_after_resume(level)
	if dead.is_empty():
		quit(1)
		return
	await retry_boss_death(level)
	await dispose_room(level)
	level = await load_room(dead, true)
	await retry_boss_death(level)
	var won := await finish_room(level)
	if won.is_empty():
		quit(1)
		return
	await dispose_room(current_scene)
	level = await load_room(won, true)
	assert(level.boss_beat and level._remaining_cleaners() == 0 and level.terminal_gate.collision_layer == 0)
	check_boss_door(level, true)
	await dispose_room(level)
	won.snapshot.room.erase("parallel_cleaner")
	level = await load_room(won, true)
	assert(level.boss_beat and not is_instance_valid(level.boss) and level.terminal_gate.collision_layer == 0)
	print("BOSS_JOURNEY_SAVE_COMPAT_PASS: defeated Boss stays cleared, older unlocked saves keep their terminal access")
	await dispose_room(level)
	SAVE.erase(PATH)
	print("BOSS_JOURNEY_PASS")
	quit()
