extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.set_physics_process(false)
	visual.set_physics_process(false)
	player.global_position = Vector2(180,180)
	Input.action_press("move_right")
	await physics_frame
	await process_frame
	player._physics_process(1.0/60.0)
	assert(is_equal_approx(player.velocity.length(),160.0))
	visual.walk_distance = 0.0
	visual.update_animation(1.0/60.0,player.sprint_motion,false)
	var normal_stride: float = visual.walk_distance
	Input.action_press("b_sprint")
	player._physics_process(1.0/60.0)
	assert(player.sprint_active and is_equal_approx(player.velocity.length(),200.0))
	assert(player.move_speed == 160.0)
	visual.walk_distance = 0.0
	visual.update_animation(1.0/60.0,player.sprint_motion,false)
	assert(absf(visual.walk_distance-normal_stride)<0.001)
	Input.action_press("move_down")
	player._physics_process(1.0/60.0)
	assert(is_equal_approx(player.velocity.length(),200.0))
	Input.action_release("b_sprint")
	player._physics_process(1.0/60.0)
	assert(not player.sprint_active and is_equal_approx(player.velocity.length(),160.0))
	Input.action_press("b_sprint")
	player.controls_enabled = false
	player._physics_process(1.0/60.0)
	assert(not player.sprint_active and player.velocity == Vector2.ZERO)
	player.restore_player(Vector2(180,180),3,[&"pulse_gun"])
	assert(not player.sprint_active and player.sprint_motion == Vector2.ZERO)
	player._physics_process(1.0/60.0)
	assert(player.sprint_active)
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player._physics_process(1.0/60.0)
	assert(not player.sprint_active)
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_release("b_sprint")
	room.queue_free()
	await process_frame
	print("Sprint: hold/release, speed, diagonal normalization, same cadence, disabled/reset/focus: PASS")
	quit()
