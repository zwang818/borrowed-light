extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(scene)
	scene.player.set_physics_process(false)
	for enemy in scene.enemies:
		enemy.set_physics_process(false)
	scene.player.global_position = scene.terminal.global_position + Vector2(0,30)
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	assert(scene._remaining_cleaners() == 3)
	for enemy in scene.enemies:
		scene._input(press)
		assert(not scene.terminal_activated, "Living cleaners must block E")
		assert(not scene.terminal.get_meta("activated"))
		scene._update_world_prompts()
		assert("锁定" in scene.interact_label.text)
		enemy.apply_damage(100)
	assert(scene._remaining_cleaners() == 0)
	scene._input(press)
	assert(scene.terminal_activated)
	assert(scene.terminal.get_meta("activated"))
	var door = scene.interactables_parent.get_node("Door_p1_door_01")
	assert(door.get_meta("is_open") and door.collision_layer == 0)
	await create_timer(.6).timeout
	scene._retry_level()
	assert(scene._remaining_cleaners() == 3)
	assert(not scene.terminal.get_meta("activated"))
	assert(not door.get_meta("is_open") and door.collision_layer == 1)
	scene.player.global_position = scene.terminal.global_position + Vector2(0,30)
	scene._input(press)
	assert(not scene.terminal_activated)
	await create_timer(.15).timeout
	scene.queue_free()
	await create_timer(.15).timeout
	print("Terminal elimination gate: PASS")
	quit()
