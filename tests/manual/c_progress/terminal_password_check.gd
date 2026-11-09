extends SceneTree
## Real keypad input, clue reads, gate boundaries and retry knowledge separation.
const SAVE := "user://test_terminal_password.cfg"
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func press_key(keycode: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.unicode = unicode
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func approach(level: Node, target: Node2D) -> void:
	level.player.global_position = target.global_position + Vector2(0, 40 if target == level.terminal else 24)
	await physics_frame
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func finish_story(level: Node) -> void:
	for _line in level.interaction_sheet.dialogue.size():
		level.interaction_sheet._advance_or_finish()
	await process_frame

func run_checks() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = SAVE
	root.add_child(level)
	current_scene = level
	await create_timer(0.15).timeout
	level.player.set_physics_process(false)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	await approach(level, level.terminal)
	check(not paused and level.pending_interaction.is_empty(), "Living cleaners prevent opening terminal UI")
	await approach(level, level.interaction_points[&"pulse_blueprint"])
	level.interaction_sheet._advance_or_finish()
	level._toggle_pause()
	await process_frame
	check(level.terminal_clues.is_empty(), "Canceled clue dialogue does not record knowledge")
	await approach(level, level.interaction_points[&"pulse_blueprint"])
	check(str(level.interaction_sheet.dialogue).contains("04"), "Blueprint room contains first labeled fragment")
	await finish_story(level)
	check(level.terminal_clues.get(&"pulse_blueprint") == "04", "Completed reading records first fragment")
	await approach(level, level.interaction_points[&"workshop_origin"])
	check(str(level.interaction_sheet.dialogue).contains("17"), "Side room contains second labeled fragment")
	await finish_story(level)
	check(level.terminal_clues.size() == 2, "Both other-room records remain known")
	var snapshot: Dictionary = level.get_interaction_state()
	snapshot.terminal_clues.clear()
	check(level.terminal_clues.size() == 2, "Presenter cannot mutate clue knowledge through snapshot")
	for enemy in level.enemies:
		enemy.apply_damage(999)
	await physics_frame
	var exit_door = level.interactables_parent.get_node("Door_p1_door_01")
	await approach(level, level.terminal)
	var sheet = level.interaction_sheet
	var old_token: int = level.interaction_token
	check(paused and not level.terminal_activated and exit_door.collision_layer == 1, "Clearing cleaners opens entrance but code still guards exit")
	await create_timer(0.05, true).timeout
	# canvas_items uses logical viewport units; headless can differ from Window.size.
	check(root.get_visible_rect().encloses(sheet.panel.get_global_rect()), "Keypad fits logical viewport")
	check(sheet._code_input.text.is_empty(), "Opening E does not type or submit a code")
	root.size = Vector2i(960, 540)
	await create_timer(0.05, true).timeout
	check(root.get_visible_rect().encloses(sheet.panel.get_global_rect()), "Keypad fits viewport after smaller window request")
	root.size = Vector2i(1152, 648)
	check(not level.enemies[0].can_process() and not level.player.can_process(), "Password reading freezes world")
	sheet._advance_or_finish()
	check(sheet._code_status.text.contains("完整") and not level.terminal_activated, "Empty input cannot activate")
	# Keyboard uses actual focused LineEdit event handling; leading zero is retained.
	await press_key(KEY_0, 48)
	await press_key(KEY_A, 97)
	await press_key(KEY_1, 49)
	check(sheet._code_input.text == "01", "Keyboard accepts ASCII digits only and retains leading zero: %s" % sheet._code_input.text)
	sheet._advance_or_finish()
	check(not level.terminal_activated and paused, "Short password cannot activate")
	sheet._type_code("清空")
	for digit in "9999":
		sheet._type_code(digit)
	# Exercise the actual verification button signal.
	sheet._confirm.pressed.emit()
	check(sheet._code_status.text.contains("不匹配") and paused and exit_door.collision_layer == 1, "Wrong password stays open with retry feedback")
	sheet._type_code("退格")
	check(sheet._code_input.text.is_empty(), "Backspace clears selected wrong entry")
	check(not level.game_menus.achievements.get("first_terminal", false), "Failed attempts grant no achievement")
	level._toggle_pause()
	await process_frame
	level._submit_terminal_code(old_token, level.TERMINAL_CODE)
	check(not level.terminal_activated and not paused, "Canceled request rejects late correct submission")
	await approach(level, level.terminal)
	level._submit_terminal_code(old_token, level.TERMINAL_CODE)
	check(paused and not level.terminal_activated, "New request rejects previous token")
	level.finish_interaction(level.interaction_token, true)
	await process_frame
	check(not level.terminal_activated and exit_door.collision_layer == 1, "Generic story callback cannot bypass password")
	await approach(level, level.terminal)
	for digit in "9999":
		sheet._type_code(digit)
	sheet._confirm.pressed.emit()
	for digit in level.TERMINAL_CODE:
		for button in sheet.overlay.find_children("*", "Button", true, false):
			if button.text == digit:
				button.pressed.emit()
	check(sheet._code_input.text == level.TERMINAL_CODE, "Keypad replaces selected wrong entry and preserves leading zero: %s" % sheet._code_input.text)
	sheet._type_code("退格")
	check(sheet._code_input.text == "041", "Keypad backspace deletes last digit")
	sheet._type_code("7")
	# Optional real render capture before activation, outside repository.
	var capture := OS.get_environment("C_TERMINAL_PREVIEW_PATH")
	if DisplayServer.get_name() != "headless" and not capture.is_empty():
		# Let transient achievements from the accelerated clue reads finish first.
		await create_timer(4.0, true).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture)
	await press_key(KEY_ENTER)
	await process_frame
	check(level.terminal_activated and not paused and exit_door.collision_layer == 0, "Enter submits correct password and opens exit")
	check(level.game_menus.achievements.get("first_terminal", false), "Verified activation grants terminal achievement")
	level._retry_level()
	await process_frame
	check(not level.terminal_activated and exit_door.collision_layer == 1 and level.terminal_gate.collision_layer == 1, "Retry resets terminal and both doors")
	check(level.terminal_clues.size() == 2, "Retry preserves read clues independently of world state")
	level._submit_terminal_code(level.interaction_token, level.TERMINAL_CODE)
	check(not level.terminal_activated, "Old successful callback cannot reopen terminal after retry")
	await approach(level, level.interaction_points[&"workshop_origin"])
	check(str(sheet.dialogue).contains("17"), "Known clue remains rereadable after retry")
	level._toggle_pause()
	await process_frame
	level.queue_free()
	await process_frame
	var fresh = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	fresh.achievement_save_path = SAVE
	root.add_child(fresh)
	await physics_frame
	fresh.player.set_physics_process(false)
	check(fresh.terminal_clues.is_empty() and not fresh.terminal_activated, "New level starts without old clues or authorization")
	for enemy in fresh.enemies:
		enemy.apply_damage(999)
	await physics_frame
	await approach(fresh, fresh.terminal)
	for digit in fresh.TERMINAL_CODE:
		fresh.interaction_sheet._type_code(digit)
	fresh.interaction_sheet._confirm.pressed.emit()
	await process_frame
	check(fresh.terminal_activated, "A remembered correct password works without artificial read-flag gating")
	fresh.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("TERMINAL PASSWORD CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
