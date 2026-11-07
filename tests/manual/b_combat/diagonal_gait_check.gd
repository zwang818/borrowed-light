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
	player.attack_mode = 2
	for direction in [0,1,2,3,4,6,7]:
		visual.facing_row = direction
		visual.gait_offset = Vector2.ZERO
		var hip_y := 0.0
		for frame in range(8):
			visual.walk_distance = frame*({0:10.0,1:8.0,2:10.0,3:13.0,4:10.0,6:10.0,7:8.0}[direction])+1.0
			visual._show_frame()
			assert(visual.leg_sprite.visible)
			assert(visual.leg_sprite.texture == visual.diagonal_legs[{6:2,7:1}.get(direction,direction)][frame%4 if direction in [0,4] else frame])
			if frame == 0:
				hip_y = visual.leg_sprite.position.y
			assert(is_equal_approx(hip_y,visual.leg_sprite.position.y))
			assert(visual.sprite.texture == visual.upper_bodies[direction])
		assert(visual.leg_sprite.scale.x < 0.0 if direction in [0,4,6,7] else visual.leg_sprite.scale.x > 0.0)
		visual.walk_distance = 9.0
		visual._show_frame()
		assert(visual.leg_sprite.texture == visual.diagonal_legs[{6:2,7:1}.get(direction,direction)][0 if direction in [0,2,3,4,6] else 1])
		visual.walk_distance = 0.0
		visual._show_frame()
		assert(not visual.leg_sprite.visible)
		assert(visual.sprite.texture == visual.body_frames[direction*4])
	visual.facing_row = 5
	visual.walk_distance = 16.0
	visual._show_frame()
	assert(not visual.leg_sprite.visible)
	assert(visual.sprite.texture == visual.body_frames[20+visual.current_column])
	visual.facing_row = 1
	player.is_dead = true
	visual._show_frame()
	assert(not visual.leg_sprite.visible)
	room.queue_free()
	await process_frame
	print("Eight-direction gait: eight poses, stable hips, idle/death, unchanged right-up: PASS")
	quit()
