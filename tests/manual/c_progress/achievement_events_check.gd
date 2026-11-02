extends SceneTree
const SAVE := "user://test_c_achievement_events.cfg"
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)
func run() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = SAVE
	root.add_child(level)
	current_scene = level
	await create_timer(0.15).timeout
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	var menus = level.game_menus
	check(level.achievement_webs.size() == 10, "Only ten indoor webs count")
	var environment = level.map.get_node("Environment")
	for web in environment.webs:
		if web.background_region.has_area():
			web.apply_damage(1)
			break
	check(not menus.achievements.get("first_web", false), "Background decoration does not award indoor web achievement")
	var first = level.achievement_webs[0]
	first.apply_damage(0)
	check(menus.achievement_progress["web_sweeper"].x == 0, "Zero damage does not count")
	first.apply_damage(1)
	first.apply_damage(1)
	check(menus.achievements.get("first_web", false) and menus.achievement_progress["web_sweeper"].x == 1, "Repeated hits count a web once")
	level._retry_level()
	check(menus.achievement_progress["web_sweeper"].x == 0 and not menus.achievements.get("web_sweeper", false), "Retry clears partial room challenge progress")
	check(not menus.achievements.get("first_retry", false), "Voluntary retry is not a death achievement")
	for i in range(9):
		level.achievement_webs[i].apply_damage(1)
	check(not menus.achievements.get("web_sweeper", false), "Nine out of ten cannot award full clear")
	level.achievement_webs[9].apply_damage(1)
	check(menus.achievements.get("web_sweeper", false), "Final indoor web awards man achievement")
	check(menus.achievement_progress["web_sweeper"] == Vector2i(10, 10), "Handbook receives exact full-clear progress")
	level.player.apply_damage(1)
	for enemy in level.enemies:
		enemy.apply_damage(999)
	check(not menus.achievements.get("clean_clear", false), "Damaged attempt cannot award no-hit clear")
	level.player.invulnerability_remaining = 0
	level.player.apply_damage(999)
	level._retry_level()
	check(menus.achievements.get("first_retry", false), "Death followed by retry awards reboot achievement")
	check(menus.achievements.get("web_sweeper", false), "Unlocked achievements survive room reset")
	for enemy in level.enemies:
		enemy.apply_damage(999)
	check(menus.achievements.get("clean_clear", false), "Fresh no-hit attempt can award clean clear")
	check(not menus.unlock_achievement("web_sweeper"), "Previously unlocked full clear does not notify again")
	var reader = load("res://scenes/gameplay/game_menus.gd").new()
	reader.achievement_save_path = SAVE
	root.add_child(reader)
	check(reader.achievements.get("web_sweeper", false) and reader.achievements.get("first_retry", false), "New achievements persist to disk")
	check(not reader.unlock_achievement("web_sweeper"), "Reload never replays unlocked achievement")
	reader.queue_free()
	level.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("ACHIEVEMENT EVENTS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
