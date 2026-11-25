extends SceneTree
## Run with CHECKPOINT_CAPTURE_DIR set in a graphical session to capture red and green.
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const FLOW := preload("res://scenes/gameplay/spine_flow_state.gd")
const PATH_ABDOMEN := "user://test_checkpoint_abdomen.json"
const PATH_SPINE := "user://test_checkpoint_spine.json"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _open(path: String, save_path: String, data: Dictionary = {}) -> Node:
	if current_scene != null:
		var previous := current_scene
		previous.queue_free()
		await previous.tree_exited
	paused = false
	set_meta("journey_session", {"path": save_path, "data": data, "defer_save": true})
	var room := (load(path) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	while not room.is_entry_ready():
		await process_frame
	await physics_frame
	return room

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _continue_from_title(path: String) -> Node:
	var previous := current_scene
	previous.queue_free()
	await previous.tree_exited
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = path
	root.add_child(title)
	current_scene = title
	title.start_button.pressed.emit()
	await root.get_node("EntryLoading").tree_exited
	return current_scene

func _capture(name: String) -> void:
	var folder := OS.get_environment("CHECKPOINT_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))

func _open_space(player: CharacterBody2D, point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1 | 4
	return root.world_2d.direct_space_state.intersect_shape(query, 1).is_empty()

func _retry_from_menu(menus: Node) -> void:
	for button in menus._content.get_children():
		if button is Button and button.text == "重试":
			button.pressed.emit()
			return
	check(false, "Death menu offers retry")

func _reported(spine: Node) -> bool:
	return spine.status_notice.visible and spine.status_label.text.contains("存档点已保存")

func _run() -> void:
	create_timer(120, true, false, true).timeout.connect(func(): quit(1))
	root.size = Vector2i(1152, 648)
	SAVE.erase(PATH_ABDOMEN)
	SAVE.erase(PATH_SPINE)

	var old_abdomen := {"blueprint_known":true, "pulse_learned":false, "workshop_seen":false,
		"ducts":[], "explored":[], "abdomen_checkpoint":SAVE.ABDOMEN_CHECKPOINT}
	var abdomen = await _open(SAVE.SCENE, PATH_ABDOMEN, old_abdomen)
	var beacon = abdomen.checkpoint_beacon
	check(not beacon.activated and abdomen._retry_spawn() == abdomen._find_spawn_position(),
		"A legacy save without the laser starts on the accessible side of the locked gate")
	abdomen.pulse_learned = true
	abdomen.player.learn_pulse()
	abdomen.cleaner_intro_seen = true
	var foot: Vector2 = beacon.global_position
	var combat_floor = abdomen.map.get_node("Floors/FirstCombat")
	var threshold = abdomen.map.get_node("Floors/GunThreshold")
	var at_threshold: Vector2 = threshold.to_local(foot)
	check(Rect2(Vector2.ZERO, combat_floor.size).has_point(combat_floor.to_local(foot))
		and at_threshold.y < 0.0 and at_threshold.y >= -24.0
		and at_threshold.x >= 0.0 and at_threshold.x < threshold.size.x
		and _open_space(abdomen.player, foot), "The first beacon fits just across the grate in the combat room")
	check(not beacon.activated and not beacon.lamp_material.get_shader_parameter("activated"), "First beacon starts red")
	abdomen.player.global_position = foot + Vector2(0, 48)
	abdomen.camera.global_position = abdomen.player.global_position
	abdomen.camera.reset_smoothing()
	await _capture("abdomen-red")

	abdomen.journey_save_path = PATH_ABDOMEN.path_join("missing/journey.json")
	abdomen.player.global_position = foot
	await _frames(3)
	check(not beacon.activated and abdomen.notify_label.text != "存档点已保存", "Failed writing leaves the beacon red")
	abdomen.journey_save_path = PATH_ABDOMEN
	await _frames(2)
	check(not beacon.activated and SAVE.read_save(PATH_ABDOMEN).is_empty(), "Standing on a failed beacon does not spam writes")

	abdomen.player.global_position = foot + Vector2(0, 28)
	await _frames(2)
	abdomen.player.global_position = foot + Vector2(0, 15)
	await _frames(3)
	check(beacon.activated and beacon.lamp_material.get_shader_parameter("activated")
		and abdomen.notify_bg.visible and abdomen.notify_label.text == "存档点已保存",
		"Body contact saves, turns green and announces on the HUD")
	var saved := SAVE.read_save(PATH_ABDOMEN)
	check(saved.get("abdomen_checkpoint") == SAVE.ABDOMEN_CHECKPOINT, "Abdomen checkpoint is written to the journey")
	abdomen.player.global_position = foot + Vector2(46, 20)
	await _capture("abdomen-green")

	abdomen.player.health = 2
	check(abdomen._save_journey() == OK, "A later save records the player away from the lamp")
	abdomen = await _continue_from_title(PATH_ABDOMEN)
	check(abdomen.checkpoint_beacon.activated and abdomen.player.global_position.is_equal_approx(foot)
		and abdomen.player.health == 2, "Title Continue uses the first beacon position and keeps saved health")
	abdomen.player.global_position -= Vector2(0, 80)
	abdomen.player.invulnerability_remaining = 0.0
	abdomen.player.apply_damage(999)
	check(paused and abdomen.game_menus.death_at_checkpoint, "Death menu names the saved checkpoint")
	_retry_from_menu(abdomen.game_menus)
	check(not paused and abdomen.player.global_position == foot and abdomen.player.health == abdomen.player.max_health,
		"Death retry chooses the touched first beacon")
	check(abdomen._remaining_cleaners() == 4, "Retry still restores the combat baseline")

	var opening := {"first_level_cleared": true, "blueprint_known": true, "pulse_learned": true,
		"workshop_seen": false, "ducts": [], "explored": [],
		"spine_flow": {"first_fall": true, "hatch_open": true, "checkpoint": "return"}}
	var spine = await _open(SAVE.SPINE, PATH_SPINE, opening)
	beacon = spine.checkpoint_beacons[FLOW.SERVICE_CHECKPOINT]
	foot = beacon.global_position
	var arena: Polygon2D = spine.map.get_node("Reservations/DefenseArena")
	check(spine.map.is_walkable_point(foot) and _open_space(spine.hero(), foot)
		and not Geometry2D.is_point_in_polygon(arena.to_local(foot), arena.polygon),
		"The service checkpoint is on a legal foot landing outside the defense arena")
	spine.hero().global_position = foot.move_toward(spine.anchor("MaintenanceExit"), 37.0)
	spine._update_camera()
	spine.get_node("Camera2D").reset_smoothing()
	check(not beacon.activated, "Spine beacon starts red even with a legacy return checkpoint")
	await _capture("spine-red")
	var lamp_edge: Vector2 = beacon.to_global(Vector2(-43, 3))
	check(lamp_edge.distance_to(foot) > beacon.TOUCH_RADIUS and spine.map.is_walkable_point(lamp_edge)
		and beacon._has_contact(beacon.to_global(Vector2(-28, -37))) and beacon._has_contact(foot),
		"The lantern cap, outer base and pressure plate all have touch coverage")
	spine.hero().global_position = lamp_edge
	await _frames(3)
	check(beacon.activated and _reported(spine) and spine.state.checkpoint == FLOW.SERVICE_CHECKPOINT,
		"Touching the lantern beyond the old radius supersedes the legacy return checkpoint")
	saved = SAVE.read_save(PATH_SPINE)
	check(saved.spine_flow.checkpoint == FLOW.SERVICE_CHECKPOINT and saved.spine_flow.hatch_open,
		"Spine checkpoint and open passage are written together")
	spine.hero().global_position = foot + spine.F * 53
	await _capture("spine-green")

	spine.hero().health = 2
	check(spine._save_progress(false), "A later save records the spine player away from the beacon")
	spine = await _continue_from_title(PATH_SPINE)
	check(spine.checkpoint_beacons[FLOW.SERVICE_CHECKPOINT].activated and spine.state.checkpoint == FLOW.SERVICE_CHECKPOINT
		and spine.hero().global_position.is_equal_approx(foot) and spine.hero().health == 2,
		"Title Continue uses the service beacon position and keeps saved health")
	spine.hero().global_position = spine.anchor("ScatterCheckpoint")
	spine.state.calibrated = true
	await _frames(2)
	check(spine.state.checkpoint == FLOW.SERVICE_CHECKPOINT, "The invisible return fallback cannot replace a touched beacon")
	var hud: Rect2 = spine.health_display.get_global_rect()
	check(is_equal_approx(hud.position.x, 20.0) and is_equal_approx(hud.end.y, root.get_visible_rect().end.y - 20.0),
		"The spine health display is anchored in the bottom-left corner")
	check(not hud.intersects(spine.interaction_panel.get_global_rect()),
		"The health display and interaction prompt have separate screen space")
	var patrol = spine.checkpoint_beacons[FLOW.PATROL_CHECKPOINT]
	var patrol_foot: Vector2 = patrol.global_position
	check(not patrol.activated and spine.map.is_walkable_point(patrol_foot) and _open_space(spine.hero(), patrol_foot)
		and spine.protocol_approach.to_local(patrol_foot).x < 0.0,
		"The patrol approach checkpoint starts red on a clear landing before the observation area")
	spine.hero().global_position = patrol_foot - spine.F * 65
	spine._update_camera()
	spine.get_node("Camera2D").reset_smoothing()
	await _capture("patrol-red")
	spine.hero().global_position = patrol_foot
	await _frames(3)
	check(patrol.activated and _reported(spine) and SAVE.read_save(PATH_SPINE).spine_flow.checkpoint == FLOW.PATROL_CHECKPOINT,
		"Contact activates and saves the new checkpoint")
	spine.hero().global_position = patrol_foot - spine.F * 65
	await _capture("patrol-green")
	spine.hero().health = 2
	check(spine._save_progress(false), "A later save preserves the patrol approach checkpoint")
	spine = await _continue_from_title(PATH_SPINE)
	check(spine.checkpoint_beacons[FLOW.PATROL_CHECKPOINT].activated and spine.state.checkpoint == FLOW.PATROL_CHECKPOINT
		and spine.hero().global_position.is_equal_approx(patrol_foot) and spine.hero().health == 2,
		"Continue resumes at the patrol approach checkpoint with saved health")
	spine.hero().invulnerability_remaining = 0.0
	spine.hero().apply_damage(999)
	_retry_from_menu(spine.menus)
	check(not paused and spine.hero().global_position == patrol_foot and spine.hero().health == spine.hero().max_health,
		"Death retry uses the patrol approach checkpoint with full health")

	var blueprint = spine.checkpoint_beacons[FLOW.BLUEPRINT_CHECKPOINT]
	var blueprint_foot: Vector2 = blueprint.global_position
	check(not blueprint.activated and spine.map.is_walkable_point(blueprint_foot) and _open_space(spine.hero(), blueprint_foot),
		"The new checkpoint starts red with a clear landing on the main deck")
	spine.save_path = PATH_SPINE.path_join("missing/journey.json")
	spine.hero().global_position = blueprint_foot
	await _frames(3)
	check(not blueprint.activated and spine.state.checkpoint == FLOW.PATROL_CHECKPOINT,
		"A failed write leaves the new beacon red and keeps the previous checkpoint")
	spine.save_path = PATH_SPINE
	spine.hero().global_position = blueprint_foot + spine.F * 53
	await _frames(2)
	spine._update_camera()
	spine.get_node("Camera2D").reset_smoothing()
	await _capture("blueprint-red")
	spine.hero().global_position = blueprint_foot
	await _frames(3)
	check(blueprint.activated and _reported(spine) and spine.state.checkpoint == FLOW.BLUEPRINT_CHECKPOINT,
		"Touching the new beacon's plate selects it as the latest checkpoint")
	spine.hero().global_position = blueprint_foot + spine.F * 53
	await _capture("blueprint-green")
	spine.hero().health = 2
	check(spine._save_progress(false), "Saving away from the new beacon keeps its checkpoint")
	spine = await _continue_from_title(PATH_SPINE)
	check(spine.checkpoint_beacons.values().all(func(item): return item.activated)
		and spine.state.checkpoint == FLOW.BLUEPRINT_CHECKPOINT and spine.hero().global_position.is_equal_approx(blueprint_foot)
		and spine.hero().health == 2, "Continue picks the blueprint approach and restores all three lamps")
	spine.hero().invulnerability_remaining = 0.0
	spine.hero().apply_damage(999)
	_retry_from_menu(spine.menus)
	check(not paused and spine.hero().global_position == blueprint_foot and spine.hero().health == spine.hero().max_health,
		"Death retry chooses the most recently touched checkpoint")
	spine.hero().global_position = foot
	await _frames(3)
	check(spine.state.checkpoint == FLOW.SERVICE_CHECKPOINT and SAVE.read_save(PATH_SPINE).spine_flow.checkpoint == FLOW.SERVICE_CHECKPOINT,
		"Touching an earlier green beacon makes it the latest checkpoint again")

	current_scene.queue_free()
	await process_frame
	SAVE.erase(PATH_ABDOMEN)
	SAVE.erase(PATH_SPINE)
	print("CHECKPOINT BEACON CHECK: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
