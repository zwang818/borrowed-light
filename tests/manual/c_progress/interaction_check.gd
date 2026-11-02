extends SceneTree
const SAVE := "user://test_c_interactions.cfg"
var failures: Array[String] = []
var received_token := 0

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func interact_at(level: Node, id: StringName) -> void:
	level.player.global_position = level.interaction_points[id].global_position + Vector2(0, 24)
	await physics_frame
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	root.push_input(press, true)
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	root.push_input(release, true)

func receive_story(_id: StringName, _payload: Dictionary, token: int) -> void:
	received_token = token

func run_checks() -> void:
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	level.achievement_save_path = SAVE
	root.add_child(level)
	current_scene = level
	await create_timer(0.15).timeout
	check(level.interaction_points.size() == 3, "Three stable interaction points exist")
	check(not level.notify_bg.visible, "No opening navigation notification")
	for label in level.hud_canvas.find_children("*", "Label", true, false):
		check(not label.text.contains("当前目标") and not label.text.contains("前往上方"), "No persistent objective guidance")
	check(not level.player.pulse_gun_equipped, "No attack before learning")
	var hearts = level.health_display
	check(hearts.heart_count() == 3 and is_equal_approx(hearts.heart_fill(2), 1), "Three full hearts reflect starting health")
	# Fractional view snapshots exercise half-heart rendering without changing B damage.
	hearts.set_health(2.5, 3)
	check(is_equal_approx(hearts.heart_fill(2), 0.5), "Half-heart fill is represented exactly")
	hearts.set_health(0, 3)
	check(is_zero_approx(hearts.heart_fill(0)) and hearts._status.text == "离线", "Zero health leaves empty casings and offline state")
	level._update_hp_bar()
	await interact_at(level, &"pulse_workbench")
	check(not paused and not level.pulse_learned, "Workbench cannot skip blueprint")
	await interact_at(level, &"pulse_blueprint")
	check(paused and level.pending_interaction == &"pulse_blueprint", "Blueprint opens modal and freezes world")
	var first_token: int = level.interaction_token
	check(level.interaction_sheet.line_index == 0, "Opening interaction does not skip first dialogue line")
	level.interaction_sheet._advance_or_finish()
	check(not level.blueprint_known, "Advancing one dialogue line does not grant progress")
	for label in level.interaction_sheet.overlay.find_children("*", "Label", true, false):
		check(not label.text.contains("阅读时世界暂停") and not label.text.contains("下一步"), "Dialogue has no system or next-step footer")
	# This card is the actual modal. It must remain on screen after viewport resize.
	await process_frame
	check(level.interaction_sheet.panel.get_global_rect().end.y <= root.get_visible_rect().end.y, "Interaction card fits viewport")
	level._toggle_pause()
	await process_frame
	check(not paused and not level.blueprint_known, "Esc cancels without granting progress")
	level.finish_interaction(first_token, true)
	check(not level.blueprint_known, "Late completion after cancellation is ignored")
	await interact_at(level, &"pulse_blueprint")
	for _line in level.interaction_sheet.dialogue.size():
		level.interaction_sheet._advance_or_finish()
	await process_frame
	check(level.blueprint_known and not level.pulse_learned, "Blueprint records knowledge but does not grant attack")
	check(level.current_objective == level.Objective.CRAFT_ARM, "Blueprint switches internal crafting phase")
	await interact_at(level, &"pulse_workbench")
	for _line in level.interaction_sheet.dialogue.size():
		level.interaction_sheet._advance_or_finish()
	await process_frame
	check(not paused and level.pulse_learned and level.player.pulse_gun_equipped, "Manufacturing grants pulse ability once")
	check(level.player.pulse_gun.state == level.player.pulse_gun.State.IDLE, "Completion does not leak attack")
	await interact_at(level, &"pulse_workbench")
	check(not paused and level.pending_interaction.is_empty(), "Completed manufacturing cannot repeat")
	# D can replace the fallback and must explicitly report completion.
	level.interaction_requested.connect(receive_story)
	await interact_at(level, &"workshop_origin")
	check(paused and received_token > 0 and not is_instance_valid(level.interaction_sheet.overlay), "D receives request without fallback UI")
	level.finish_interaction(received_token + 1, true)
	check(paused and not level.workshop_seen, "Wrong token cannot advance story")
	level.finish_interaction(received_token, true)
	await process_frame
	check(level.workshop_seen and not paused, "D completion records story read state")
	check(level.game_menus.achievements.get("workshop_reader", false), "Completed story request awards reader achievement")
	level.interaction_requested.disconnect(receive_story)
	# Test genuine player collision at front and side of the new region enclosure.
	var player = level.player
	player.global_position = level.terminal.global_position + Vector2(0, 100)
	await physics_frame
	check(player.test_move(player.global_transform, Vector2(0, -60)), "Closed entrance physically blocks player")
	level._update_interaction()
	check(level.nearest_interactable != level.terminal, "Terminal cannot be used through closed gate")
	player.global_position = level.terminal.global_position + Vector2(-120, 0)
	await physics_frame
	check(player.test_move(player.global_transform, Vector2(80, 0)), "Side wall prevents bypass")
	for enemy in level.enemies:
		enemy.apply_damage(999)
	await physics_frame
	check(level.terminal_gate.collision_layer == 0 and level.terminal_gate.get_meta("is_open"), "Last cleaner opens entrance")
	await create_timer(0.4).timeout
	check(is_equal_approx(level.terminal_gate.get_node("FacilityVisual").open_amount, 1.0), "Door animation exposes open entrance")
	player.global_position = level.terminal.global_position + Vector2(0, 100)
	check(not player.test_move(player.global_transform, Vector2(0, -60)), "Player can enter after clear")
	player.global_position = level.terminal.global_position + Vector2(0, 24)
	await physics_frame
	level._try_interact()
	check(level.terminal_activated, "E activates reachable terminal")
	var exit_door = level.interactables_parent.get_node("Door_p1_door_01")
	check(exit_door.collision_layer == 0, "Terminal opens exit separately")
	player.invulnerability_remaining = 0
	player.apply_damage(999)
	check(paused and player.is_dead, "Death waits for retry")
	check(is_zero_approx(hearts.current_health), "Death signal immediately clears HUD hearts")
	level._retry_level()
	check(level.pulse_learned and player.pulse_gun_equipped, "REV-14: death preserves ability")
	check(is_equal_approx(hearts.current_health, float(player.max_health)), "Retry restores hearts from real health snapshot")
	check(level.workshop_seen and level.blueprint_known, "Knowledge and read records survive retry")
	check(not level.terminal_activated and level.terminal_gate.collision_layer == 1 and exit_door.collision_layer == 1, "Retry resets both doors and terminal")
	check(is_zero_approx(level.terminal_gate.get_node("FacilityVisual").open_amount), "Retry closes door visual with collision")
	check(level._remaining_cleaners() == 3, "Retry restores all cleaners")

	await process_frame
	# Export an actual graphical preview when run without --headless.
	var capture_path := OS.get_environment("C_UI_PREVIEW_PATH")
	if DisplayServer.get_name() != "headless" and not capture_path.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_path)
	level.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("INTERACTION CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
