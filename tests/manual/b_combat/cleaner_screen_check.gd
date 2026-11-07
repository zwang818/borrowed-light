extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var enemy = room.get_node("SpawnPoints/CleanerSpawn/Cleaner")
	await process_frame
	var screen := root.get_visible_rect()
	var to_world := root.get_canvas_transform().affine_inverse()
	player.global_position = to_world*Vector2(screen.end.x-80,screen.size.y/2)
	enemy.global_position = to_world*Vector2(80,screen.size.y/2)
	assert(player.global_position.distance_to(enemy.global_position)>256.0)
	assert(enemy.can_detect())
	enemy._physics_process(0.01)
	assert(enemy.state == enemy.State.CHASE)
	# The model entering the edge counts, even with its origin outside.
	enemy.global_position = to_world*Vector2(-2,screen.size.y/2)
	assert(enemy.can_detect())
	enemy.global_position = to_world*Vector2(-150,screen.size.y/2)
	assert(not enemy.can_detect())
	enemy.global_position = to_world*Vector2(80,screen.size.y/2)
	enemy.hide()
	assert(not enemy.can_detect())
	enemy.show()
	player.is_dead = true
	assert(not enemy.can_detect())
	player.is_dead = false
	player.set_protocol_active(true)
	assert(not enemy.can_detect())
	player.set_protocol_active(false)
	# Geometry between visible enemy/player does not remove awareness.
	var wall := StaticBody2D.new()
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12,100)
	collision.shape = shape
	wall.add_child(collision)
	room.add_child(wall)
	wall.global_position = (enemy.global_position+player.global_position)/2
	await physics_frame
	await process_frame
	var ray := PhysicsRayQueryParameters2D.create(enemy.global_position,player.global_position,1)
	assert(not wall.get_world_2d().direct_space_state.intersect_ray(ray).is_empty())
	assert(enemy.can_detect())
	enemy.state = enemy.State.DEAD
	assert(not enemy.can_detect())
	room.queue_free()
	await process_frame
	print("Cleaner screen awareness: far, edge, offscreen, hidden, wall, death and protocol: PASS")
	quit()
