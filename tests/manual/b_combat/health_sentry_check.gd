extends SceneTree

const BULLET := preload("res://scenes/weapons/enemy_projectile.tscn")
var failures: int = 0
var visible_to_player: bool = true

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func visible_query(_enemy: Node2D) -> bool:
	return visible_to_player

func run_checks() -> void:
	var room := load("res://tests/manual/b_combat/combat_test.tscn").instantiate() as Node2D
	root.add_child(room)
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").set_physics_process(false)
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").collision_layer = 0
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").remove_from_group("combat_enemies")
	current_scene = room
	var player := room.get_node("SpawnPoints/PlayerSpawn/Player")
	var sentry := room.get_node("SpawnPoints/SentrySpawn/Sentry")
	var bullets := room.get_node("EnemyProjectiles")
	player.set_physics_process(false)
	sentry.set_physics_process(false)
	sentry.configure(player, visible_query, bullets)
	var deaths := [0]
	player.died.connect(func(): deaths[0] += 1)
	player.apply_damage(1)
	player.apply_damage(1)
	check(player.health == 2, "Same-frame player damage must respect immunity.")
	player._physics_process(0.79)
	player.apply_damage(1)
	check(player.health == 2, "Player is still immune before 0.8 seconds.")
	player._physics_process(0.02)
	player.apply_damage(1)
	check(player.health == 1, "Damage resumes after immunity expires.")
	player.invulnerability_remaining = 0.0
	player.apply_damage(1)
	player.apply_damage(1)
	check(player.is_dead and deaths[0] == 1 and not player.controls_enabled, "Death notifies once and disables controls.")
	check(player.pulse_gun.state == player.pulse_gun.State.IDLE, "Death cancels laser.")
	player.restore_player(Vector2(700, 224), 3, [&"pulse_gun"])
	check(player.health == 3 and not player.is_dead and player.pulse_gun_equipped, "Restore resets player and retained weapon.")
	await physics_frame

	sentry._physics_process(0.01)
	check(sentry.state == sentry.State.WARNING and bullets.get_child_count() == 0, "Detection begins warning, not damage.")
	sentry._physics_process(0.749)
	check(bullets.get_child_count() == 0, "Warning must finish before shooting.")
	sentry._physics_process(0.001)
	check(bullets.get_child_count() == 1, "First bullet after full warning.")
	visible_to_player = false
	sentry._physics_process(0.5)
	check(sentry.state == sentry.State.IDLE and sentry.shots_left == 0, "Lost visibility cancels remainder.")
	check(bullets.get_child_count() == 1, "Lost visibility must not erase fired bullet.")
	visible_to_player = true
	sentry._physics_process(0.01)
	check(sentry.state == sentry.State.WARNING and sentry.remaining == 0.75, "Reacquisition restarts full warning.")
	for bullet in bullets.get_children():
		bullet.free()
	sentry._physics_process(0.75)
	sentry._physics_process(0.2)
	sentry._physics_process(0.2)
	check(bullets.get_child_count() == 3 and sentry.state == sentry.State.RECOVERY, "Sentry fires three then recovers.")
	for bullet in bullets.get_children():
		bullet.free()
	sentry.global_position = Vector2(500, 224)
	player.global_position = Vector2(380, 224)
	await physics_frame
	sentry._physics_process(0.1)
	check(sentry.state == sentry.State.IDLE, "Wall LOS blocks discovery.")

	sentry.apply_damage(1)
	sentry.apply_damage(1)
	check(sentry.health == 1, "Enemy has no damage immunity or flash immunity.")
	sentry.apply_damage(1)
	check(sentry.state == sentry.State.DEAD, "Enemy reaches dead state.")
	sentry._physics_process(5.0)
	check(bullets.get_child_count() == 0, "Dead enemy cannot attack.")
	await process_frame
	check(sentry.collision_layer == 0, "Dead enemy no longer blocks laser.")
	room.reset_test_combat()
	check(sentry.health == sentry.max_health and sentry.state == sentry.State.IDLE, "Test reset restores enemy without old attack.")
	player.restore_player(Vector2(700, 224), 3, [&"pulse_gun"])
	await physics_frame
	await physics_frame
	var projectile := BULLET.instantiate()
	bullets.add_child(projectile)
	projectile.global_position = Vector2(650, 224)
	projectile.direction = Vector2.RIGHT
	projectile._physics_process(0.5)
	check(projectile.spent and player.health == 2, "Swept enemy bullet damages player once.")
	projectile._physics_process(0.5)
	check(player.health == 2, "Spent enemy projectile cannot hit twice.")
	var wall_projectile := BULLET.instantiate()
	bullets.add_child(wall_projectile)
	wall_projectile.global_position = Vector2(650, 448)
	wall_projectile.direction = Vector2.RIGHT
	wall_projectile._physics_process(1.0)
	check(wall_projectile.spent and wall_projectile.global_position.x <= 696.1, "Enemy projectile stops at thin wall.")
	await process_frame
	room.reset_test_combat()
	await process_frame
	check(bullets.get_child_count() == 0, "Reset clears all enemy projectiles.")
	sentry.global_position = Vector2(800, 224)
	player.restore_player(Vector2(700, 224), 3, [&"pulse_gun"])
	await physics_frame
	await physics_frame
	player.pulse_gun.request_fire(Vector2.RIGHT)
	player.pulse_gun.advance_time(1.1, player.global_position)
	check(sentry.health == 2, "Player laser must damage the real sentry.")
	player.pulse_gun.update_beam(player.global_position)
	check(sentry.health == 2, "Same laser must not repeatedly damage real sentry.")
	player.pulse_gun.cancel()
	await create_timer(0.15).timeout
	room.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Health and sentry checks: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
