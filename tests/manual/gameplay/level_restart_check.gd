extends SceneTree
## Exercise the real pause-menu action and its save handoff with isolated files.
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const FLOW := preload("res://scenes/gameplay/spine_flow_state.gd")
const PATH := "user://test_level_restart.json"
const WORKSHOP := "res://scenes/gameplay/spine_workshop_visit.tscn"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _open(path: String, data: Dictionary = {}) -> Node:
	var scene := load(path) as PackedScene
	var room := scene.instantiate()
	set_meta("journey_session", {"path": PATH, "data": data, "defer_save": true})
	root.add_child(room)
	current_scene = room
	while not room.is_entry_ready():
		await process_frame
	return room

func _close_room() -> void:
	var room := current_scene
	room.queue_free()
	await room.tree_exited
	paused = false

func _click_restart(menu: Node) -> Node:
	if not paused:
		menu.toggle_pause()
	var button: Button
	for child in menu._content.get_children():
		if child is Button and child.text == "重试本房间":
			button = child
			break
	assert(button != null)
	button.pressed.emit()
	return root.get_node("EntryLoading")

func _run() -> void:
	create_timer(110, true, false, true).timeout.connect(func(): quit(1))
	Engine.time_scale = 3.0
	SAVE.erase(PATH)
	var abdomen = await _open(SAVE.SCENE)
	abdomen.game_menus.unlock_achievement("first_weapon")
	abdomen.blueprint_known = true
	abdomen.pulse_learned = true
	abdomen.player.learn_pulse()
	abdomen.player.health = 1
	abdomen.player.global_position += Vector2(16, 24)
	abdomen.terminal_activated = true
	abdomen.terminal.get_node("FacilityVisual").set_power(true)
	abdomen.unlocked_ducts[&"duct_arrival"] = true
	abdomen.checkpoint_beacon.activated = true
	abdomen.achievement_webs[0].restore_broken(0.2)
	abdomen.enemies[0].apply_damage(100)
	abdomen.explored_positions.append(Vector2(320, 2400))
	check(abdomen._save_journey() == OK, "First-level fixture saves")
	var loader := _click_restart(abdomen.game_menus)
	await loader.tree_exited
	abdomen = current_scene
	check(not paused and abdomen.player.global_position == abdomen._find_spawn_position()
		and abdomen.player.health == abdomen.player.max_health, "Abdomen restarts at its original spawn with full health")
	check(not abdomen.blueprint_known and not abdomen.pulse_learned and not abdomen.workshop_seen
		and not abdomen.player.pulse_gun_equipped and abdomen.unlocked_ducts.is_empty()
		and abdomen.explored_positions.is_empty(), "Abilities obtained in this level, ducts and exploration reset")
	check(not abdomen.terminal_activated and not abdomen.terminal_gate.get_meta("is_open")
		and abdomen.pulse_assembly_gate.collision_layer == 1
		and not abdomen.achievement_webs[0].broken and abdomen._remaining_cleaners() == 4
		and not abdomen.checkpoint_beacon.activated, "Terminal, gate, webs, enemies and beacon return to initial state")
	var saved := SAVE.read_save(PATH)
	check(saved.get("version") == 2 and not saved.blueprint_known and not saved.first_level_cleared
		and saved.snapshot.player.health == abdomen.player.max_health, "Continue uses the fresh first-level snapshot")
	check(abdomen.game_menus.achievements.get("first_weapon", false), "Journey achievements survive the level reset")
	await _close_room()

	var previous := {"first_level_cleared": true, "blueprint_known": true, "pulse_learned": true,
		"workshop_seen": true, "ducts": ["duct_arrival"], "explored": [[320.0, 2400.0]]}
	var spine = await _open(SAVE.SPINE, previous)
	spine.state.first_fall = true
	spine.state.hatch_open = true
	spine.state.record_read = true
	spine.state.receipt_learned = true
	spine.state.scatter_blueprint = true
	spine.state.assembled = true
	spine.state.calibrated = true
	spine.state.fluid_tutorial = true
	spine.state.completed = true
	spine.state.checkpoint = FLOW.SERVICE_CHECKPOINT
	spine.checkpoint_beacon.activated = true
	spine.hero().global_position = spine.anchor("ScatterCheckpoint")
	spine.hero().health = 1
	spine.hero().scatter_unlocked = true
	spine.hero().pressure = 2
	spine.protocol_rail.set_powered(true)
	spine.authorized_gate.set_open(true)
	spine.exit_gate.set_open(true)
	spine.defense.elapsed = 7.5
	var defeated = spine.enemies[0]
	defeated.apply_damage(100)
	spine.state.baseline = spine._snapshot_world()
	check(spine._save_progress(), "Second-level fixture saves")
	var before_rejected := FileAccess.get_file_as_bytes(PATH)
	spine.save_path = PATH.path_join("unwritable/journey.json")
	loader = _click_restart(spine.menus)
	while not loader.failed:
		await process_frame
	check(current_scene == spine and paused and spine.menus.page == spine.menus.Page.PAUSE,
		"Failed restart restores the same room and paused menu")
	check(spine.authorized_gate.is_open and spine.hero().health == 1 and not auto_accept_quit
		and before_rejected == FileAccess.get_file_as_bytes(PATH), "Rollback keeps live progress, saved bytes and the close handler")
	loader._cancel()
	await loader.tree_exited

	spine.save_path = PATH
	loader = _click_restart(spine.menus)
	await loader.tree_exited
	spine = current_scene
	check(not paused and spine.hero().global_position == spine.anchor("PlayerSpawn")
		and spine.hero().health == spine.hero().max_health, "Spine restarts at the entrance even after activating the beacon")
	check(spine.state == FLOW.fresh() and not spine.checkpoint_beacon.activated
		and not spine.protocol_rail.console.active and not spine.hero().scatter_unlocked
		and spine.hero().pulse_gun_equipped and spine.hero().pressure == 0 and not spine.hero().has_protocol,
		"New spine entry restores fresh progression and loadout")
	check(not spine.authorized_gate.is_open and not spine.exit_gate.is_open and spine.defense.elapsed < 0.2
		and spine.map.service_passage_state == spine.map.ServicePassage.CONCEALED
		and spine.enemies.all(func(unit): return unit.health == unit.max_health),
		"Gate, hatch, timed defense and enemy placement use a new scene baseline")
	saved = SAVE.read_save(PATH)
	check(SAVE.resume_scene(saved) == SAVE.SPINE and saved.first_level_cleared
		and saved.pulse_learned and saved.workshop_seen and saved.ducts == previous.ducts
		and saved.explored == previous.explored and not saved.spine_flow.receipt_learned,
		"Reset saves a new spine snapshot while preserving the completed abdomen")
	await _close_room()

	var workshop_data := previous.duplicate(true)
	var visit_state := FLOW.fresh()
	visit_state.room = "workshop"
	visit_state.scatter_blueprint = true
	visit_state.assembled = true
	workshop_data.spine_flow = visit_state
	var workshop = await _open(WORKSHOP, workshop_data)
	loader = _click_restart(workshop.game_menus)
	await loader.tree_exited
	spine = current_scene
	check(spine.scene_file_path == SAVE.SPINE and spine.hero().global_position == spine.anchor("PlayerSpawn")
		and spine.state == FLOW.fresh(), "Restarting during the workshop visit resets its owning spine level")

	await _close_room()
	SAVE.erase(PATH)
	print("LEVEL RESTART CHECK: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
