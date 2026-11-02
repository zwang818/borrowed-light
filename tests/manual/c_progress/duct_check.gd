extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)
func interact(level: Node, id: StringName) -> void:
	level.player.global_position = level.ducts[id].point.global_position + Vector2(0, 20)
	await physics_frame
	level._try_interact()
func run() -> void:
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = "user://test_ducts.cfg"
	root.add_child(level)
	current_scene = level
	await create_timer(0.15).timeout
	check(level.ducts.size() == 3 and level.unlocked_ducts.is_empty(), "Three initially locked ducts")
	await interact(level, &"duct_arrival")
	check(paused and level.pending_interaction == &"duct_arrival", "E opens unlock confirmation")
	level.finish_interaction(level.interaction_token, false)
	await process_frame
	check(level.unlocked_ducts.is_empty(), "Cancel does not unlock")
	await interact(level, &"duct_arrival")
	level.interaction_sheet._finish(true)
	await process_frame
	check(level.unlocked_ducts.size() == 1, "Unlock affects current duct only")
	await interact(level, &"duct_arrival")
	var origin: Vector2 = level.player.global_position
	level._travel_duct(level.interaction_token, &"duct_exit")
	check(level.player.global_position == origin, "Locked destination cannot be used")
	check(level.ducts[&"duct_arrival"].visual.is_open, "Unlocked hatch visibly opens")
	level.finish_interaction(level.interaction_token, false)
	await process_frame
	check(not level.ducts[&"duct_arrival"].visual.is_open, "Close menu closes hatch")
	await interact(level, &"duct_weapon")
	level.interaction_sheet._finish(true)
	await process_frame
	await interact(level, &"duct_arrival")
	var old_token: int = level.interaction_token
	# Destination buttons must omit locked points and source itself.
	var buttons: Array[Node] = level.interaction_sheet.panel.find_children("*", "Button", true, false)
	var route_button: Button
	for button in buttons:
		check(not button.text.contains("终端区"), "Locked destination stays hidden")
		if button.text.contains("前往"):
			route_button = button
	check(route_button != null, "Unlocked destination appears as actionable choice")
	var blocker := StaticBody2D.new()
	blocker.position = level.ducts[&"duct_weapon"].point.global_position
	blocker.collision_layer = 4
	var blocker_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 120
	blocker_shape.shape = circle
	blocker.add_child(blocker_shape)
	level.add_child(blocker)
	await physics_frame
	level._travel_duct(level.interaction_token, &"duct_weapon")
	check(level.player.global_position == origin and paused, "Occupied destination is rejected without moving player")
	blocker.queue_free()
	await process_frame
	await physics_frame
	if route_button != null:
		route_button.pressed.emit()
	await process_frame
	check(not paused and level.player.global_position.distance_to(level.ducts[&"duct_weapon"].point.global_position) < 70, "Destination button performs teleport")
	check(level.game_menus.achievements.get("duct_traveler", false), "Actual travel awards narrow subway achievement")
	check(not level.game_menus.achievements.get("duct_network", false), "Two unlocked ducts are not full network")
	check(not level.terminal_activated and not level.is_level_complete, "Shortcut does not activate terminal or finish level")
	var after: Vector2 = level.player.global_position
	level._travel_duct(old_token, &"duct_exit")
	check(level.player.global_position == after, "Stale callback cannot teleport")
	level._retry_level()
	check(level.unlocked_ducts.size() == 2, "Retry retains unlocked shortcuts")
	await process_frame
	await interact(level, &"duct_weapon")
	level._travel_duct(level.interaction_token, &"duct_arrival")
	await process_frame
	check(level.player.global_position.distance_to(level.ducts[&"duct_arrival"].point.global_position) < 70, "Travel works in reverse")
	await interact(level, &"duct_exit")
	level.interaction_sheet._finish(true)
	await process_frame
	check(level.game_menus.achievements.get("duct_network", false), "Third unlocked duct awards full network achievement")
	level.queue_free()
	await process_frame
	if FileAccess.file_exists("user://test_ducts.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ducts.cfg"))
	print("DUCT CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
