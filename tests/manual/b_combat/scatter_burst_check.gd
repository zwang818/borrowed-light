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
	assert(burst.points.size()==12)
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
	assert(burst.impacts.size()==12)
	for point in burst.points: assert(point.x<=28.1)
	burst._physics_process(0.1)
	assert(burst.impacts.size()==12)
	room.reset_test_combat()
	await process_frame
	assert(get_nodes_in_group("b_scatter_flashes").is_empty())
	wall.queue_free()
	room.queue_free()
	await process_frame
	print("Scatter burst: 12 swept streaks, wall blocking, no repeated impact, cooldown and reset: PASS")
	quit()
