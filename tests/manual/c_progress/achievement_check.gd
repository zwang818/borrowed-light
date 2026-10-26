extends SceneTree

const SAVE := "user://test_c_ui_achievements.cfg"
var failures: Array[String] = []


func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)


func run_checks() -> void:
	var font: FontFile = load("res://scenes/gameplay/gameplay_ui_theme.tres").default_font
	check(not font.allow_system_fallback, "Product text uses bundled font without system fallback")
	var glyphs: Dictionary = {}
	for source in ["abdomen_level.gd", "game_menus.gd", "achievement_toasts.gd"]:
		for character in FileAccess.get_file_as_string("res://scenes/gameplay/" + source):
			var codepoint: int = character.unicode_at(0)
			if codepoint >= 32:
				glyphs[codepoint] = true
	for codepoint in glyphs:
		check(font.has_char(codepoint), "Bundled font covers U+%04X" % codepoint)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var script = load("res://scenes/gameplay/game_menus.gd")
	var menus = script.new()
	menus.achievement_save_path = SAVE
	root.add_child(menus)
	await process_frame
	await process_frame
	var toasts = root.get_node("AchievementNotifications")
	toasts.display_seconds = 0.04
	check(menus.unlock_achievement("first_weapon"), "First achievement unlocks")
	check(not paused and toasts._active_id == "first_weapon", "Toast appears without pausing game")
	check(menus.unlock_achievement("first_terminal"), "Second achievement unlocks")
	check(toasts._queue.size() == 1, "Simultaneous achievements queue")
	check(not menus.unlock_achievement("first_weapon"), "Duplicate unlock ignored")
	check(not menus.unlock_achievement("invalid"), "Invalid achievement ignored")
	check(toasts._queue.size() == 1, "Duplicates do not add notifications")
	for control in toasts._host.find_children("*", "Control", true, false):
		check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Toast does not block input")
	await create_timer(0.55, true).timeout
	check(toasts._active_id == "first_terminal", "Queue advances to second achievement")
	await create_timer(0.55, true).timeout
	check(toasts._active_id.is_empty() and not toasts._card.visible, "Notifications dismiss after display")
	menus.toggle_pause()
	menus._show_page(menus.Page.ACHIEVEMENTS)
	await process_frame
	check(paused and menus._manual_list.get_child_count() == 4, "Handbook lists locked and unlocked entries")
	check(menus._manual_summary.text.contains("2 / 4"), "Completion summary counts actual unlocks")
	var filter = menus._content.find_children("*", "OptionButton", true, false)[0]
	filter.select(1)
	filter.item_selected.emit(1)
	check(menus._manual_list.get_child_count() == 2, "Locked filter lists remaining achievements")
	var search = menus._content.find_children("*", "LineEdit", true, false)[0]
	search.text = "出口"
	search.text_changed.emit("出口")
	check(menus._manual_list.get_child_count() == 1, "Search matches completion conditions")
	check(menus._manual_list.find_children("*", "Label", true, false)[0].text.contains("继续前行"), "Search finds correct locked achievement")
	search.text = "不存在的名称"
	search.text_changed.emit(search.text)
	check(menus._manual_list.get_child(0).text == "没有符合条件的成就", "Search shows empty state")
	search.text = ""
	search.text_changed.emit("")
	filter.select(2)
	filter.item_selected.emit(2)
	check(menus._manual_list.get_child_count() == 2, "Unlocked filter lists completed achievements")
	check(menus.unlock_achievement("first_clear"), "Unlock while handbook open")
	check(menus._manual_list.get_child_count() == 3 and menus._manual_summary.text.contains("3 / 4"), "Handbook refreshes without resetting filters")
	menus.close_and_resume()
	menus.queue_free()
	await process_frame
	check(is_instance_valid(toasts) and toasts._active_id == "first_clear", "Toast survives owning scene removal")
	var reloaded = script.new()
	reloaded.achievement_save_path = SAVE
	root.add_child(reloaded)
	check(reloaded._completed_count() == 3, "Save reload preserves achievements")
	check(not reloaded.unlock_achievement("first_clear"), "Reloaded unlock does not replay toast")
	check(toasts._queue.is_empty(), "Loading save adds no notifications")
	reloaded.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("ACHIEVEMENT CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
