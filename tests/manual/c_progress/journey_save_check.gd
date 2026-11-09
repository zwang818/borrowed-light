extends SceneTree
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const PATH := "user://test_journey_save.json"
var failures: Array[String] = []
func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)
func run() -> void:
	SAVE.erase(PATH)
	check(SAVE.read_save(PATH).is_empty(), "No fake continue for empty slot")
	var data := {"blueprint_known": true, "pulse_learned": true, "workshop_seen": false,
		"ducts": ["duct_arrival", "duct_weapon"], "explored": [[320, 2500], [432, 1924]]}
	check(SAVE.write_save(PATH, data) == OK, "Checkpoint is written")
	check(SAVE.read_save(PATH).pulse_learned, "Knowledge survives disk reload")
	data.workshop_seen = true
	check(SAVE.write_save(PATH, data) == OK, "Overwrite preserves readable backup")
	var corrupt := FileAccess.open(PATH, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	var recovered := SAVE.read_save(PATH)
	check(recovered.get("recovered", false) and not recovered.workshop_seen, "Corrupt main recovers previous checkpoint")
	check(SAVE.write_save(PATH, recovered) == OK, "Recovered checkpoint can be saved again")
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = PATH
	root.add_child(title)
	current_scene = title
	await process_frame
	check(title.start_button.text == "继续游戏", "Title shows real continue when valid data exists")
	title._open_archive()
	title._new_button.pressed.emit()
	check(title._archive_action == "new" and SAVE.read_save(PATH).pulse_learned, "New journey requires confirmation and does not erase current data")
	title._close_archive()
	check(title._archive_action.is_empty(), "Closing cancels overwrite confirmation")
	title._open_archive()
	title._delete_button.pressed.emit()
	check(not SAVE.read_save(PATH).is_empty(), "First delete click does not erase")
	title._close_archive()
	title._open_archive()
	title._load_button.pressed.emit()
	check(paused and root.has_node("EntryLoading"), "Archive read uses loading transition")
	# Restoring the learned arm also initializes its shared visual resources.
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and current_scene != null and current_scene.scene_file_path == SAVE.SCENE:
			break
	check(current_scene != null and current_scene.scene_file_path == SAVE.SCENE and not paused, "Continue opens gameplay directly: scene=%s paused=%s loading=%s" % [current_scene.scene_file_path if current_scene != null else "none", paused, root.has_node("EntryLoading")])
	if current_scene != null and current_scene.scene_file_path == SAVE.SCENE:
		var level = current_scene
		level.achievement_save_path = "user://test_journey_achievements.cfg"
		level.game_menus.achievement_save_path = level.achievement_save_path
		check(level.pulse_learned and level.player.pulse_gun_equipped, "Learned ability restored without repeating manufacture")
		check(level.unlocked_ducts.size() == 2 and level.explored_positions.size() >= 2, "Duct knowledge and exploration restored")
		check(not level.terminal_activated and level._remaining_cleaners() == 3, "World returns to room baseline")
		check(level.player.global_position.distance_to(level._find_spawn_position()) < 1 and level.player.health == level.player.max_health, "Continue uses safe entry and room retry health")
		level.explored_positions.append(Vector2(600, 1200))
		level.game_menus.toggle_pause()
		for action in level.game_menus._content.find_children("*", "Button", true, false):
			if action.text == "保存游戏":
				action.pressed.emit()
				break
		check(not paused and SAVE.read_save(PATH).explored.size() >= 3, "Pause save button persists current exploration and resumes")
		level.player.global_position = level.interaction_points[&"workshop_origin"].global_position + Vector2(0, 24)
		await physics_frame
		level._try_interact()
		for _line in level.interaction_sheet.dialogue.size():
			level.interaction_sheet._advance_or_finish()
		await process_frame
		check(SAVE.read_save(PATH).workshop_seen, "Completing a real story interaction automatically saves knowledge")
		level._return_to_title()
		await process_frame
		await process_frame
		title = current_scene
		title.game_save_path = PATH
		title._open_archive()
		title._delete_button.pressed.emit()
		title._delete_button.pressed.emit()
		check(SAVE.read_save(PATH).is_empty() and not FileAccess.file_exists(PATH + ".bak"), "Confirmed delete clears checkpoint and backup")
		check(title.start_button.text == "开始游戏" and title._load_button.disabled, "Deleting refreshes empty title state")
	current_scene.queue_free()
	await process_frame
	SAVE.erase(PATH)
	if FileAccess.file_exists("user://test_journey_achievements.cfg"):
		DirAccess.remove_absolute("user://test_journey_achievements.cfg")
	print("JOURNEY SAVE CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
