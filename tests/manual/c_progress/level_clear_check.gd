extends SceneTree
const SAVE := "user://test_spine_exit_achievements.cfg"
const PATH := "user://test_level_clear.json"
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)
func run() -> void:
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = SAVE
	level.journey_save_path = PATH
	root.add_child(level)
	current_scene = level
	await create_timer(0.15).timeout
	level.player.set_physics_process(false)
	level.player.global_position = level.final_exit.global_position
	await physics_frame
	await process_frame
	check(not level.is_level_complete and not root.has_node("EntryLoading"), "Exit remains locked before terminal activation")
	for enemy in level.enemies:
		enemy.apply_damage(999)
	level.player.global_position = level.terminal.global_position + Vector2(0, 40)
	await physics_frame
	level._try_interact()
	for digit in level.TERMINAL_CODE:
		level.interaction_sheet._type_code(digit)
	level.interaction_sheet._advance_or_finish()
	await process_frame
	check(level.terminal_activated, "Terminal password unlocks exit normally")
	level.player.global_position = level.final_exit.global_position + Vector2(0, 35)
	level._on_exit_entered(level.player.get_node("PlayerModelHurtbox"), level.final_exit.get_meta("exit_id"))
	await physics_frame
	check(not level.is_level_complete, "Head silhouette alone does not trigger transition")
	level.player.global_position = level.final_exit.global_position
	await physics_frame
	await process_frame
	check(level.is_level_complete and root.has_node("EntryLoading"), "Feet entering an already-overlapped exit starts loading")
	var loading = root.get_node_or_null("EntryLoading")
	if loading != null:
		level._on_exit_entered(level.player, level.final_exit.get_meta("exit_id"))
		check(root.get_node("EntryLoading") == loading, "Exit cannot create duplicate transitions")
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn":
			break
	check(not paused and current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "Level clear returns to title through loading")
	var save_script = preload("res://scenes/gameplay/journey_save.gd")
	check(save_script.read_save(PATH).get("first_level_cleared", false), "Clear result is persisted before returning to title")
	if current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn":
		current_scene.game_save_path = PATH
		current_scene._refresh_archive()
		check(current_scene.start_button.text == "重玩第一关", "Title distinguishes cleared journey from unfinished continue")
	save_script.erase(PATH)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("LEVEL CLEAR CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
