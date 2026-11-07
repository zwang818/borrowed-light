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
	for actor in [player,enemy]:
		actor.process_mode = Node.PROCESS_MODE_ALWAYS
		actor.set_physics_process(false)
	player.global_position = Vector2(280,120)
	enemy.global_position = Vector2(100,120)
	enemy.configure(player,func(_e): return true,func(): return player.has_protocol)
	await physics_frame
	await process_frame
	enemy.state = enemy.State.CHASE
	enemy.web_cooldown = 0.0
	var start: Vector2 = enemy.global_position
	enemy._physics_process(0.01)
	assert(enemy.web_phase == 1 and enemy.velocity == Vector2.ZERO)
	enemy._physics_process(0.3)
	assert(enemy.global_position == start and get_nodes_in_group("b_cleaner_webs").is_empty())
	enemy._physics_process(0.3)
	assert(enemy.web_phase == 2 and enemy.global_position == start)
	var web = get_nodes_in_group("b_cleaner_webs")[0]
	web.set_physics_process(false)
	assert(web.global_position.distance_to(enemy.eye_origin()) < 0.01)
	var health: int = player.health
	web._physics_process(1.0)
	assert(player.health == health and player.web_slow_remaining == 2.0)
	Input.action_press("move_right")
	player._physics_process(0.01)
	assert(is_equal_approx(player.velocity.length(),96.0))
	Input.action_press("b_sprint")
	player._physics_process(0.01)
	assert(is_equal_approx(player.velocity.length(),120.0))
	player.apply_web_slow(2.0,0.6)
	assert(player.web_speed_factor == 0.6 and player.web_slow_remaining == 2.0)
	Input.action_release("b_sprint")
	player._physics_process(2.1)
	assert(is_equal_approx(player.velocity.length(),160.0))
	Input.action_release("move_right")
	enemy._physics_process(0.3)
	assert(enemy.web_phase == 0)
	enemy._physics_process(0.01)
	assert(enemy.global_position != start)
	# Nearby players trigger the unchanged melee warning instead of silk.
	player.global_position = enemy.global_position+Vector2(35,0)
	enemy._physics_process(0.01)
	assert(enemy.state == enemy.State.WARNING and enemy.web_phase == 0)
	# Protocol cancels a pending ranged shot.
	enemy.state = enemy.State.CHASE
	player.global_position = enemy.global_position+Vector2(180,0)
	enemy.web_cooldown = 0.0
	enemy._physics_process(0.01)
	assert(enemy.web_phase == 1)
	player.set_protocol_active(true)
	enemy._physics_process(0.6)
	assert(enemy.web_phase == 0)
	player.set_protocol_active(false)
	# A swept silk hit on a wall must not slow the player behind it.
	player.restore_player(Vector2(280,120),3,[&"pulse_gun"])
	enemy.global_position = Vector2(100,120)
	var wall := StaticBody2D.new()
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	wall.collision_layer = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8,100)
	collider.shape = shape
	wall.add_child(collider)
	room.add_child(wall)
	wall.global_position = Vector2(190,120)
	await physics_frame
	await process_frame
	enemy.web_direction = enemy.eye_origin().direction_to(player.global_position)
	enemy.fire_web()
	var blocked = get_nodes_in_group("b_cleaner_webs").back()
	blocked.set_physics_process(false)
	blocked._physics_process(1.0)
	assert(blocked.spent and player.web_slow_remaining == 0.0)
	player.apply_web_slow(2.0,0.6)
	room.reset_test_combat()
	assert(player.web_slow_remaining == 0.0 and enemy.web_phase == 0)
	await process_frame
	assert(get_nodes_in_group("b_cleaner_webs").is_empty())
	room.queue_free()
	await process_frame
	print("Web attack: stationary telegraph, eye origin, no damage, slow/sprint/expiry, chase/melee, protocol, wall, reset: PASS")
	quit()
