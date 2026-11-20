extends SceneTree
const BATTLE_FIXTURE := preload("res://tests/manual/gameplay/abdomen_combat_fixture.gd")
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
	press_interact()

func press_interact() -> void:
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
	create_timer(40.0).timeout.connect(func(): quit(1))
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await create_timer(0.15).timeout
	check(level.interaction_points.size() == 4, "Four stable story interaction points exist")
	var duct = level.ducts[&"duct_arrival"].point
	for point in level.interaction_points.values():
		check(point.cue == duct.cue, "Story point uses the duct marker: " + String(point.interaction_id))
	check(level.terminal.get_node("InteractionMarker").cue == duct.cue, "Terminal uses the duct marker")
	check(not level.notify_bg.visible, "No opening navigation notification")
	var gate: StaticBody2D = level.pulse_assembly_gate
	var approach := gate.global_position + Vector2(0, 48)
	level.player.global_position = approach
	await physics_frame
	check(gate.collision_layer == 1 and level.player.test_move(level.player.global_transform, Vector2(0, -72)),
		"The locked assembly gate blocks the passage")
	Input.action_press(&"move_up")
	await create_timer(0.4).timeout
	Input.action_release(&"move_up")
	check(level.notify_bg.visible and level.notify_label.text == "请先到制造台装配激光装置。",
		"Walking into the locked assembly gate tells the player to assemble the laser")
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
	await interact_at(level, level.VOICE_POINT)
	check(paused and level.pending_interaction == level.VOICE_POINT and level.abdomen_voice.visible,
		"Listening opens by pressing interact from beside the former light spot")
	level._toggle_pause()
	await process_frame
	await interact_at(level, &"pulse_workbench")
	check(not paused and not level.pulse_learned, "Workbench cannot skip blueprint")
	var blueprint_point = level.interaction_points[&"pulse_blueprint"]
	var rack = level.map.get_node("Walls/GunRackBase")
	check(is_equal_approx(blueprint_point.global_position.x, rack.to_global(rack.size * 0.5).x),
		"Blueprint marker is centered beneath the computer")
	level.player.global_position = blueprint_point.global_position + Vector2(0, 34)
	await physics_frame
	check(not level.player.test_move(level.player.global_transform, Vector2(0, -34)),
		"Xiaoyi can walk to the blueprint marker from below")
	check(level.player.test_move(Transform2D(0, blueprint_point.global_position), Vector2(0, -24)),
		"The visible blueprint casing still prevents walking through it")
	level.player.global_position = level.interaction_points[&"pulse_blueprint"].global_position + Vector2(0, 60)
	await physics_frame
	press_interact()
	check(not paused and level.pending_interaction.is_empty(), "Standing beyond duct reach cannot open the blueprint panel")
	await interact_at(level, &"pulse_blueprint")
	check(paused and level.pending_interaction == &"pulse_blueprint", "Blueprint opens modal and freezes world")
	var first_token: int = level.interaction_token
	check(level.abdomen_voice.visible and level.abdomen_voice.page == 0, "Opening interaction shows the first illustrated page")
	level.abdomen_voice._advance()
	check(not level.blueprint_known, "Advancing one dialogue line does not grant progress")
	level._toggle_pause()
	await process_frame
	check(not paused and not level.blueprint_known, "Esc cancels without granting progress")
	level.finish_interaction(first_token, true)
	check(not level.blueprint_known, "Late completion after cancellation is ignored")
	var player_z: int = level.player.z_index
	var computer_z: int = level.blueprint_computer.z_index
	await interact_at(level, &"pulse_blueprint")
	for _page in level.abdomen_voice._page_count():
		level.abdomen_voice._advance()
	await create_timer(0.15).timeout
	check(level.player.z_index > computer_z and level.blueprint_computer.z_index == computer_z
		and level.blueprint_computer.transfer_cable.visible, "Transfer keeps Xiaoyi in front of the computer with the cable visible")
	level._toggle_pause()
	await process_frame
	check(level.player.z_index == player_z and not level.blueprint_computer.transfer_cable.visible,
		"Canceling transfer restores the regular player layer")
	await interact_at(level, &"pulse_blueprint")
	for _page in level.abdomen_voice._page_count():
		level.abdomen_voice._advance()
	await create_timer(5.2).timeout
	await process_frame
	check(level.player.z_index == player_z and not level.blueprint_computer.transfer_cable.visible,
		"Finishing transfer restores the regular player layer")
	check(level.blueprint_known and not level.pulse_learned, "Blueprint records knowledge but does not grant attack")
	check(gate.collision_layer == 1 and not gate.get_meta("is_open"), "Reading the schematic alone keeps the gate locked")
	check(level.current_objective == level.Objective.CRAFT_ARM, "Blueprint switches internal crafting phase")
	await interact_at(level, &"pulse_workbench")
	for _page in level.abdomen_voice._page_count():
		level.abdomen_voice._advance()
	await process_frame
	check(not paused and level.pulse_learned and level.player.pulse_gun_equipped, "Manufacturing grants pulse ability once")
	check(gate.get_meta("is_open") and gate.collision_layer == 0, "Finishing assembly automatically opens the route")
	check(not level.player.test_move(Transform2D(0, approach), Vector2(0, -72)),
		"The open gate lets the player cross the passage")
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
	var player = level.player
	player.global_position = level.terminal.global_position + Vector2(0, 100)
	await physics_frame
	check(player.test_move(player.global_transform, Vector2(0, -60)), "Closed entrance physically blocks player")
	level._update_interaction()
	check(level.nearest_interactable != level.terminal, "Terminal cannot be used through closed gate")
	check(await BATTLE_FIXTURE.clear_exit_encounter(level), "Exit encounter cleared")
	await physics_frame
	check(level.terminal_gate.collision_layer == 0 and level.terminal_gate.get_meta("is_open"), "Defeating the exit encounter opens entrance")
	await create_timer(0.4).timeout
	check(is_equal_approx(level.terminal_gate.get_node("FacilityVisual").open_amount, 1.0), "Door animation exposes open entrance")
	player.global_position = level.terminal.global_position + Vector2(0, 100)
	check(not player.test_move(player.global_transform, Vector2(0, -60)), "Player can enter after clear")
	player.global_position = level.terminal.global_position + Vector2(0, 40)
	await physics_frame
	check(player.test_move(player.global_transform, Vector2(0, -60)), "Solid terminal blocks approaching from the front")
	check(player.test_move(Transform2D(0, level.terminal.global_position + Vector2(72, -20)), Vector2(-40, 0)), "Solid terminal blocks approaching from the side")
	level._update_world_prompts()
	check(level.terminal.get_node("FacilityVisual").z_index == 0, "Player standing in front renders in front of terminal")
	var marker = level.terminal.get_node("InteractionMarker")
	var console = level.terminal.get_node("FacilityVisual")
	check(marker.visible and marker.to_global(marker.cue_offset).is_equal_approx(console.to_global(console.LEVER_WELL.get_center())),
		"The unpowered terminal marks the right-hand lever")
	player.global_position = level._terminal_access_position() + Vector2(0, 24)
	await physics_frame
	press_interact()
	check(not paused and console.powered, "Interact from beside the marker powers the terminal")
	check(marker.visible and marker.to_global(marker.cue_offset).is_equal_approx(console.to_global(console.SCREEN.get_center())),
		"Powering the terminal moves the marker to the left-hand screen")
	press_interact()
	check(not paused and level.pending_interaction.is_empty(), "The previous lever approach is out of reach of the new screen point")
	player.global_position = level._terminal_access_position() + Vector2(0, 24)
	await physics_frame
	press_interact()
	check(paused and level.pending_interaction == level.TERMINAL_REQUEST and not level.terminal_activated, "E opens terminal password entry")
	if not is_instance_valid(level.interaction_sheet._code_input):
		quit(1)
		return
	level.interaction_sheet._code_input.text = level.TERMINAL_CODE
	level.interaction_sheet._advance_or_finish()
	check(not marker.visible, "Submitting the correct password hides the interaction marker during success feedback")
	await create_timer(2.0).timeout
	check(level.terminal_activated, "Correct password activates reachable terminal")
	var exit_door = level.interactables_parent.get_node("Door_p1_door_01")
	check(exit_door.collision_layer == 0, "Terminal opens exit separately")
	player.invulnerability_remaining = 0
	player.apply_damage(999)
	check(paused and player.is_dead, "Death waits for retry")
	check(is_zero_approx(hearts.current_health), "Death signal immediately clears HUD hearts")
	level._retry_level()
	check(level.pulse_learned and player.pulse_gun_equipped, "REV-14: death preserves ability")
	check(gate.get_meta("is_open") and gate.collision_layer == 0, "Death retry keeps the assembly gate open for the retained arm")
	check(is_equal_approx(hearts.current_health, float(player.max_health)), "Retry restores hearts from real health snapshot")
	check(level.workshop_seen and level.blueprint_known, "Knowledge and read records survive retry")
	check(not level.terminal_activated and level.terminal_gate.collision_layer == 1 and exit_door.collision_layer == 1, "Retry resets both doors and terminal")
	check(not marker.visible and marker.to_global(marker.cue_offset).is_equal_approx(console.to_global(console.LEVER_WELL.get_center())),
		"Retry restores the lever position and hides the locked marker")
	check(is_zero_approx(level.terminal_gate.get_node("FacilityVisual").open_amount), "Retry closes door visual with collision")
	check(level._remaining_cleaners() == 4, "Retry restores all cleaners")

	await process_frame
	# Export an actual graphical preview when run without --headless.
	var capture_path := OS.get_environment("C_UI_PREVIEW_PATH")
	if DisplayServer.get_name() != "headless" and not capture_path.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_path)
	level.queue_free()
	await process_frame
	print("INTERACTION CHECKS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
