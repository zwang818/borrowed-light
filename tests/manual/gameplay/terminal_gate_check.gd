extends SceneTree

const LEVEL := preload("res://scenes/gameplay/abdomen_level.tscn")

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene := LEVEL.instantiate()
	root.add_child(scene)
	while not scene.is_entry_ready():
		await process_frame
	scene.player.set_physics_process(false)
	for enemy in scene.enemies:
		enemy.set_physics_process(false)
	scene.player.global_position = scene._terminal_access_position()
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	assert(scene._remaining_cleaners() == 4 and scene.terminal_gate.collision_layer == 1)
	scene._input(press)
	assert(not scene.terminal_activated and not paused)
	for enemy in scene.enemies:
		enemy.apply_damage(enemy.health)
	assert(scene._remaining_cleaners() == 1 and scene.terminal_gate.collision_layer == 1)
	scene.player.global_position = Vector2(855, 533)
	for i in range(110):
		await physics_frame
		if is_instance_valid(scene.boss) and not scene.boss.chassis.disabled:
			break
	assert(is_instance_valid(scene.boss) and not scene.boss.chassis.disabled)
	scene.boss.apply_damage(scene.boss.health)
	assert(scene._remaining_cleaners() == 0 and scene.terminal_gate.collision_layer == 0)
	scene.player.global_position = scene._terminal_access_position()
	scene._input(press)
	assert(scene.terminal.get_node("FacilityVisual").powered)
	scene.player.global_position = scene._terminal_access_position()
	scene._input(press)
	assert(not scene.terminal_activated and paused)
	scene.interaction_sheet._code_input.text = scene.TERMINAL_CODE
	scene.interaction_sheet._advance_or_finish()
	await process_frame
	assert(scene.terminal_activated and scene.terminal.get_meta("activated"))
	var door := scene.interactables_parent.get_node("Door_p1_door_01") as StaticBody2D
	assert(door.get_meta("is_open") and door.collision_layer == 0)
	scene._retry_level()
	assert(scene._remaining_cleaners() == 4 and not is_instance_valid(scene.boss))
	assert(scene.terminal_gate.collision_layer == 1 and not scene.terminal.get_meta("activated"))
	assert(not door.get_meta("is_open") and door.collision_layer == 1)
	scene.queue_free()
	await process_frame
	print("TERMINAL_GATE_PASS")
	quit()
