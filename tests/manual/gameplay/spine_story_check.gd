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
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func(): printerr("FAIL: watchdog timeout"); quit(1))
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	for path in ["spine_flow_state","spine_flow_player","spine_calibration_target","spine_flow_gate","spine_protocol_panel","spine_flow_loading","spine_story_defense","spine_story_signals","spine_story_level","spine_workshop_visit"]:
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
		check(not level.authorized_gate.is_open,"Authorization gate starts physically locked")
		check(level.defense.emitters.size()==8 and level.defense.electrodes.size()==7,"Authored defense devices drive real damage")
		await capture("entry")
		await walk_to(level.map.get_node("RouteWaypoints/MainRoute/Point01").global_position)
		if not level.state.first_fall: await walk_to(level.map.get_node("RouteWaypoints/MainRoute/Point02").global_position)
		if not level.state.first_fall: await walk_to(level.anchor("IsolationGate")-level.F*56)
		if not level.state.first_fall: await wait_game(3.2)
		await process_frame
		await process_frame
		await wait_game(0.4)
		check(level.state.first_fall and paused and not level.hero().is_dead,"First real damage hands off to recovery communications, without a death menu")
		await dialogue()
		check(not paused and level.map.service_passage_state==level.map.ServicePassage.REVEALED,"First fall reveals the physical maintenance hatch")
		await press("interact")
		check(level.state.hatch_open,"Real E input opens maintenance passage")
		for waypoint in level.map.get_node("RouteWaypoints/ServiceRoute").get_children().slice(4):
			await walk_to(waypoint.global_position,4)
		check(level.hero().global_position.distance_to(level.map.get_node("RouteWaypoints/ServiceRoute/Point12").global_position)<12,"Real player walks the opened inspection route without crossing walls")
		await capture("hatch_exit")
		level.hero().global_position = level.anchor("ProtocolTerminalUse")
		await physics_frame
		await press("interact")
		check(is_instance_valid(level.protocol_panel),"Real terminal interaction opens three-contact input")
		await capture("protocol")
		if not is_instance_valid(level.protocol_panel):
			print("SPINE STORY CHECK: ",failures)
			quit(1)
			return
		level.protocol_panel._send()
		await wait_game(2.9)
		check(not level.state.receipt_learned and level.protocol_panel.contacts==[false,false,false],"Wrong receipt preserves contacts and grants no protocol")
		level.protocol_panel._toggle(1)
		level.protocol_panel._send()
		await wait_game(2.9)
		check(level.state.receipt_learned and level.hero().has_protocol,"Correct receipt activates real cleaner recognition state")
		level.hero().global_position = level.anchor("ProtocolGateReader")-level.F*25
		await physics_frame
		await press("interact")
		await wait_game(3.0)
		check(level.authorized_gate.is_open,"Learned receipt is reused at the physical authorization gate")
		await walk_to(level.anchor("AuthorizedDoor")+level.F*40,4)
		check(level.hero().global_position.distance_to(level.anchor("AuthorizedDoor")+level.F*40)<12,"Real body crosses the gate after the two cleaners yield")
		level._update_camera()
		await physics_frame
		await physics_frame
		var gate_sentry
		for unit in level.enemies:
			if unit.entity_id == "p2_protocol_gate_sentry": gate_sentry = unit
		check(level.hero().has_protocol and not level.demo_cleaner.can_detect() and gate_sentry.can_detect(),"Inside the same valid protocol, cleaner refuses a target while the real gate sentry detects it")
		level.hero().global_position = level.anchor("ScatterEvolution")+Vector2(0,32)
		await physics_frame
		await press("interact")
		await dialogue()
		check(level.state.scatter_blueprint and not level.hero().scatter_unlocked,"Blueprint records knowledge without granting the scatter arm")
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
		level.player.global_position = level.interaction_points[&"pulse_workbench"].global_position+Vector2(0,48)
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
			level.hero().global_position = level.anchor("SpinalFluidTapUse")
			await physics_frame
			await press("interact")
			await dialogue()
			await wait_game(1.8)
			check(level.hero().pressure==level.state.capacity,"Real refill interaction fills finite pressure cells")
			level.hero().set_attack_mode(level.hero().AttackMode.SCATTER)
			level.hero().holster_remaining=2
			level.hero().update_combat_mode()
			check(level.hero().fire_scatter(Vector2.RIGHT),"Refilled scatter uses the production weapon")
			check(level.hero().pressure==level.state.capacity-1,"One volley consumes exactly one pressure cell")
			level.hero().pressure = 0
			await wait_game(0.8)
			check(not level.hero().fire_scatter(Vector2.RIGHT),"Empty pressure cannot auto-refill or fire")
			check(level.hero().set_attack_mode(level.hero().AttackMode.LASER),"Empty right arm still allows the independent left pulse")
			level.hero().pressure = 3
			level.state.ammo = 3
			print("STAGE: refill and retry")
			level._retry()
			check(level.hero().scatter_unlocked and level.state.calibrated,"Death retry keeps manufacture/calibration memory")
			level.hero().global_position = level.anchor("MaintenanceRecord")-level.F*32
			await physics_frame
			await press("interact")
			await dialogue()
			check(level.state.record_read,"Optional record remains readable after the main progression")
			level.hero().global_position = level.anchor("ExitTerminal")-level.F*52
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
