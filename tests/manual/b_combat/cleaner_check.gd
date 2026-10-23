extends SceneTree
var failures: int = 0
var readable: bool = true
var protocol: bool = false
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func can_read(_enemy: Node2D) -> bool:
	return readable
func in_protocol() -> bool:
	return protocol
func run_checks() -> void:
	var room := load("res://tests/manual/b_combat/combat_test.tscn").instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	var player := room.get_node("SpawnPoints/PlayerSpawn/Player")
	var cleaner := room.get_node("SpawnPoints/CleanerSpawn/Cleaner")
	room.get_node("SpawnPoints/SentrySpawn/Sentry").set_physics_process(false)
	player.set_physics_process(false)
	cleaner.set_physics_process(false)
	cleaner.configure(player, can_read, in_protocol)
	player.restore_player(Vector2(640, 500), 3, [&"pulse_gun"])
	cleaner.global_position = Vector2(600, 500)
	await physics_frame
	await physics_frame
	cleaner._physics_process(0.01)
	check(cleaner.state == cleaner.State.CHASE, "Detection starts chase.")
	cleaner._physics_process(0.01)
	check(cleaner.state == cleaner.State.WARNING, "Near target begins warning.")
	cleaner._physics_process(0.649)
	check(player.health == 3 and cleaner.state == cleaner.State.WARNING, "Warning must be harmless.")
	cleaner._physics_process(0.001)
	check(player.health == 2 and cleaner.state == cleaner.State.ATTACK, "Front region damages after warning.")
	player.invulnerability_remaining = 0.0
	cleaner._physics_process(0.01)
	check(player.health == 2, "Each melee swing hits once even without player immunity.")
	cleaner._physics_process(0.2)
	check(cleaner.state == cleaner.State.RECOVERY, "Attack ends in recovery.")
	cleaner.state = cleaner.State.ATTACK
	cleaner.remaining = 0.1
	cleaner.attack_hit = false
	protocol = true
	cleaner._physics_process(0.01)
	check(player.health == 2 and cleaner.state == cleaner.State.RECOVERY and cleaner.velocity == Vector2.ZERO, "Protocol cancels active damage immediately.")
	cleaner._physics_process(0.65)
	cleaner._physics_process(0.01)
	check(cleaner.state == cleaner.State.PATROL, "Protocol player is ignored during patrol.")
	protocol = false
	cleaner.global_position = Vector2(600, 500)
	cleaner._physics_process(0.01)
	cleaner._physics_process(0.01)
	check(cleaner.state == cleaner.State.WARNING and is_equal_approx(cleaner.remaining, 0.65), "Protocol exit requires a full new warning.")
	readable = false
	cleaner._physics_process(0.01)
	check(cleaner.state == cleaner.State.RECOVERY and not cleaner.get_node("Facing/AttackZone").visible, "Lost visibility cancels warning and hit region.")
	readable = true
	player.global_position = Vector2(450, 224)
	cleaner.global_position = Vector2(380, 224)
	cleaner.state = cleaner.State.CHASE
	await physics_frame
	await physics_frame
	cleaner._physics_process(0.01)
	check(cleaner.state == cleaner.State.RECOVERY, "Wall blocks pursuit; no stale target chase.")
	# Visible player behind the locked attack direction is outside the damage region.
	player.restore_player(Vector2(560, 500), 3, [&"pulse_gun"])
	cleaner.global_position = Vector2(600, 500)
	cleaner.state = cleaner.State.ATTACK
	cleaner.locked_direction = Vector2.RIGHT
	cleaner.attack_hit = false
	await physics_frame
	await physics_frame
	cleaner.try_melee_hit()
	check(player.health == 3, "Melee does not hit behind cleaner.")
	var deaths := [0]
	cleaner.died.connect(func(_id): deaths[0] += 1)
	cleaner.apply_damage(1)
	cleaner.apply_damage(1)
	check(cleaner.health == 1, "Cleaner has no damage immunity.")
	cleaner.apply_damage(1)
	cleaner.apply_damage(1)
	check(cleaner.state == cleaner.State.DEAD and deaths[0] == 1, "Cleaner dies once and cancels attack.")
	await process_frame
	room.reset_test_combat()
	check(cleaner.health == 3 and cleaner.state == cleaner.State.PATROL and cleaner.global_position == cleaner.home, "Reset restores patrol baseline without attack remnants.")
	readable = false
	var before: Vector2 = cleaner.global_position
	for index in range(10):
		await physics_frame
		cleaner._physics_process(1.0 / 60.0)
	check(cleaner.global_position.distance_to(before) > 1.0, "Patrol actually moves.")
	readable = true
	player.restore_player(Vector2(600, 500), 3, [&"pulse_gun"])
	cleaner.global_position = Vector2(640, 500)
	await physics_frame
	await physics_frame
	player.pulse_gun.request_fire(Vector2.RIGHT)
	player.pulse_gun.advance_time(1.1, player.global_position, Vector2.RIGHT)
	check(cleaner.health == 2, "Laser damages real cleaner.")
	player.set_protocol_active(true)
	check(player.pulse_gun.state == player.pulse_gun.State.IDLE, "Protocol cancels player's attack.")
	await create_timer(0.15).timeout
	room.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Cleaner checks: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
