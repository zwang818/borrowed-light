extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room = load("res://scenes/gameplay/spine_level.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	for frame in range(600):
		if room.is_entry_ready(): break
		await process_frame
	assert(room.is_entry_ready())
	var hazard = room.entrance_hazards
	var player = hazard.actor
	assert(hazard.emitters.size() == 8 and hazard.electrodes.size() == 7)
	paused = true
	var time: float = hazard.elapsed
	await create_timer(0.05,true).timeout
	assert(hazard.elapsed == time)
	paused = false
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var emitters = hazard.emitters.duplicate()
	var electrodes = hazard.electrodes.duplicate()
	var emitter: Marker2D = emitters[0]
	var forward := Vector2.from_angle(emitter.global_rotation)
	hazard.emitters.assign([emitter])
	hazard.electrodes.clear()
	player.global_position = emitter.global_position+forward*96.0
	hazard.reset_motion()
	for frame in range(300):
		hazard._physics_process(1.0/60.0)
		if player.health < player.max_health: break
	assert(player.health == player.max_health-1,"Laser orb must deal real damage")
	hazard.actor_hit.emit("激光球")
	assert(player.health == player.max_health-1,"Same-frame hits respect player immunity")

	# A solid obstacle between muzzle and player stops the projectile.
	var wall := StaticBody2D.new()
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	wall.collision_layer = 1
	wall.position = emitter.global_position+forward*65.0
	wall.rotation = forward.angle()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6,80)
	collision.shape = shape
	wall.add_child(collision)
	room.add_child(wall)
	player.health = player.max_health
	player.invulnerability_remaining = 0.0
	await physics_frame
	await process_frame
	hazard.reset_motion()
	for frame in range(300): hazard._physics_process(1.0/60.0)
	assert(player.health == player.max_health,"Wall must block laser orbs")
	wall.queue_free()
	await physics_frame
	await process_frame

	hazard.emitters.clear()
	hazard.electrodes.assign([electrodes[0]])
	player.global_position = electrodes[0].global_position+Vector2(0.9063078,-0.4226183)*40.0
	hazard.reset_motion()
	for frame in range(120):
		hazard._physics_process(1.0/60.0)
		if player.health < player.max_health: break
	assert(player.health == player.max_health-1,"Expanding ring must deal real damage")
	player.invulnerability_remaining = 0.0
	hazard._physics_process(1.0/60.0)
	assert(player.health == player.max_health-1,"One ring cannot hit twice in the same cycle")

	hazard.emitters.assign(emitters)
	hazard.electrodes.assign(electrodes)
	player.global_position = room.map.get_node("Markers/DefenseSafePocket").global_position
	player.health = player.max_health
	hazard.reset_motion()
	for frame in range(300): hazard._physics_process(1.0/60.0)
	assert(player.health == player.max_health,"Safe pocket must remain safe")
	player.health = 1
	player.invulnerability_remaining = 0.0
	hazard.actor_hit.emit("扩散电圈")
	assert(player.is_dead and paused)
	time = hazard.elapsed
	hazard._physics_process(1.0)
	assert(hazard.elapsed == time)
	room._retry()
	assert(not player.is_dead and player.health == player.max_health and not paused)
	assert(hazard.elapsed == 0.0 and hazard.orbs.is_empty())
	for cycle in hazard.ring_hit_cycle: assert(cycle == -1)
	room.queue_free()
	await process_frame
	print("Entrance hazards: 8 emitters/7 electrodes, orb/ring damage, immunity, walls, safe pocket, pause, death/retry: PASS")
	quit()
