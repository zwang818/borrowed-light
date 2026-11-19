extends SceneTree
## Run once with -- write, then again with -- read, using the same test paths.
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const ABDOMEN_PATH := "user://test_snapshot_abdomen.json"
const SPINE_PATH := "user://test_snapshot_spine.json"
const DEATH_PATH := "user://test_snapshot_death.json"

func _initialize() -> void:
	call_deferred("_run")

func _continue_from_title(path: String) -> Node:
	var previous := current_scene
	if previous != null:
		previous.queue_free()
		await previous.tree_exited
	paused = false
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = path
	root.add_child(title)
	current_scene = title
	title.start_button.pressed.emit()
	await root.get_node("EntryLoading").tree_exited
	return current_scene

func _write() -> void:
	for path in [ABDOMEN_PATH, SPINE_PATH, DEATH_PATH]:
		SAVE.erase(path)
	var knowledge := {"blueprint_known": true, "pulse_learned": true, "workshop_seen": false,
		"ducts": ["duct_arrival"], "explored": []}
	assert(SAVE.write_save(ABDOMEN_PATH, knowledge) == OK)
	knowledge.first_level_cleared = true
	knowledge.scatter_unlocked = true
	assert(SAVE.write_save(SPINE_PATH, knowledge) == OK)

	var abdomen = await _continue_from_title(ABDOMEN_PATH)
	abdomen.player.global_position = abdomen._find_spawn_position() + Vector2(14.125, -19.375)
	abdomen.player.apply_damage(1)
	abdomen.player.apply_web_slow(1.5, 0.6)
	var cleaner = abdomen.enemies[0]
	cleaner.global_position += Vector2(8.5, -2.75)
	cleaner.apply_damage(1)
	cleaner.state = cleaner.State.WARNING
	cleaner.remaining = 0.37
	cleaner.web_cooldown = 1.2
	abdomen.enemies[1].apply_damage(99)
	abdomen.achievement_webs[0].restore_broken(0.2)
	abdomen._open_door("p1_terminal_access_gate")
	abdomen.terminal.get_node("FacilityVisual").set_power(true)
	assert(abdomen.player.pulse_gun.request_fire(Vector2.RIGHT))
	abdomen.game_menus.toggle_pause()
	assert(abdomen._save_journey() == OK)
	assert(SAVE.read_save(ABDOMEN_PATH).version == 2)

	var spine = await _continue_from_title(SPINE_PATH)
	var player = spine.get_node("SpawnPoints/PlayerSpawn/Player")
	player.global_position += Vector2(30.25, -18.75)
	player.apply_damage(1)
	assert(player.set_attack_mode(player.AttackMode.SCATTER))
	player.scatter_remaining = 0.47
	var sentry = spine.enemies[0]
	sentry.state = sentry.State.BURST
	sentry.remaining = 0.12
	sentry.shots_left = 2
	sentry.attack_mode = 1
	sentry.shot_index = 4
	var combat_cleaner = spine.enemies.filter(func(enemy): return enemy.entity_id == "p2_cleaner_02")[0]
	combat_cleaner.apply_damage(99)
	var bullet = load("res://scenes/weapons/enemy_projectile.tscn").instantiate()
	spine.get_node("EnemyProjectiles").add_child(bullet)
	bullet.global_position = player.global_position + Vector2(89, 11)
	bullet.direction = Vector2.LEFT
	bullet.travelled = 53.5
	spine.entrance_hazards.elapsed = 8.25
	spine.defense.elapsed = 7.25
	spine.hero().pressure = 3
	spine.state.record_read = true
	spine.authorized_gate.set_open(true)
	spine.entrance_hazards.ring_hit_cycle[0] = 1
	var hazard := {"position": [player.global_position.x + 100, player.global_position.y],
		"direction": [-1, 0], "travel_left": 97.5}
	spine.entrance_hazards.restore_journey_state({"orbs": [hazard]})
	var burst = player.scatter_burst_script.new()
	burst.player = player
	player.get_parent().add_child(burst)
	burst.global_position = player.global_position
	burst.points[0] = Vector2(50, -5)
	burst.distances[0] = 50.5
	burst.spent[0] = true
	burst.age = 0.17
	spine.state.first_fall = true
	assert(spine._save_progress())

	spine.state.first_fall = true # The story recovery has already been seen.
	# Return to the title from death. Then verify the window close uses the
	# latest state rather than the previous save.
	player.invulnerability_remaining = 0.0
	player.apply_damage(99)
	assert(spine.menus.page == spine.menus.Page.DEATH)
	spine.save_path = DEATH_PATH
	spine._return_title()
	await scene_changed
	await root.get_node("EntryLoading").tree_exited
	spine = await _continue_from_title(SPINE_PATH)
	player = spine.get_node("SpawnPoints/PlayerSpawn/Player")
	player.global_position += Vector2(7.5, 2.25)
	var closing_position: Vector2 = player.global_position
	assert(not auto_accept_quit)
	root.close_requested.emit()
	assert(SAVE.SNAPSHOT.vector(SAVE.read_save(SPINE_PATH).snapshot.player.global_position).is_equal_approx(closing_position))

func _read() -> void:
	var abdomen = await _continue_from_title(ABDOMEN_PATH)
	assert(abdomen.player.global_position.is_equal_approx(abdomen._find_spawn_position()))
	assert(abdomen.player.health == 2 and is_equal_approx(abdomen.player.web_speed_factor, 0.6))
	assert(abdomen.player.pulse_gun.state == abdomen.player.pulse_gun.State.CHARGING)
	var cleaner = abdomen.enemies[0]
	assert(cleaner.health == cleaner.max_health - 1 and cleaner.state == cleaner.State.WARNING)
	assert(is_equal_approx(cleaner.remaining, 0.37) and is_equal_approx(cleaner.web_cooldown, 1.2))
	assert(cleaner.global_position.is_equal_approx(cleaner.home + Vector2(8.5, -2.75)))
	assert(abdomen.enemies[1].health == 0 and abdomen.enemies[1].collision_layer == 0)
	assert(abdomen.terminal_gate.collision_layer == 0)
	assert(abdomen.terminal.get_node("FacilityVisual").powered and not abdomen.terminal_activated)
	assert(abdomen.achievement_webs[0].broken and abdomen.achievement_webs[0].collision_layer == 0)
	abdomen._retry_level()
	assert(abdomen.player.global_position.is_equal_approx(abdomen._find_spawn_position()))
	assert(abdomen.player.health == abdomen.player.max_health and abdomen._remaining_cleaners() == 3)
	assert(not abdomen.terminal_gate.get_meta("is_open") and not abdomen.achievement_webs[0].broken)

	var spine = await _continue_from_title(SPINE_PATH)
	var spawn = spine.get_node("SpawnPoints/PlayerSpawn")
	var player = spawn.get_node("Player")
	assert(player.global_position.is_equal_approx(spine.anchor("DefenseSafePocket")))
	assert(player.health == 2 and player.scatter_unlocked and player.selected_mode == player.AttackMode.SCATTER)
	assert(is_equal_approx(player.scatter_remaining, 0.47))
	var sentry = spine.enemies[0]
	assert(sentry.state == sentry.State.BURST and sentry.shots_left == 2 and sentry.shot_index == 4)
	var combat_cleaner = spine.enemies.filter(func(enemy): return enemy.entity_id == "p2_cleaner_02")[0]
	assert(combat_cleaner.health == 0 and combat_cleaner.collision_layer == 0)
	assert(is_equal_approx(spine.defense.elapsed, 7.25) and spine.hero().pressure == 3 and spine.state.record_read and spine.authorized_gate.is_open)
	assert(is_equal_approx(spine.entrance_hazards.elapsed, 8.25) and spine.entrance_hazards.ring_hit_cycle[0] == 1)
	assert(is_equal_approx(spine.entrance_hazards.orbs.back().travel_left, 97.5))
	assert(is_equal_approx(spine.get_node("EnemyProjectiles").get_child(0).travelled, 53.5))
	var burst = get_first_node_in_group("b_scatter_flashes")
	assert(burst.spent[0] and is_equal_approx(burst.distances[0], 50.5))

	spine = await _continue_from_title(DEATH_PATH)
	player = spine.get_node("SpawnPoints/PlayerSpawn/Player")
	assert(paused and player.is_dead and player.health == 0 and spine.menus.page == spine.menus.Page.DEATH)
	spine._retry()
	assert(not paused and not player.is_dead and player.scatter_unlocked)

	abdomen = await _continue_from_title(ABDOMEN_PATH)
	abdomen.player.health = 2
	abdomen.is_level_complete = true
	abdomen._show_level_complete()
	assert(SAVE.resume_scene(SAVE.read_save(ABDOMEN_PATH)) == SAVE.SCENE)
	for child in root.get_children():
		if child.get_script() == preload("res://scenes/ui/intro_cutscene/level_transition.gd"):
			# Skip video playback in this headless test, then use the real loader.
			child._finish()
			break
	await root.get_node("EntryLoading").tree_exited
	var arrived := SAVE.read_save(ABDOMEN_PATH)
	assert(SAVE.resume_scene(arrived) == SAVE.SPINE and arrived.snapshot.player.health == 2)
	for path in [ABDOMEN_PATH, SPINE_PATH, DEATH_PATH]:
		SAVE.erase(path)
	print("Journey snapshot: two levels, window close, combat, room state and death/retry: PASS")
	quit()

func _run() -> void:
	create_timer(120, true, false, true).timeout.connect(func(): quit(1))
	if "write" in OS.get_cmdline_user_args():
		await _write()
	else:
		await _read()
