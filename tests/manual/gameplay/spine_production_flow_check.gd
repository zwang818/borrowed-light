extends SceneTree
## Actual title/intro/first exit/video/loading/production route, with isolated saves.
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const PATH := "user://test_spine_production_journey.json"
const ACH := "user://test_spine_production_achievements.cfg"
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,text: String) -> void:
	if not value:
		failures.append(text)
		printerr("FAIL: ",text)
func wait_room(path: String, ready: bool = true) -> bool:
	var deadline := Time.get_ticks_msec()+100000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if current_scene == null or current_scene.scene_file_path!=path: continue
		if not ready: return true
		if current_scene.is_entry_ready() and not paused and not root.has_node("EntryLoading"): return true
	return false
func press(action: String) -> void:
	for down in [true,false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		root.push_input(event,true)
		await process_frame
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func(): printerr("FAIL: production watchdog"); quit(1))
	var personal: Array = []
	for path in [SAVE.DEFAULT_PATH,"user://achievements.cfg","user://settings.cfg"]:
		personal.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	SAVE.erase(PATH)
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = PATH
	title.settings_path = "user://test_spine_production_settings.cfg"
	root.add_child(title)
	current_scene = title
	await process_frame
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = title.start_button.get_global_rect().get_center()
	mouse.pressed = true
	root.push_input(mouse,true)
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse,true)
	check(await wait_room("res://scenes/ui/intro_cutscene/intro_cutscene.tscn",false),"Real title Start opens the production intro")
	await press("ui_cancel")
	check(await wait_room(SAVE.SCENE),"Intro skip and common loading reach the real first level")
	if current_scene.scene_file_path!=SAVE.SCENE:
		quit(1)
		return
	var first = current_scene
	first.game_menus.achievement_save_path = ACH
	# Fixture only shortens first-level combat; it does not replace the exit route.
	first.blueprint_known = true
	first.pulse_learned = true
	first.player.learn_pulse()
	first.player.health = 2
	first.terminal_activated = true
	first.player.global_position = first.final_exit.global_position
	first._on_exit_entered(first.player,first.final_exit.get_meta("exit_id"))
	await process_frame
	var transition
	for node in root.get_children():
		if node.get_script()==load("res://scenes/ui/intro_cutscene/level_transition.gd"): transition = node
	check(transition!=null and transition.video.is_playing(),"Real first-level exit starts the existing full video")
	if transition!=null: await transition.video.finished
	check(await wait_room("res://scenes/gameplay/spine_level.tscn"),"Video natural completion and common loading reach the formal interactive second level")
	var level = current_scene
	check(level.get_meta("flow_version","")=="spine_v5_interactive" and level.story_ready,"Production scene binds the interactive v5 flow")
	check(not level.isolate_progress and level.playtest_start==0 and level.save_path==PATH,"Formal flow uses the original journey with no developer jump")
	check(level.hero().health==2 and level.hero().pulse_gun_equipped and not level.hero().scatter_unlocked,"First exit carries real health and pulse without granting scatter")
	check(level.defense.emitters.size()==8 and not level.authorized_gate.is_open,"Formal flow enables hazards and locked authorization gate")
	level.state.first_fall = true
	level.state.hatch_open = true
	check(level._save_progress(),"Formal progress writes the owning journey")
	level._return_title()
	check(await wait_room("res://scenes/main.tscn",false),"Formal pause/title return uses the shared loading route")
	while root.has_node("EntryLoading"): await process_frame
	title = current_scene
	title.game_save_path = PATH
	title._refresh_archive()
	title._continue_journey()
	check(await wait_room("res://scenes/gameplay/spine_level.tscn"),"Title Continue returns to the same formal flow")
	level = current_scene
	check(level.state.first_fall and level.state.hatch_open and not level.isolate_progress,"Formal continue retains story knowledge and save ownership")
	# Base menu construction must see the production save owner on a return transfer.
	check(level.menus.achievement_save_path=="user://achievements.cfg","Formal entry uses the real achievement profile, rather than the preview profile")
	# Completed manufacture fixture: the real manufacture is covered separately.
	level.state.scatter_blueprint = true
	level.state.assembled = true
	level.state.calibrated = true
	level.hero().scatter_unlocked = true
	level._begin_workshop_trip()
	check(await wait_room("res://scenes/gameplay/spine_workshop_visit.tscn"),"Formal journey can revisit the real abdomen workshop")
	var workshop = current_scene
	check(workshop.flow_path==PATH and workshop.game_menus.achievement_save_path=="user://achievements.cfg","Workshop retains production save and achievement ownership")
	workshop._return_spine()
	check(await wait_room("res://scenes/gameplay/spine_level.tscn"),"Formal workshop return reaches production spine")
	check(current_scene.save_path==PATH and not current_scene.isolate_progress and current_scene.menus.achievement_save_path=="user://achievements.cfg","Return loading cannot silently switch to preview persistence")
	current_scene.queue_free()
	await process_frame
	SAVE.erase(PATH)
	DirAccess.remove_absolute(ACH)
	var i := 0
	for path in [SAVE.DEFAULT_PATH,"user://achievements.cfg","user://settings.cfg"]:
		var after := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		check(after==personal[i],"Personal file unchanged: "+path)
		i += 1
	print("SPINE PRODUCTION FLOW: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
