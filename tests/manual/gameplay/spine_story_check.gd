extends SceneTree
var failures: Array[String] = []
var level
func walk_to(point: Vector2, max_seconds: float = 18.0) -> void:
	var player = level.hero()
	for tick in range(int(max_seconds*240)):
		if paused or player.is_dead or player.global_position.distance_to(point)<5: break
		var dir: Vector2 = player.global_position.direction_to(point)
		for action in ["move_right","move_left","move_up","move_down"]: Input.action_release(action)
		Input.action_press("move_right" if dir.x>0 else "move_left",absf(dir.x))
		Input.action_press("move_down" if dir.y>0 else "move_up",absf(dir.y))
		await physics_frame
	for action in ["move_right","move_left","move_up","move_down"]: Input.action_release(action)
func capture(label: String) -> void:
	var folder := OS.get_environment("SPINE_STORY_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("spine_story_"+label+".png"))
func press(action: String) -> void:
	for down in [true,false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		root.push_input(event,true)
		await process_frame
func wait_game(seconds: float) -> void: await create_timer(seconds,true).timeout
func dialogue() -> void:
	for i in range(10):
		if not paused: return
		await press("interact")
		await process_frame
func wait_scene(path: String) -> bool:
	var until := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<until:
		await process_frame
		if current_scene != null and current_scene.scene_file_path==path and current_scene.is_entry_ready() and not paused and not root.has_node("EntryLoading"):
			level = current_scene
			return true
	return false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)
func check_solid_interactions() -> void:
	var player: CharacterBody2D = level.hero()
	var space := player.get_world_2d().direct_space_state
	var stance := PhysicsShapeQueryParameters2D.new()
	stance.shape = player.get_node("CollisionShape2D").shape
	stance.collision_mask = player.collision_mask
	for key in level.SOLID_INTERACTION_FIXTURES:
		var marker: Node2D = level.interaction_points[key]
		var point := marker.global_position
		var fixture: Node2D = level.map.get_node("SpineArt/" + level.SOLID_INTERACTION_FIXTURES[key])
		check(is_equal_approx(marker.global_rotation, fixture.global_rotation),
			"The marker follows the casing's orientation: " + key)
		var body: StaticBody2D = level.map.get_node("Covers/SpinalFluidPlinth/Body") \
			if key == "SpinalFluidTapUse" else fixture.get_node("Body")
		stance.transform = Transform2D(0, point)
		check(level.map.is_walkable_point(point) and space.intersect_shape(stance, 1).is_empty(),
			"The marker has room to stand beside the casing: " + key)
		var contact := KinematicCollision2D.new()
		var blocked := player.test_move(stance.transform, fixture.global_position - point, contact)
		check(blocked and contact.get_collider() == body, "The casing stops movement at the indicated side: " + key)
		check(level._nearest_interaction(point, level._interaction_candidates()) == key,
			"The position beside the casing selects the matching device: " + key)
func check_moving_interaction_prompts() -> void:
	var player: CharacterBody2D = level.hero()
	var origin := player.global_position
	var original_velocity := player.velocity
	player.velocity = Vector2.RIGHT * 100.0
	var candidates: Dictionary = level._interaction_candidates()
	for key in candidates:
		var point = level.interaction_points[key]
		player.global_position = point.global_position
		level._update_interaction_prompts()
		check(point._rectangle_focused and level.interaction_panel.visible and level.interaction_label.text.ends_with(candidates[key]),
			"Movement does not delay the prompt for " + key)
	player.global_position = origin
	player.velocity = original_velocity
	level._update_interaction_prompts()
	check(not level.interaction_panel.visible, "The prompt clears immediately outside interaction range")
func check_guard_patrol() -> void:
	var guards: Array = level.enemies.filter(func(unit): return unit is CharacterBody2D and unit != level.demo_cleaner)
	check(guards.size() == 7 and not level.demo_cleaner.patrol_cycle_query.is_valid(),
		"Only the seven combat cleaners share the patrol cycle")
	if guards.is_empty(): return
	var start: Vector2 = level.anchor("PlayerSpawn")
	var end: Vector2 = level.anchor("ToThorax")
	var left_band := start.lerp(end, 14.0 / 25.0)
	var right_band := start.lerp(end, 15.0 / 25.0)
	var rows := {}
	for guard in guards:
		var row := roundi(guard.home.y / 25.0)
		rows[row] = rows.get(row, 0) + 1
	var row_order := rows.keys()
	row_order.sort()
	check(row_order.map(func(row): return rows[row]) == [2, 3, 2],
		"The guards patrol in a 2–3–2 formation")
	check(level.anchor("Cleaner07").x < level.anchor("Cleaner04").x
		and level.anchor("Cleaner08").x < level.anchor("ExitCleaner").x,
		"Both additional guards fill the left slots in the two lower rows")
	var leader = guards[0]
	var previous: Vector2 = leader.global_position - leader.home
	var walked_out := false
	var walked_back := false
	var held_far_end := false
	var in_step := true
	var inside_bands := true
	for tick in range(240):
		await physics_frame
		var offset: Vector2 = leader.global_position - leader.home
		var step: float = (offset - previous).dot(level.F)
		walked_out = walked_out or step < -0.1
		walked_back = walked_back or step > 0.1
		held_far_end = held_far_end or (absf(step) < 0.01 and offset.length() > level.GUARD_PATROL_DISTANCE - 0.5)
		var visual = leader.combat_visual()
		for guard in guards:
			var position: Vector2 = guard.global_position
			inside_bands = inside_bands and (position - left_band).dot(level.F) > 31.0 \
				and (right_band - position).dot(level.F) > 38.0
			var other = guard.combat_visual()
			in_step = in_step and (guard.global_position - guard.home).distance_to(offset) < 0.03 \
				and other.face_left == visual.face_left and other.sprite_pose().index == visual.sprite_pose().index
		previous = offset
	check(in_step and walked_out and walked_back and held_far_end,
		"The seven guards stay in step through the full back-and-forth patrol and pause")
	check(inside_bands, "The entire patrol keeps the seven cleaner bodies clear of both deck bands")
func check_guard_alert(guard: CharacterBody2D) -> void:
	var player: CharacterBody2D = level.hero()
	var zone: Node2D = level.guard_patrol_zone
	var before: Dictionary = level._capture_room_snapshot(player)
	var approach := zone.to_global(Vector2(-64, 144))
	player.global_position = approach
	level._update_camera()
	level.get_node("Camera2D").reset_smoothing()
	await physics_frame
	await physics_frame
	check(guard.is_on_screen() and level._line_clear(guard.global_position, player.global_position)
		and not level.guard_alerted and not guard.can_detect(), "Visible guards keep patrolling before the yellow boundary")
	await walk_to(zone.to_global(Vector2(20, 144)), 2)
	await physics_frame
	check(level._in_guard_patrol_area(player.global_position), "Real movement crosses the yellow boundary")
	var reacting := [guard.State.CHASE, guard.State.WARNING, guard.State.ATTACK]
	check(not level.state.receipt_learned and level.guard_alerted and guard.can_detect() and guard.state in reacting,
		"Walking into the marked area triggers pursuit before solving the terminal")
	await walk_to(approach, 2)
	await physics_frame
	check(zone.to_local(player.global_position).x < -37.0 and guard.can_detect() and guard.state in reacting,
		"The guard keeps pursuing when the player retreats past the entire yellow stripe")
	var attack_state: int = guard.state
	var pursuit: Dictionary = level._capture_room_snapshot(player)
	level._apply_live_snapshot(before)
	check(not level.guard_alerted, "Restoring a save from before the encounter leaves the guards unalerted")
	level._apply_live_snapshot(pursuit)
	check(level.guard_alerted and guard.state == attack_state and guard.state in reacting,
		"Restoring a save outside the yellow stripe preserves an active pursuit")
	player.health = 1
	for tick in range(480):
		await physics_frame
		if player.is_dead: break
	check(player.is_dead and not level._in_guard_patrol_area(player.global_position),
		"A pursuing guard can defeat the player after retreat beyond the yellow stripe")
	if player.is_dead:
		await check_patrol_reminder()
	else:
		level._retry()
	level._apply_live_snapshot(before)
func check_patrol_reminder() -> void:
	var player: CharacterBody2D = level.hero()
	check(level.menus.page == level.menus.Page.DEATH and level.patrol_reminder_pending,
		"A lethal cleaner hit schedules the patrol reminder from the death menu")
	var defeated: Dictionary = level._capture_room_snapshot(player)
	level.patrol_reminder_pending = false
	level._apply_live_snapshot(defeated)
	check(level.patrol_reminder_pending, "The pending reminder survives a snapshot restore")
	await process_frame
	await press("ui_accept")
	check(not paused and not player.is_dead and not level.guard_alerted
		and player.global_position.is_equal_approx(level._retry_spawn()), "Retry respawns at the checkpoint and clears the alert")
	if paused: level._retry()
	check(level.patrol_reminder_pending and not level.patrol_notice.visible and not level.patrol_guide.visible,
		"The reminder waits for the player to return from the checkpoint")
	var approach: Node2D = level.protocol_approach
	player.global_position = approach.to_global(Vector2(-24, 144))
	await physics_frame
	Input.action_press(&"move_right")
	for tick in range(100):
		await physics_frame
		if not level.patrol_reminder_pending: break
	Input.action_release(&"move_right")
	check(not level.patrol_reminder_pending and level.patrol_intro != null,
		"Returning to the patrol after defeat starts the same camera preview")
	await check_patrol_preview("patrol_reminder")
	player.invulnerability_remaining = 0.0
	player.apply_damage(player.health)
	check(player.is_dead and not level.patrol_reminder_pending, "Other fatal damage does not schedule another patrol reminder")
	level.menus.retry_requested.emit()
func check_patrol_intro() -> void:
	var player: CharacterBody2D = level.hero()
	var previous := player.global_position
	var approach: Node2D = level.protocol_approach
	player.global_position = approach.to_global(Vector2(-24, 144))
	await physics_frame
	await physics_frame
	check(not level.patrol_intro_seen, "The camera stays with the player before reaching the patrol approach")
	Input.action_press(&"move_right")
	for tick in range(100):
		await physics_frame
		if level.patrol_intro_seen: break
	Input.action_release(&"move_right")
	await check_patrol_preview("patrol_intro")
	check(level._capture_room_snapshot(player).room.story_runtime.patrol_intro_seen,
		"Saving after the preview remembers that the player has seen it")
	player.global_position = previous
func check_patrol_preview(capture_name: String) -> void:
	var player: CharacterBody2D = level.hero()
	var stopped_at := player.global_position
	await wait_game(1.0)
	var camera: Camera2D = level.get_node("Camera2D")
	check(level.patrol_intro_seen and not player.controls_enabled and player.global_position.is_equal_approx(stopped_at)
		and camera.get_screen_center_position().is_equal_approx(level.patrol_camera_bounds.get_center()),
		"The " + capture_name + " pauses movement and pans onto the patrol")
	var message: Label = level.patrol_notice.get_child(0)
	check(level.patrol_notice.is_visible_in_tree() and message.text == "前方清扫者集结，正面交战危险！"
		and message.get_global_rect().get_center().y < root.get_visible_rect().size.y * 0.3
		and not level.patrol_guide.is_visible_in_tree(), "The patrol camera shows only the warning at the top of the screen")
	if level.status_notice.visible:
		check(not level.patrol_notice.get_global_rect().intersects(level.status_notice.get_global_rect()),
			"A recent checkpoint notice cannot cover the patrol warning")
	for unit in level.enemies:
		if unit is CharacterBody2D and unit != level.demo_cleaner:
			check(unit.is_on_screen(), "The patrol preview frames all seven combat cleaners")
	await capture(capture_name)
	await wait_game(4.5)
	await process_frame
	check(player.controls_enabled and not level.patrol_notice.visible and is_equal_approx(camera.zoom.x, level.follow_zoom),
		"The camera and controls return automatically without replaying while standing in the trigger")
	var guidance: Label = level.patrol_guide.get_child(0)
	check(level.patrol_guide.is_visible_in_tree() and guidance.text.contains("维护协议") and guidance.text.contains("无伤通过")
		and guidance.get_global_rect().get_center().y < root.get_visible_rect().size.y * 0.3,
		"The remaining guidance appears at the top after the camera returns")
	await capture(capture_name + "_guide")
	await wait_game(6.5)
	check(not level.patrol_guide.visible and player.controls_enabled, "The top guidance clears without interrupting movement")
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func(): printerr("FAIL: watchdog timeout"); quit(1))
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	for path in ["spine_flow_state","spine_flow_player","spine_calibration_target","spine_flow_gate","spine_protocol_panel","spine_protocol_rail","spine_patrol_demo","spine_flow_loading","spine_story_defense","spine_story_signals","spine_story_level","spine_workshop_visit"]:
		var script = load("res://scenes/gameplay/"+path+".gd")
		check(script != null and script.can_instantiate(),"Script compiles: "+path)
	if not failures.is_empty():
		quit(1)
		return
	level = load("res://scenes/gameplay/spine_story_playtest.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var deadline := Time.get_ticks_msec()+45000
	while not level.story_ready and Time.get_ticks_msec()<deadline: await process_frame
	check(level.story_ready,"Playable entry initializes")
	if level.story_ready:
		check(not level.hero().scatter_unlocked and level.hero().pulse_gun_equipped,"Entry grants only the inherited pulse arm")
		check(not level.pressure_panel.visible, "The scatter pressure panel is hidden before calibration")
		check(not level.authorized_gate.is_open,"Authorization gate starts physically locked")
		check(level.defense.emitters.size()==8 and level.defense.electrodes.size()==7,"Authored defense devices drive real damage")
		check(is_equal_approx(level.defense.cycle_speed, 4.0 / 3.0), "Entrance devices release 25% sooner each cycle")
		var hatch = level.interaction_points["MaintenanceHatch"]
		var camera: Camera2D = level.get_node("Camera2D")
		var observation = level.interaction_points["ProtocolObservation"]
		var terminal = level.interaction_points["ProtocolTerminalUse"]
		var reader = level.interaction_points["ProtocolGateReader"]
		var receiver = level.interaction_points["ProtocolTransferReceiver"]
		check(level.interaction_points.size() == 10 and hatch.cue == hatch.Cue.RECTANGLE and not hatch.visible,
			"Spine uses the abdomen rectangle cue and conceals the distant maintenance seam")
		check(is_equal_approx(observation.global_rotation, terminal.global_rotation),
			"The observation and console markers align with each other")
		var art_root := level.map.get_node("SpineArt") as Node2D
		var reader_model = art_root.get_node("ProtocolFittings/ProtocolGateReader")
		var receiver_model = art_root.get_node("ProtocolFittings/ProtocolTransferReceiver")
		check(reader_model.kind == receiver_model.kind and reader_model.solid_outline() == receiver_model.solid_outline()
			and is_equal_approx(reader.global_rotation, receiver.global_rotation),
			"The two transfer readers share their model, collision footprint and prompt orientation")
		check(level._interaction_candidates()["ProtocolGateReader"] == "检查检修传送装置",
			"An unsolved reader points the player to the transfer device")
		await physics_frame
		await physics_frame
		check_solid_interactions()
		check_moving_interaction_prompts()
		await check_guard_patrol()
		await capture("entry")
		await walk_to(level.map.get_node("RouteWaypoints/MainRoute/Point01").global_position)
		if not level.state.first_fall: await walk_to(level.map.get_node("RouteWaypoints/MainRoute/Point02").global_position)
		if not level.state.first_fall: await walk_to(level.anchor("IsolationGate")-level.F*56)
		if not level.state.first_fall: await wait_game(3.2)
		await process_frame
		await process_frame
		await wait_game(0.4)
		check(level.state.first_fall and paused and not level.hero().is_dead,"First real damage hands off to recovery communications, without a death menu")
		var respawn: Vector2 = level.first_fall_spawn.global_position
		check(level.hero().global_position.is_equal_approx(respawn)
			and level.map.is_walkable_point(respawn) and level._can_stand_at(respawn, 1),
			"First fall revives the player at the clear approach beside the yellow stripe")
		await dialogue()
		check(not paused and level.map.service_passage_state==level.map.ServicePassage.REVEALED,"First fall reveals the physical maintenance hatch")
		await wait_game(1.0)
		check(camera.get_screen_center_position().distance_to(hatch.global_position) < 4.0
			and hatch.visible and not level.hero().controls_enabled,
			"Finishing communications frames the revealed hatch")
		await capture("hatch_preview")
		await wait_game(1.8)
		check(level.hatch_preview == null and is_equal_approx(camera.zoom.x, level.follow_zoom)
			and level.hero().controls_enabled, "The camera returns to the player and restores movement")
		await wait_game(3.5)
		check(not level.hero().is_dead, "The respawn point remains safe while the hazards cycle")
		level._update_interaction_prompts()
		await press("interact")
		check(hatch.visible and not hatch._rectangle_focused and not level.interaction_panel.visible and not level.state.hatch_open,
			"The hatch does not focus or open from the respawn point")
		for waypoint in ["Point00", "Point01", "Point02", "Point03"]:
			await walk_to(level.map.get_node("RouteWaypoints/ServiceRoute/" + waypoint).global_position, 3.0)
		await walk_to(hatch.global_position.move_toward(level.hero().global_position, 32.0), 3.0)
		level.hero().velocity = Vector2.RIGHT
		level._update_interaction_prompts()
		check(hatch.visible and hatch._rectangle_focused and level.interaction_panel.visible
			and level.interaction_label.text.ends_with("开启检修盖板"), "The revealed hatch enlarges and shows its prompt while the player moves")
		var blocker := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var barrier := CircleShape2D.new()
		barrier.radius = 5.0
		shape.shape = barrier
		blocker.add_child(shape)
		level.add_child(blocker)
		blocker.global_position = hatch.global_position.lerp(level.hero().global_position, 0.5)
		await physics_frame
		await physics_frame
		await press("interact")
		check(not level.state.hatch_open and not hatch._rectangle_focused and not level.interaction_panel.visible,
			"A wall blocks hatch focus, the prompt, and interaction")
		blocker.queue_free()
		await physics_frame
		await physics_frame
		var art = level.map.get_node("SpineArt")
		var covers: Node2D = art.get_node("ServicePassageArt/ArmorCovers")
		var cover: Node2D = covers.get_node("MaintenanceHatch")
		var exit_cover: Node2D = covers.get_node("MaintenanceExit")
		var closed_at := cover.position
		var exit_closed_at := exit_cover.position
		var seal: CollisionShape2D = level.map.get_node("EntranceDefense/ServiceSeals/MaintenanceHatch/Collision")
		var exit_seal: CollisionShape2D = level.map.get_node("EntranceDefense/ServiceSeals/MaintenanceExit/Collision")
		var deck: Polygon2D = level.map.get_node("Floors/ServiceCatwalk/Top")
		var deck_material := deck.material
		await press("interact")
		check(level.state.hatch_open,"Real E input opens maintenance passage")
		check(not hatch.visible, "The marker disappears once the hatch opens")
		var reveal_start: Vector3 = deck.material.get_shader_parameter("service_reveal")
		await wait_game(0.55)
		check(covers.visible and cover.position != closed_at and exit_cover.position == exit_closed_at
			and not seal.disabled and not exit_seal.disabled,
			"The entrance retracts first while both ends still block the walkway")
		await wait_game(0.75)
		var reveal_mid: Vector3 = deck.material.get_shader_parameter("service_reveal")
		check(reveal_mid.z > reveal_start.z and art.service_lights[-2].energy > 0.0
			and is_zero_approx(art.service_lights[-1].energy) and camera.zoom.x < level.follow_zoom,
			"The walkway and lights unfold toward the exit under a wider camera")
		await wait_game(1.05)
		check(exit_cover.position != exit_closed_at and not exit_seal.disabled,
			"The exit retracts when the unfolding reaches the far end")
		await wait_game(0.85)
		check(not covers.visible and seal.disabled and exit_seal.disabled and deck.material == deck_material
			and is_equal_approx(camera.zoom.x, level.follow_zoom),
			"The deployed passage is walkable and the normal camera resumes")
		for waypoint in level.map.get_node("RouteWaypoints/ServiceRoute").get_children().slice(4):
			await walk_to(waypoint.global_position,4)
		check(level.hero().global_position.distance_to(level.map.get_node("RouteWaypoints/ServiceRoute/Point12").global_position)<12,"Real player walks the opened inspection route without crossing walls")
		check(level.checkpoint_beacons[level.FLOW.SERVICE_CHECKPOINT].activated
			and level.state.checkpoint == level.FLOW.SERVICE_CHECKPOINT,
			"Walking out of the inspection route activates the service exit beacon")
		await capture("hatch_exit")
		await check_patrol_intro()
		var guide = level.protocol_rail
		var cleaner = level.demo_cleaner
		var side := Vector2(-level.F.y, level.F.x)
		var guard = level.enemies.filter(func(unit): return unit.entity_id == &"p2_cleaner_03")[0]
		var gate_guard = level.enemies.filter(func(unit): return unit.entity_id == &"p2_cleaner_06")[0]
		var new_guard = level.enemies.filter(func(unit): return unit.entity_id == &"p2_cleaner_07")[0]
		var shifted_snapshot: Dictionary = level._capture_room_snapshot(level.hero())
		shifted_snapshot.room.story_runtime.erase("guard_formation")
		shifted_snapshot.room.story_runtime["observation_layout"] = 2
		shifted_snapshot.enemies.erase("p2_cleaner_07")
		shifted_snapshot.enemies.erase("p2_cleaner_08")
		shifted_snapshot.enemies["p2_cleaner_03"].global_position = [6260.466, -98.533]
		shifted_snapshot.enemies["p2_cleaner_03"].state = guard.State.CHASE
		shifted_snapshot.enemies["p2_cleaner_06"].global_position = [6634.25955, -172.42737]
		shifted_snapshot.enemies["p2_cleaner_06"].health = 2
		var saved_patrol_time: float = shifted_snapshot.room.story_runtime.guard_patrol_time
		level.guard_patrol_time = 0.0
		level._apply_live_snapshot(shifted_snapshot)
		check(is_equal_approx(level.guard_patrol_time, saved_patrol_time), "Resume restores the shared guard patrol phase")
		check(guard.global_position.is_equal_approx(level.anchor("Cleaner03"))
			and guard.state == guard.State.RECOVERY, "An unsolved save with shifted guards restores the authored patrol origin")
		var offset: Vector2 = gate_guard.global_position - level.anchor("Cleaner06")
		var progress := 1.0 - absf(1.0 - float(level._guard_patrol_cycle()))
		check(offset.distance_to(-level.F * level.GUARD_PATROL_DISTANCE * progress) < 0.01 and gate_guard.health == 2,
			"A patrolling gate guard from an old save joins the new formation at its saved phase and health")
		check(new_guard.global_position.distance_to(new_guard.home - level.F * level.GUARD_PATROL_DISTANCE * progress) < 0.01
			and new_guard.health == new_guard.max_health, "A guard absent from an old save starts at the restored patrol phase")
		await check_guard_alert(new_guard)
		cleaner.restore_loop(0.0)
		level.hero().global_position = guide.demonstration[0]
		var observed: Array[int] = []
		var observed_stop := 0
		var stopped_frames := 0
		var previous: Vector2 = cleaner.global_position
		var health: int = level.hero().health
		for i in range(480):
			await physics_frame
			var step: Vector2 = cleaner.global_position - previous
			previous = cleaner.global_position
			if step.length() < 0.05:
				stopped_frames += 1
				if stopped_frames >= 20 and observed.size() > 0 and observed.size() < 6:
					observed_stop = observed.size()
				continue
			stopped_frames = 0
			var direction := step.normalized().rotated(-guide.board_angle)
			var index: int = guide.DIRECTIONS.find(Vector2(roundf(direction.x), roundf(direction.y)))
			if index >= 0 and (observed.is_empty() or observed[-1] != index):
				observed.append(index)
			if observed.size() == 6 and cleaner.global_position.distance_to(guide.demonstration[0]) < 2:
				break
		check(observed.size() == 6 and observed == guide.observed_directions() and observed_stop == cleaner.stop_after,
			"The real cleaner demonstrates six moves and an observable intermediate stop")
		check(not cleaner.can_detect() and cleaner.state == cleaner.State.PATROL
			and cleaner.web_phase == 0 and level.hero().health == health, "The guide walks past a visible player without attacking")
		cleaner.apply_damage(99)
		check(cleaner.health == cleaner.max_health and cleaner.collision_layer == 0
			and not cleaner.has_node("ModelHurtbox"), "The demonstration stays available during combat")

		level.hero().global_position = level.anchor("ProtocolObservation")
		cleaner.restore_loop(1.4)
		level._update_camera()
		level.get_node("Camera2D").reset_smoothing()
		await capture("patrol")

		level.hero().global_position = level.interaction_points["ProtocolTerminalUse"].global_position
		await physics_frame
		await press("interact")
		check(is_instance_valid(level.protocol_panel), "Real terminal interaction opens the route and stop controls")
		await capture("protocol")
		if not is_instance_valid(level.protocol_panel) or observed.size() != 6 or observed_stop == 0:
			print("SPINE STORY CHECK: ", failures)
			quit(1)
			return
		var original: Array = level.protocol_panel.directions.duplicate()
		level.protocol_panel._send()
		check(not level.state.receipt_learned and level.protocol_panel.directions == original,
			"An incorrect sequence keeps input and grants no authorization")
		for i in range(observed.size()):
			while level.protocol_panel.directions[i] != observed[i]:
				level.protocol_panel._rotate(i)
		level.protocol_panel._send()
		check(not level.state.receipt_learned, "Correct directions alone cannot authorize the player")
		level.protocol_panel.stop_picker.select(1)
		level.protocol_panel._send()
		check(not level.state.receipt_learned, "A wrong stop leaves the protocol locked")
		level.protocol_panel._close()
		await process_frame
		level._open_protocol()
		check(level.protocol_panel.directions == observed and level.protocol_panel.stop_picker.get_selected_id() == 1,
			"Returning from observation preserves the entered directions and stop")
		level.protocol_panel.stop_picker.select(observed_stop)
		await capture("protocol_connected")
		level.protocol_panel._send()
		await physics_frame
		await process_frame
		await process_frame
		check(level.state.receipt_learned and level.hero().has_protocol,
			"Copying the observed sequence enables concealment even at the console")
		check(not observation.visible, "Learning the route removes the observation marker")
		var success_at: Vector2 = level.status_notice.get_global_rect().get_center()
		check(level.status_notice.visible and level.status_label.text.begins_with("维护协议已启用\n隐身已接通")
			and is_equal_approx(success_at.x, root.get_visible_rect().get_center().x)
			and success_at.y < root.get_visible_rect().size.y * 0.3,
			"Solving the route displays a confirmation banner at the top center")
		await capture("protocol_success")

		var zone: Node2D = level.protocol_zone
		var before_notch := zone.to_global(Vector2(-26, 144))
		var beyond_notch := zone.to_global(Vector2(28, 144))
		level.hero().global_position = before_notch
		await physics_frame
		await physics_frame
		check(not level.hero().has_protocol, "The protocol is inactive on the approach to the deck notch")
		await walk_to(beyond_notch, 3)
		check(level.hero().global_position.distance_to(beyond_notch) < 6 and level.hero().has_protocol,
			"Walking past the notch activates concealment across the main deck")
		await walk_to(before_notch, 3)
		check(not level.hero().has_protocol, "Walking back across the notch drops concealment")

		var gate_approach: Vector2 = level.anchor("ProtocolGateReader") + side * 78
		var before_patrol_health: int = level.hero().health
		await walk_to(gate_approach, 10)
		check(level.hero().global_position.distance_to(gate_approach) < 6 and level.hero().has_protocol
			and level.hero().health == before_patrol_health and not level.guard_alerted,
			"The player can walk through the patrol unharmed without raising the alert while hidden")
		await walk_to(gate_approach + level.F * 8 + side * 54, 4)
		check(level.hero().has_protocol, "Moving across the width of the corridor stays hidden")
		await press("protocol_exit")
		await physics_frame
		check(not level.hero().has_protocol and level.protocol_suspended, "Manual exit keeps protocol disabled within the area")
		level.hero().global_position = guard.global_position + side * 58.0
		level._update_camera()
		level.get_node("Camera2D").reset_smoothing()
		await physics_frame
		await physics_frame
		check(guard.can_detect() and guard.state == guard.State.CHASE,
			"After solving, a nearby guard resumes pursuit when the player exits concealment")
		level.hero().global_position = level.anchor("ProtocolExit")
		await physics_frame
		await physics_frame
		check(not level.hero().has_protocol and not level.protocol_suspended, "Exiting the area clears the manual override")
		level.hero().global_position = gate_approach
		await physics_frame
		await physics_frame
		check(level.hero().has_protocol, "Reentering anywhere in the area restores protocol")
		await capture("protocol_gate")
		check(level._interaction_candidates()["ProtocolGateReader"] == "传送至门后掩体"
			and level._interaction_candidates()["ProtocolTransferReceiver"] == "传送回门前",
			"Both transfer prompts describe the destination")
		await walk_to(reader.global_position, 4.0)
		await press("interact")
		check(level.hero().global_position.distance_to(receiver.global_position) < 1.0 and not level.hero().has_protocol,
			"Arriving at the far reader immediately ends concealment")
		var partition = level.authorized_gate
		var partition_body: StaticBody2D = partition.get_node("Body")
		check(not partition.is_open and not partition.opening and not partition_body.get_node("Collision").disabled,
			"The partition keeps its collision after transfer")
		for unit in level.enemies:
			if not unit is CharacterBody2D or unit == cleaner:
				continue
			var lane: float = partition.to_local(unit.global_position).y
			var start: Vector2 = partition.to_global(Vector2(-48, lane))
			var contact := KinematicCollision2D.new()
			check(unit.test_move(Transform2D(0, start), level.F * 96, contact) and contact.get_collider() == partition_body,
				"The partition blocks the cleaner's body: " + String(unit.entity_id))
		await capture("protocol_receiver")
		await press("interact")
		check(level.hero().global_position.distance_to(reader.global_position) < 1.0 and level.hero().has_protocol,
			"Returning to the front reader restores concealment")
		await press("interact")
		await walk_to(level.anchor("AuthorizedDoor") + level.F * 55, 6)
		check(level.hero().global_position.distance_to(level.anchor("AuthorizedDoor") + level.F * 55) < 12,
			"The player can walk around the far side after transfer")
		level._update_camera()
		await physics_frame
		await physics_frame
		var gate_sentry
		for unit in level.enemies:
			if unit.entity_id == "p2_protocol_gate_sentry":
				gate_sentry = unit
		check(not level.hero().has_protocol and gate_sentry.can_detect(), "The gate sentry detects the exposed player behind the partition")
		await walk_to(level.anchor("ProtocolExit"), 4)
		await physics_frame
		await physics_frame
		check(not level.hero().has_protocol, "Concealment stays off by the cover behind the partition")
		var legacy: Dictionary = level._capture_room_snapshot(level.hero())
		legacy.room.story_gates["p2_authorized_door"] = {"open": true, "opening": false, "aperture": 1.0}
		legacy.player.global_position = level.JOURNEY.SNAPSHOT.pack_vector(partition.global_position + level.F * 5)
		legacy.player.has_protocol = true
		legacy.enemies["p2_cleaner_06"].global_position = level.JOURNEY.SNAPSHOT.pack_vector(receiver.global_position + level.F * 8)
		level._apply_live_snapshot(legacy)
		await physics_frame
		await physics_frame
		check(not partition.is_open and level.hero().global_position.distance_to(receiver.global_position) < 1.0
			and not level.hero().has_protocol and gate_guard.global_position.distance_to(level.anchor("Cleaner06")) < 3.0,
			"An old open-gate save restores the player visibly at the far reader and a crossed cleaner on patrol")
		level.hero().global_position = level.interaction_points["ScatterEvolution"].global_position
		await physics_frame
		await press("interact")
		await dialogue()
		check(level.state.scatter_blueprint and not level.hero().scatter_unlocked,"Blueprint records knowledge without granting the scatter arm")
		check(level.status_notice.visible and level.status_label.text == "请通过返程井前往制造台",
			"Reading the blueprint shows the return-duct instruction in the top banner")
		await capture("scatter_blueprint_hint")
		var original_room = level
		var before_baseline: Dictionary = level.state.baseline.duplicate(true)
		level.save_path = "user://missing_spine_flow_test_directory/journey.json"
		level._begin_workshop_trip()
		var failure_deadline := Time.get_ticks_msec()+60000
		while Time.get_ticks_msec()<failure_deadline:
			await process_frame
			if root.has_node("EntryLoading") and root.get_node("EntryLoading").failed: break
		check(current_scene==original_room and original_room.state.baseline==before_baseline,"Failed destination save restores the original live room without committing its baseline")
		if root.has_node("EntryLoading"): root.get_node("EntryLoading")._cancel()
		await process_frame
		level = original_room
		level.save_path = ""
		check(not paused and not level.busy,"Failure Return restores controls and permits another transfer")
		level.hero().global_position = level.anchor("ReturnDuct")+Vector2(0,32)
		await physics_frame
		await press("interact")
		check(await wait_scene("res://scenes/gameplay/spine_workshop_visit.tscn"),"Actual loading reaches the original abdomen map and workbench")
		if current_scene.scene_file_path != "res://scenes/gameplay/spine_workshop_visit.tscn":
			print("SPINE STORY CHECK: ",failures)
			quit(1)
			return
		level.player.global_position = level.interaction_points[&"pulse_workbench"].global_position+Vector2(0,36)
		await physics_frame
		print("WORKSHOP BENCH: ",level.player.global_position," anchor ",level.interaction_points[&"pulse_workbench"].global_position," clear ",level._visit_line_clear(level.player.global_position,level.interaction_points[&"pulse_workbench"].global_position)," paused ",paused," busy ",level.visit_busy," completed ",level.is_level_complete)
		await press("interact")
		await dialogue()
		check(level.calibration_active and not level.player.scatter_unlocked,"Manufacture starts a trial without committing the ability")
		await capture("workshop")
		if level.calibration_active:
			print("STAGE: calibration trial")
			level.player.global_position = level.calibration_stand
			var center: Vector2 = (level.calibration_targets[0].position+level.calibration_targets[1].position)*0.5
			for attempt in range(6):
				var motion := InputEventMouseMotion.new()
				motion.position = level.get_viewport().get_canvas_transform()*center
				root.push_input(motion,true)
				await physics_frame
				await physics_frame
				level.player.holster_remaining = 2
				level.player.set_attack_mode(level.player.AttackMode.SCATTER)
				var origin: Vector2 = level.player.get_shot_origin(level.player.AttackMode.SCATTER).position
				check(level.player.fire_scatter(origin.direction_to(center)),"Real scatter burst accepted during trial")
				await wait_game(0.9)
				if level.flow_state.calibrated: break
				level.player.global_position -= level.calibration_direction*6
		print("STAGE: calibration finished ",level.flow_state.calibrated)
		check(level.flow_state.calibrated and level.player.scatter_unlocked,"One real scatter burst hits both calibration contacts")
		if not level.flow_state.calibrated:
			print("CALIBRATION: ",level.calibration_stand," targets ",level.calibration_targets.map(func(t):return t.position)," hits ",level.calibration_hits)
		else:
			level.player.global_position = level.ducts[&"duct_arrival"].point.global_position+Vector2(0,36)
			await physics_frame
			await press("interact")
			print("STAGE: return loading")
			check(await wait_scene("res://scenes/gameplay/spine_level.tscn"),"Actual loading returns to the second-level platform")
			check(level.hero().scatter_unlocked and level.state.calibrated,"Manufactured ability survives the round trip")
			var arrival: Vector2 = level.anchor("ScatterReturnEntry")
			check(level.hero().global_position.is_equal_approx(arrival)
				and arrival.distance_to(level.anchor("ReturnDuct")) < 15.0
				and level._can_stand_at(arrival, 1), "The workshop return lands safely on the return duct cover")
			check(level.JOURNEY.SNAPSHOT.vector(level.save_data.snapshot.player.global_position).is_equal_approx(arrival),
				"The return saves the actual landing position")
			check(level.status_notice.visible and level.status_label.text == "请前往脊液补能处补能",
				"Returning successfully from the workshop shows the refill instruction")
			await capture("workshop_return_hint")
			await walk_to(level.interaction_points["ScatterEvolution"].global_position, 4.0)
			await press("interact")
			check(paused and level.busy, "The blueprint can still be reread after the arm is installed")
			await dialogue()
			check(not paused and level.state.scatter_blueprint and level.hero().scatter_unlocked
				and not level.status_label.text.contains("请通过返程井前往制造台"),
				"Rereading the blueprint after manufacture does not repeat the workshop instruction")
			level.hero().global_position = level.interaction_points["SpinalFluidTapUse"].global_position
			await physics_frame
			await press("interact")
			await dialogue()
			await wait_game(0.35)
			check(level.status_notice.visible and level.status_label.text.contains("脊液接入")
				and not level.status_label.text.contains("右臂蓄压"), "The top banner shows refill progress separately")
			var health_box: Rect2 = level.health_display.get_global_rect()
			var pressure_box: Rect2 = level.pressure_panel.get_global_rect()
			check(level.pressure_panel.visible and level.pressure_label.text == "右臂蓄压  0 / %d" % level.state.capacity
				and is_equal_approx(pressure_box.position.x, health_box.position.x)
				and is_equal_approx(pressure_box.size.x, health_box.size.x)
				and is_equal_approx(pressure_box.end.y, health_box.position.y - 8.0),
				"Scatter pressure is aligned just above the bottom-left health display")
			await capture("refill_status")
			await wait_game(1.5)
			check(level.hero().pressure==level.state.capacity,"Real refill interaction fills finite pressure cells")
			check(level.status_notice.visible and level.status_label.text == "脊液补能完成",
				"Finishing refill shows the refill confirmation in the top banner")
			await capture("refill_complete")
			level.hero().set_attack_mode(level.hero().AttackMode.SCATTER)
			level.hero().holster_remaining=2
			level.hero().update_combat_mode()
			check(level.hero().fire_scatter(Vector2.RIGHT),"Refilled scatter uses the production weapon")
			check(level.hero().pressure==level.state.capacity-1,"One volley consumes exactly one pressure cell")
			await process_frame
			await process_frame
			check(level.pressure_label.text == "右臂蓄压  %d / %d" % [level.state.capacity - 1, level.state.capacity],
				"The bottom-left panel updates after firing")
			level.hero().pressure = 0
			await wait_game(0.8)
			await press("shoot")
			check(level.status_notice.visible and level.status_label.text == "请前往脊液补能处补能"
				and level.hero().pressure == 0 and is_zero_approx(level.hero().scatter_remaining),
				"The shooting input with empty scatter pressure shows the refill instruction without firing")
			await capture("scatter_empty_hint")
			check(level.hero().set_attack_mode(level.hero().AttackMode.LASER),"Empty right arm still allows the independent left pulse")
			level.hero().pressure = 3
			level.state.ammo = 3
			print("STAGE: refill and retry")
			level._retry()
			check(level.hero().scatter_unlocked and level.state.calibrated,"Death retry keeps manufacture/calibration memory")
			level.hero().global_position = level.interaction_points["MaintenanceRecord"].global_position
			await physics_frame
			await press("interact")
			await dialogue()
			check(level.state.record_read,"Optional record remains readable after the main progression")
			level.hero().global_position = level.interaction_points["ExitTerminal"].global_position
			await physics_frame
			await press("interact")
			await dialogue()
			await wait_game(0.9)
			check(level.exit_gate.is_open,"Exit terminal opens a real gate after manufacture")
			print("STAGE: exit gate walking")
			await walk_to(level.anchor("ThoraxEntry"),4)
			check(level.state.completed,"Actual exit walking reaches the second-level completion screen")
			await capture("complete")
	print("SPINE STORY CHECK: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
