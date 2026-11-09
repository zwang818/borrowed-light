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
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.set_physics_process(false)
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	visual.set_physics_process(false)
	player.global_position = Vector2(200,200)
	player.attack_mode = 2
	visual.facing_row = 0
	visual._show_frame()
	visual.global_rotation = 0.0
	var hurtbox = player.get_node("PlayerModelHurtbox")
	hurtbox.sync_pose()
	assert(player.collision_layer == 0 and player.collision_mask == 1)
	assert(player.get_node("CollisionShape2D").shape.radius == 10.0)
	await physics_frame
	await process_frame
	var space = player.get_world_2d().direct_space_state
	var head_ray := PhysicsRayQueryParameters2D.create(Vector2(150,165),Vector2(250,165),2)
	assert(space.intersect_ray(head_ray).collider == hurtbox)
	var empty_ray := PhysicsRayQueryParameters2D.create(Vector2(150,125),Vector2(250,125),2)
	assert(space.intersect_ray(empty_ray).is_empty())
	# Actual shared sentry projectile strikes the head, outside old foot circle.
	var bullet = load("res://scenes/weapons/enemy_projectile.tscn").instantiate()
	room.add_child(bullet)
	bullet.global_position = Vector2(150,165)
	bullet.direction = Vector2.RIGHT
	bullet._physics_process(0.5)
	assert(player.health == 2 and bullet.spent)
	# Silk uses that same silhouette and still never damages.
	var web = preload("res://tests/manual/b_combat/web_projectile.gd").new()
	web.source = enemy
	room.add_child(web)
	web.global_position = Vector2(150,165)
	web.direction = Vector2.RIGHT
	web._physics_process(0.5)
	assert(player.health == 2 and player.web_slow_remaining == 2.0)
	player.invulnerability_remaining = 0.0
	enemy.global_position = Vector2(165,165)
	enemy.configure(player,func(_e): return true,func(): return false)
	enemy.state = enemy.State.ATTACK
	enemy.locked_direction = Vector2.RIGHT
	enemy.attack_hit = false
	enemy.try_melee_hit()
	assert(player.health == 1)
	enemy.try_melee_hit()
	assert(player.health == 1)
	# Exercise every animated/mirrored pose and raised weapon arm.
	for direction in range(8):
		for frame in range(8):
			visual.facing_row = direction
			visual.walk_distance = frame*10.0+1.0
			visual._show_frame()
			hurtbox.sync_pose()
			assert(hurtbox.shapes.size()>0)
	player.invulnerability_remaining = 0.0
	player.apply_damage(1)
	await process_frame
	assert(hurtbox.collision_layer == 0)
	player.restore_player(Vector2(200,200),3,[&"pulse_gun"])
	await process_frame
	assert(hurtbox.collision_layer == 2 and player.collision_layer == 0)
	room.queue_free()
	await process_frame
	print("Player model hurtbox: head hits, empty space, bullet/web/melee, all directions, death/restore, foot collision unchanged: PASS")
	quit()
