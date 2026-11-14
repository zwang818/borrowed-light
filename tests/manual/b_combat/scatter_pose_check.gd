extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var room=load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	room.get_node("SpawnPoints/PlayerSpawn/Player").set_script(preload("res://tests/manual/b_combat/dual_arm_pose_fixture.gd"))
	root.add_child(room)
	current_scene=room
	room.process_mode=Node.PROCESS_MODE_DISABLED
	var player=room.get_node("SpawnPoints/PlayerSpawn/Player")
	var visual=player.get_node("Facing/XiaoyiCombatVisual")
	player.attack_mode=3
	for row in [6,2,4,0,7,3,5,1]:
		var aim=Vector2.from_angle(PI/2+row*PI/4)
		point_mouse(player,aim)
		visual.update_animation(0.016,Vector2.ZERO,false)
		assert(visual.facing_row==row)
		assert(Vector2.from_angle(visual.arm_nodes[1].rotation).is_equal_approx(aim))
		var muzzle=visual.get_muzzle_world_position(3)
		assert((muzzle-player.global_position-visual.shoulder(1)).normalized().is_equal_approx(aim))
		if row == 6:
			assert(visual.arm_nodes[1].z_index>visual.head_occluder.z_index)
		else:
			assert(visual.head_occluder.z_index>visual.arm_nodes[1].z_index)
	point_mouse(player,Vector2.RIGHT)
	visual.update_animation(0.016,Vector2.ZERO,false)
	for degrees in [21.0,24.0,22.0,23.0]:
		point_mouse(player,Vector2.from_angle(deg_to_rad(degrees)))
		visual.update_animation(0.016,Vector2.ZERO,false)
		assert(visual.facing_row==6)
	point_mouse(player,Vector2.from_angle(deg_to_rad(30)))
	visual.update_animation(0.016,Vector2.ZERO,false)
	assert(visual.facing_row==7)
	player.attack_mode=1
	for row in range(8):
		visual.facing_row=row
		var aim=Vector2.from_angle(PI/2+row*PI/4)
		point_mouse(player,aim)
		visual._show_frame()
		var muzzle=visual.get_muzzle_world_position(1)
		assert((muzzle-player.global_position-visual.shoulder(0)).is_equal_approx(aim*(25.0*0.94-3.0)))
		var rest_scale: Vector2=visual.arm_nodes[1].get_node("Art").scale
		visual._refresh_arms()
		assert(visual.arm_nodes[1].get_node("Art").scale.is_equal_approx(rest_scale))
	# Holstered walking must keep arms below the head and not accumulate scaling;
	# switching back to combat restores the authored weapon length and muzzle.
	player.attack_mode=2
	for row in range(8):
		visual.facing_row=row
		visual.walk_distance=20.0
		visual.gait_strength=1.0
		visual._show_frame()
		for arm in visual.arm_nodes:
			assert(arm.z_index<visual.head_occluder.z_index)
			var art=arm.get_node("Art")
			assert(is_equal_approx(art.scale.x*art.texture.get_width(),21.0))
	player.attack_mode=1
	visual._show_frame()
	var laser_art=visual.arm_nodes[0].get_node("Art")
	assert(is_equal_approx(laser_art.scale.x*laser_art.texture.get_width(),25.0))
	room.queue_free()
	await process_frame
	print("Dual-arm pose: 8-way scatter alignment, laser muzzle unchanged, stable rest scale, head occlusion and boundary stability: PASS")
	quit()

func point_mouse(player: Node2D, direction: Vector2) -> void:
	player.mouse_facing = direction
