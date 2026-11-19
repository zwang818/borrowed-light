extends SceneTree
const FLOW := preload("res://scenes/gameplay/spine_flow_state.gd")
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const PATH := "user://test_spine_flow_persistence.json"
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures.append(text)
		printerr("FAIL: ",text)
func run() -> void:
	var personal: Array = []
	for path in [SAVE.DEFAULT_PATH,"user://achievements.cfg","user://settings.cfg"]:
		personal.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	var state := FLOW.fresh()
	state.first_fall = true
	state.hatch_open = true
	state.scatter_blueprint = true
	state.assembled = true
	state.room = "workshop"
	state.baseline = {"gate":true,"exit":false,"units":[{"id":"p2_sentry_01","health":0,"position":[3262.6,1290.5]}]}
	check(FLOW.save(PATH,{},state)==OK,"Extended journey writes through the original atomic save interface")
	var read := SAVE.read_save(PATH)
	check(FLOW.sanitize(read.get("spine_flow",{})).room == "workshop" and read.spine_flow.assembled and not read.spine_flow.calibrated and read.spine_flow.baseline.gate and read.spine_flow.baseline.units[0].health==0 and not read.get("scatter_unlocked",true),"Knowledge, pending calibration and committed room baseline survive disk round trip")
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = PATH
	title.settings_path = "user://test_spine_flow_settings.cfg"
	root.add_child(title)
	current_scene = title
	title._continue_journey()
	var until := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<until:
		await process_frame
		if current_scene != null and current_scene.scene_file_path=="res://scenes/gameplay/spine_workshop_visit.tscn" and current_scene.visit_ready and not paused and not root.has_node("EntryLoading"): break
	check(current_scene.scene_file_path=="res://scenes/gameplay/spine_workshop_visit.tscn","Continue resumes the actual pending abdomen workshop, not the spine entrance")
	if current_scene.scene_file_path=="res://scenes/gameplay/spine_workshop_visit.tscn":
		check(current_scene.calibration_active and not current_scene.player.scatter_unlocked,"Interrupted manufacture resumes trial, never grants an uncalibrated ability")
		var workshop = current_scene
		workshop.player.global_position = workshop.calibration_stand
		workshop.player.health = 2
		paused = true
		check(workshop._save_journey()==OK,"Interrupted calibration saves a real version-2 workshop snapshot")
		var saved := SAVE.read_save(PATH)
		check(saved.get("version")==2 and SAVE.resume_scene(saved)==SAVE.SCENE,"Workshop snapshot owns the abdomen scene, never the previous spine scene")
		workshop.queue_free()
		await process_frame
		paused = false
		title = load("res://scenes/main.tscn").instantiate()
		title.game_save_path = PATH
		title.settings_path = "user://test_spine_flow_settings.cfg"
		root.add_child(title)
		current_scene = title
		title._continue_journey()
		until = Time.get_ticks_msec()+90000
		while Time.get_ticks_msec()<until:
			await process_frame
			if current_scene.scene_file_path=="res://scenes/gameplay/spine_workshop_visit.tscn" and current_scene.visit_ready and not paused and not root.has_node("EntryLoading"): break
		check(current_scene.player.health==2 and current_scene.player.global_position.distance_to(current_scene._duct_landing(&"duct_arrival"))<0.01,"Workshop continue resumes at the duct landing with saved health")
		check(current_scene.calibration_active and not current_scene.player.scatter_unlocked and current_scene.calibration_targets.size()==2,"Resume regenerates two calibration contacts without granting the ability")
	current_scene.queue_free()
	await process_frame
	SAVE.erase(PATH)
	var index := 0
	for path in [SAVE.DEFAULT_PATH,"user://achievements.cfg","user://settings.cfg"]:
		var now := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		check(now==personal[index],"Personal file preserved: "+path)
		index += 1
	print("SPINE FLOW PERSISTENCE: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
