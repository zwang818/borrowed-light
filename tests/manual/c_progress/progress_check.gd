extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)


func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	root.push_input(event, true)


func button(menu: Node, text: String) -> Button:
	for item in menu._content.get_children():
		if item is Button and item.text == text:
			return item
	return null


func run_checks() -> void:
	var scene := load("res://scenes/gameplay/abdomen_level.tscn") as PackedScene
	var level = scene.instantiate()
	root.add_child(level)
	current_scene = level
	await create_timer(0.15).timeout
	var enemy = level.enemies[0]
	var player = level.player
	var menus = level.game_menus
	check(not paused and player.can_process() and enemy.can_process(), "Gameplay runs before pause")
	player.pulse_gun_equipped = true
	level.pulse_learned = true
	player.pulse_gun.request_fire(Vector2.RIGHT)
	player.invulnerability_remaining = 0.4
	var projectile = load("res://scenes/weapons/enemy_projectile.tscn").instantiate()
	level.bullets_parent.add_child(projectile)
	projectile.position = Vector2(-1000, -1000)
	escape()
	check(paused and menus.page == menus.Page.PAUSE, "Esc opens pause menu")
	var pause_labels := []
	for action in menus._content.find_children("*", "Button", true, false):
		pause_labels.append(action.text)
	check(pause_labels == ["继续游戏", "重试本房间", "成就手册", "返回首页"],
		"Pause menu has the four actions in the intended order")
	check(not enemy.can_process() and not player.can_process() and menus.can_process(), "World pauses while menu remains active")
	var before_position: Vector2 = enemy.global_position
	var before_projectile: Vector2 = projectile.global_position
	var before_remaining: float = player.pulse_gun.remaining
	var before_invulnerability: float = player.invulnerability_remaining
	var before_health: int = player.health
	await create_timer(0.3, true).timeout
	check(enemy.global_position == before_position, "Enemy position stays frozen")
	check(projectile.global_position == before_projectile, "Projectile stays frozen")
	check(player.pulse_gun.remaining == before_remaining, "Weapon timer stays frozen")
	check(player.invulnerability_remaining == before_invulnerability and player.health == before_health, "Player health and timer stay frozen")
	button(menus, "成就手册").pressed.emit()
	await process_frame
	check(menus.page == menus.Page.ACHIEVEMENTS and paused, "Achievement page keeps world paused")
	escape()
	await process_frame
	check(menus.page == menus.Page.PAUSE and paused, "Esc returns to pause menu")
	escape()
	await create_timer(0.12).timeout
	check(not paused and player.pulse_gun.remaining < before_remaining, "Esc resumes gameplay timers")
	check(not is_instance_valid(projectile) or projectile.global_position != before_projectile, "Projectile resumes movement")
	player.pulse_gun.cancel()
	escape()
	await create_timer(0.05, true).timeout
	var resume := button(menus, "继续游戏")
	var location := resume.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = location
	motion.global_position = location
	root.push_input(motion, true)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = location
	mouse.global_position = location
	mouse.pressed = true
	root.push_input(mouse, true)
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = location
	mouse.global_position = location
	mouse.pressed = false
	root.push_input(mouse, true)
	await create_timer(0.05, true).timeout
	check(not paused, "Continue button responds to real mouse events")
	check(player.pulse_gun.state == player.pulse_gun.State.IDLE, "Continue click does not trigger weapon fire")
	if paused:
		menus.close_and_resume()
	enemy.global_position += Vector2(11, 17)
	player.invulnerability_remaining = 0
	player.apply_damage(player.max_health)
	check(paused and menus.page == menus.Page.DEATH, "Death opens menu and freezes world")
	await create_timer(0.1, true).timeout
	check(player.is_dead, "Death waits for a player choice")
	button(menus, "重试").pressed.emit()
	check(not paused and not player.is_dead and player.health == player.max_health, "Retry restores living player")
	check(player.pulse_gun_equipped, "REV-14: retry preserves learned pulse ability")
	check(enemy.global_position == level.enemy_baselines[enemy.entity_id].position, "Retry restores enemy baseline position")
	await process_frame
	check(level.bullets_parent.get_child_count() == 0, "Retry clears old projectiles")
	for label in level.hud_canvas.find_children("*", "Label", true, false):
		check(not label.text.contains("WASD") and not label.text.contains("目标方向"), "HUD has no controls or navigation card")
	var menu_script = load("res://scenes/gameplay/game_menus.gd")
	check(menus.unlock_achievement("first_weapon"), "Achievement unlocks once")
	check(not menus.unlock_achievement("first_weapon"), "Duplicate achievement is ignored")
	var reloaded = menu_script.new()
	root.add_child(reloaded)
	check(reloaded.achievements.get("first_weapon", false), "Achievement survives menu recreation")
	reloaded.queue_free()
	escape()
	await process_frame
	button(menus, "返回首页").pressed.emit()
	var home_loading = root.get_node_or_null("EntryLoading")
	check(paused and home_loading != null, "Return Home opens loading while the room stays paused")
	if home_loading != null:
		check(home_loading.background.texture.resource_path == "res://assets/loading/abdomen_workshop.png",
			"Returning from the first level shows the abdomen card")
		await home_loading.tree_exited
	check(not paused and current_scene.scene_file_path == "res://scenes/main.tscn", "Return to title clears pause")
	current_scene.game_save_path = "user://test_c_progress_journey.json"
	preload("res://scenes/gameplay/journey_save.gd").erase(current_scene.game_save_path)
	current_scene._on_start_pressed()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == "res://scenes/ui/intro_cutscene/intro_cutscene.tscn", "New game enters updated intro after returning to title")
	current_scene._finish()
	check(paused and root.has_node("EntryLoading"), "Intro opens loading overlay and blocks gameplay input")
	current_scene._finish()
	check(root.get_children().filter(func(node: Node): return node.get_script() == preload("res://scenes/ui/intro_cutscene/entry_loading.gd")).size() == 1, "Duplicate entry request keeps a single loading overlay")
	# Allow cold visual/resource initialization; the loading UI stays up until ready.
	var deadline := Time.get_ticks_msec() + 30000
	var active_loading = root.get_node("EntryLoading")
	var previous_fill := 0.0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(active_loading):
			check(active_loading.fill.size.x + 0.001 >= previous_fill, "Loading bar never resets backwards")
			previous_fill = active_loading.fill.size.x
			if current_scene != null and current_scene.scene_file_path != "res://scenes/gameplay/abdomen_level.tscn":
				check(previous_fill <= 108.001, "Loading bar cannot finish before gameplay exists")
		if not paused and current_scene != null and current_scene.scene_file_path == "res://scenes/gameplay/abdomen_level.tscn":
			break
	check(not paused and current_scene.scene_file_path == "res://scenes/gameplay/abdomen_level.tscn", "Intro leads back into gameplay")
	preload("res://scenes/gameplay/journey_save.gd").erase("user://test_c_progress_journey.json")
	print("RESTORE CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
