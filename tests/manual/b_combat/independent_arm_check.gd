extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	# Isolate low-level manual pose checks from production automatic holstering.
	room.get_node("SpawnPoints/PlayerSpawn/Player").set_script(preload("res://tests/manual/b_combat/manual_modes_fixture.gd"))
	root.add_child(room)
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	player.set_physics_process(false)
	visual.set_physics_process(false)
	for mode in [1,3]:
		player.set_attack_mode(mode)
		for row in range(8):
			visual.facing_row = row
			for degrees in [-20.0,0.0,20.0]:
				var aim := Vector2.from_angle(PI/2+row*PI/4+deg_to_rad(degrees))
				player.mouse_facing = aim
				visual._show_frame()
				var side := 0 if mode == 1 else 1
				var origin: Vector2 = player.global_position+visual.shoulder(side)
				var muzzle: Vector2 = visual.get_muzzle_world_position(mode)
				assert((muzzle-origin).normalized().is_equal_approx(aim))
				assert(Vector2.from_angle(visual.arm_nodes[side].rotation).is_equal_approx(aim))
				assert(visual.sprite.rotation == 0.0)
				assert(visual.head_occluder.visible)
				assert(visual.head_occluder.z_index > visual.arm_nodes[side].z_index)
				assert(visual.head_occluder.position.is_equal_approx(visual.sprite.position-visual.sprite.texture.get_size()*visual.sprite.scale/2))
	player.set_attack_mode(1)
	player.pulse_gun.state = player.pulse_gun.State.FIRING
	player.pulse_gun.locked_direction = Vector2.UP
	player.mouse_facing = Vector2.LEFT
	assert(visual.aim_vector(1) == Vector2.UP)
	player.pulse_gun.cancel()
	assert(visual.aim_vector(1) == Vector2.LEFT)
	player.set_attack_mode(2)
	visual._show_frame()
	assert(not visual.arm_nodes[0].visible and not visual.arm_nodes[1].visible)
	assert(not visual.head_occluder.visible)
	print("Independent arms: 8 directions, continuous aim, muzzle collinearity, firing lock and unarmed: PASS")
	room.queue_free()
	await process_frame
	quit()
