extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var room=load("res://tests/manual/b_combat/spine_combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene=room
	room.process_mode=Node.PROCESS_MODE_DISABLED
	assert(room.electric_seams.size() == 1)
	var seam=room.electric_seams[0]
	var player=seam.player
	player.global_position=seam.to_global(seam.span/2)
	seam.reset_cycle()
	seam._physics_process(1.2)
	assert(player.health==3 and not seam.active())
	player.has_protocol=true
	seam._physics_process(0.4)
	assert(player.health==2 and seam.active())
	seam._physics_process(0.05)
	assert(player.health==2)
	player.invulnerability_remaining=0
	player.global_position=seam.to_global(Vector2(-50,-50))
	seam.previous=player.global_position
	seam._physics_process(0.05)
	assert(player.health==2)
	room.reset_test_combat()
	assert(player.health==3 and seam.seconds==0 and not seam.active())
	room.queue_free()
	await process_frame
	print("Electric seam: warning safe, live damage, immunity, protocol no immunity, outside safe, reset: PASS")
	quit()
