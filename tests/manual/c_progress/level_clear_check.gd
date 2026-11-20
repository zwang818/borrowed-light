extends SceneTree
const BATTLE_FIXTURE := preload("res://tests/manual/gameplay/abdomen_combat_fixture.gd")
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
	level.journey_save_path = PATH
	root.add_child(level)
	current_scene = level
	while not level.is_entry_ready():
		await process_frame
	level.player.set_physics_process(false)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	level.player.global_position = level.final_exit.global_position
	await physics_frame
	await process_frame
	check(not level.is_level_complete and not root.has_node("EntryLoading"), "Exit remains locked before terminal activation")
	check(await BATTLE_FIXTURE.clear_exit_encounter(level), "Exit encounter cleared")
	level.player.global_position = level._terminal_access_position()
	await physics_frame
	level._try_interact()
	level.player.global_position = level._terminal_access_position()
	level._try_interact()
	if not is_instance_valid(level.interaction_sheet._code_input):
		quit(1)
		return
	level.interaction_sheet._code_input.text = level.TERMINAL_CODE
	level.interaction_sheet._advance_or_finish()
	while paused:
		await process_frame
	check(level.terminal_activated, "Terminal password unlocks exit normally")
	level.player.global_position = level.final_exit.global_position + Vector2(0, 35)
	level._on_exit_entered(level.player.get_node("PlayerModelHurtbox"), level.final_exit.get_meta("exit_id"))
	await physics_frame
	check(not level.is_level_complete, "Head silhouette alone does not trigger transition")
	level.player.global_position = level.final_exit.global_position
	level._on_exit_entered(level.player.get_node("PlayerModelHurtbox"), level.final_exit.get_meta("exit_id"))
	await physics_frame
	await process_frame
	var transitions := root.get_children().filter(func(child: Node):
		return child.get_script() == preload("res://scenes/ui/intro_cutscene/level_transition.gd"))
	check(level.is_level_complete and transitions.size() == 1, "Feet entering the exit starts one transition")
	if transitions.is_empty():
		quit(1)
		return
	var transition: Node = transitions[0]
	level._on_exit_entered(level.player, level.final_exit.get_meta("exit_id"))
	check(root.get_children().filter(func(child: Node):
		return child.get_script() == transition.get_script()).size() == 1, "Exit cannot create duplicate transitions")
	var save_script = preload("res://scenes/gameplay/journey_save.gd")
	check(save_script.read_save(PATH).get("first_level_cleared", false), "Clear result is persisted before the video finishes")
	transition.video.stop()
	transition._finish()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and current_scene != null and current_scene.scene_file_path == save_script.SPINE:
			break
	check(not paused and current_scene != null and current_scene.scene_file_path == save_script.SPINE, "Level clear reaches Spine through loading")
	save_script.erase(PATH)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	print("LEVEL CLEAR CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
