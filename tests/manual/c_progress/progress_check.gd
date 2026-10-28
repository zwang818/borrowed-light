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
	player.pulse_gun.request_fire(Vector2.RIGHT)
	player.invulnerability_remaining = 0.4
	var projectile = load("res://scenes/weapons/enemy_projectile.tscn").instantiate()
	level.bullets_parent.add_child(projectile)
	projectile.position = Vector2(-1000, -1000)
	escape()
	check(paused and menus.page == menus.Page.PAUSE, "Esc opens pause menu")
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
	button(menus, "重试本房间").pressed.emit()
	check(not paused and not player.is_dead and player.health == player.max_health, "Retry restores living player")
	check(not player.pulse_gun_equipped, "Retry preserves updated return-to-rack rule")
	check(enemy.global_position == level.enemy_baselines[enemy.entity_id].position, "Retry restores enemy baseline position")
	await process_frame
	check(level.bullets_parent.get_child_count() == 0, "Retry clears old projectiles")
	for label in level.hud_canvas.find_children("*", "Label", true, false):
		check(not label.text.contains("WASD") and not label.text.contains("目标方向"), "HUD has no controls or navigation card")
	var menu_script = load("res://scenes/gameplay/game_menus.gd")
	var isolated = menu_script.new()
	var save_path := "user://test_c_ui_regression.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	isolated.achievement_save_path = save_path
	root.add_child(isolated)
	check(isolated.unlock_achievement("first_weapon"), "Achievement unlocks once")
	check(not isolated.unlock_achievement("first_weapon"), "Duplicate achievement is ignored")
	var reloaded = menu_script.new()
	reloaded.achievement_save_path = save_path
	root.add_child(reloaded)
	check(reloaded.achievements.get("first_weapon", false), "Achievement survives reload")
	isolated.queue_free()
	reloaded.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	escape()
	await process_frame
	button(menus, "返回标题").pressed.emit()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == "res://scenes/main.tscn", "Return to title clears pause")
	current_scene._on_start_pressed()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == "res://scenes/ui/intro_cutscene/intro_cutscene.tscn", "New game enters updated intro after returning to title")
	current_scene._finish()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == "res://scenes/gameplay/abdomen_level.tscn", "Intro leads back into gameplay")
	print("RESTORE CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
