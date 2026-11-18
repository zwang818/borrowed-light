extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var room=load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene=room
	room.process_mode=Node.PROCESS_MODE_DISABLED
	var player=room.get_node("SpawnPoints/PlayerSpawn/Player")
	player.attack_mode=player.AttackMode.SCATTER
	assert(player.fire_scatter(Vector2.RIGHT))
	assert(not player.fire_scatter(Vector2.RIGHT))
	var burst=get_nodes_in_group("b_scatter_flashes")[0]
	assert(burst.get_script().resource_path.ends_with("scatter_burst_a.gd"))
	var second = load("res://tests/manual/b_combat/spine_combat_test.tscn").instantiate()
	assert(second.scatter_a_preview and second.hot_scatter_preview)
	second.free()
	var production = load("res://scenes/gameplay/spine_level.tscn").instantiate()
	assert(production.scatter_a_preview and production.dynamic_walk_preview)
	assert(not production.hot_scatter_preview)
	production.free()
	var main_player = load("res://scenes/player/xiaoyi_journey_player.gd").new()
	assert(main_player.scatter_burst_script.resource_path.ends_with("/scatter_burst_a.gd"))
	var original_burst = main_player.scatter_burst_script.new()
	assert(original_burst.pellet_count == 9)
	original_burst.free()
	main_player.free()
	assert(burst.points.size()==9)
	burst._physics_process(0.001)
	for distance in burst.distances:
		assert(is_equal_approx(distance,burst.SPEED*0.001),"A pellets launch together as one fan")
	var wall=StaticBody2D.new()
	wall.collision_layer=1
	var collider=CollisionShape2D.new()
	var shape=RectangleShape2D.new()
	shape.size=Vector2(4,80)
	collider.shape=shape
	wall.add_child(collider)
	root.add_child(wall)
	wall.global_position=burst.global_position+Vector2(30,0)
	await physics_frame
	await physics_frame
	burst._physics_process(0.2)
	assert(burst.impacts.size()==9)
	assert(not burst.embers.is_empty() and burst.fading_trails.size()==9)
	for ember in burst.embers: assert(ember.point.x<=28.1,"Trail particles stop at the real wall hit")
	for point in burst.points: assert(point.x<=28.1)
	burst._physics_process(0.1)
	assert(burst.impacts.size()==9)
	room.reset_test_combat()
	await process_frame
	assert(get_nodes_in_group("b_scatter_flashes").is_empty())
	wall.queue_free()
	room.queue_free()
	await process_frame
	print("Scatter burst: 9 swept streaks, wall blocking, no repeated impact, cooldown and reset: PASS")
	quit()
