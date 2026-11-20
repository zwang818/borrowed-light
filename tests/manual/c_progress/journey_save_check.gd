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
func menu_labels(title: Control) -> Array[String]:
	var labels: Array[String] = []
	for child in title.start_button.get_parent().get_children():
		if child is Button and child.visible:
			labels.append(child.text)
	return labels
func wait_for_room(path: String = SAVE.SCENE) -> bool:
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and current_scene != null and current_scene.scene_file_path == path and not root.has_node("EntryLoading"):
			return true
	return false
func run() -> void:
	SAVE.erase(PATH)
	check(SAVE.read_save(PATH).is_empty(), "No fake continue for empty slot")
	var empty_title = load("res://scenes/main.tscn").instantiate()
	empty_title.game_save_path = PATH
	root.add_child(empty_title)
	current_scene = empty_title
	await process_frame
	check(menu_labels(empty_title) == ["开始旅程", "设置", "退出"], "First visit exposes start, settings and quit")
	check(not empty_title.has_node("Presentation/SpineReviewButton"), "Default title keeps review shortcut out of the player menu")
	empty_title.queue_free()
	await process_frame
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
	check(menu_labels(title) == ["继续旅程", "重新开始旅程", "设置", "退出"], "Readable save exposes continue, restart and quit")
	title._open_archive()
	check(title.restart_button.focus_mode == Control.FOCUS_NONE, "Archive modal excludes restart from background navigation")
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
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and current_scene != null and current_scene.scene_file_path == SAVE.SCENE:
			break
	check(current_scene != null and current_scene.scene_file_path == SAVE.SCENE and not paused, "Continue opens gameplay directly: scene=%s paused=%s loading=%s" % [current_scene.scene_file_path if current_scene != null else "none", paused, root.has_node("EntryLoading")])
	if current_scene != null and current_scene.scene_file_path == SAVE.SCENE:
		var level = current_scene
		check(level.pulse_learned and level.player.pulse_gun_equipped, "Learned ability restored without repeating manufacture")
		check(level.pulse_assembly_gate.get_meta("is_open") and level.pulse_assembly_gate.collision_layer == 0,
			"Continuing an older save with the laser opens the assembly gate")
		check(level.unlocked_ducts.size() == 2 and level.explored_positions.size() >= 2, "Duct knowledge and exploration restored")
		check(not level.terminal_activated and level._remaining_cleaners() == 4, "World returns to room baseline")
		check(level.player.global_position.distance_to(level._find_spawn_position()) < 1 and level.player.health == level.player.max_health, "Continue uses safe entry and room retry health")
		level.explored_positions.append(Vector2(600, 1200))
		level.player.global_position = level.interaction_points[&"workshop_origin"].global_position + Vector2(0, 24)
		await physics_frame
		level._try_interact()
		for _line in level.interaction_sheet.dialogue.size():
			level.interaction_sheet._advance_or_finish()
		await process_frame
		check(SAVE.read_save(PATH).workshop_seen, "Completing a real story interaction automatically saves knowledge")
		check(SAVE.read_save(PATH).explored.size() >= 3, "Automatic save also persists current exploration")
		check(level.game_menus.achievements.get("workshop_reader", false), "Story interaction awards the journey achievement")
		level._return_to_title()
		check(await wait_for_room("res://scenes/main.tscn"), "Story save can return home through loading")
		title = current_scene
		title.game_save_path = PATH
		title._refresh_archive()
		var before_restart := FileAccess.get_file_as_bytes(PATH)
		title.restart_button.pressed.emit()
		check(title.restart_overlay.visible and not title._is_starting, "Restart opens confirmation without starting or deleting")
		check(root.gui_get_focus_owner() == title.restart_cancel, "Restart initially focuses safe return action")
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		root.push_input(escape, true)
		check(not title.restart_overlay.visible and before_restart == FileAccess.get_file_as_bytes(PATH), "Escape cancels restart and keeps saved bytes")
		title.restart_button.pressed.emit()
		title.restart_cancel.pressed.emit()
		check(not title.restart_overlay.visible and not title._is_starting, "Return button also cancels restart")
		title._continue_journey()
		check(await wait_for_room(), "Continuing after cancelled restart reaches the current journey")
		level = current_scene
		check(level.game_menus.achievements.get("workshop_reader", false), "Continuing in the same process preserves achievements")
		level._return_to_title()
		check(await wait_for_room("res://scenes/main.tscn"), "Continued journey can return home through loading")
		title = current_scene
		title.game_save_path = PATH
		title._refresh_archive()
		before_restart = FileAccess.get_file_as_bytes(PATH)
		title.restart_button.pressed.emit()
		title.restart_confirm.pressed.emit()
		await process_frame
		await process_frame
		check(current_scene.scene_file_path == "res://scenes/ui/intro_cutscene/intro_cutscene.tscn", "Confirmed restart replays the real opening")
		check(before_restart == FileAccess.get_file_as_bytes(PATH) and not get_meta("journey_session").has("data"), "Restart passes a fresh session and keeps old save until safe gameplay arrival")
		current_scene._finish()
		check(await wait_for_room(), "Restart opening loads a playable first-level entry")
		level = current_scene
		check(not level.pulse_learned and not level.blueprint_known and level.unlocked_ducts.is_empty() and not level.first_level_cleared, "Restart resets abilities, clues, ducts and level progress")
		check(not SAVE.read_save(PATH).pulse_learned and SAVE.read_save(PATH).scene == SAVE.SCENE, "New first-level checkpoint replaces previous journey")
		check(level.game_menus.achievements.is_empty(), "Confirmed new journey resets completed achievements")
		check(level.game_menus.unlock_achievement("workshop_reader"), "The same achievement can unlock again on the new journey")
		level._return_to_title()
		check(await wait_for_room("res://scenes/main.tscn"), "New journey can return home through loading")
		title = current_scene
		title.game_save_path = PATH
		title._open_archive()
		title._delete_button.pressed.emit()
		title._delete_button.pressed.emit()
		check(SAVE.read_save(PATH).is_empty() and not FileAccess.file_exists(PATH + ".bak"), "Confirmed delete clears checkpoint and backup")
		check(menu_labels(title) == ["开始旅程", "设置", "退出"] and title._load_button.disabled, "Deleting restores two-button first-visit menu")
	current_scene.queue_free()
	await process_frame
	SAVE.erase(PATH)
	print("JOURNEY SAVE CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
