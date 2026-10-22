extends SceneTree

var failures: int = 0
var player: CharacterBody2D


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func travel(start: Vector2, actions: Array, frames: int) -> Vector2:
	player.global_position = start
	player.velocity = Vector2.ZERO
	for action in actions:
		Input.action_press(action)
	for frame in range(frames):
		await physics_frame
		player._physics_process(1.0 / 60.0)
	for action in actions:
		Input.action_release(action)
	return player.global_position - start


func _run() -> void:
	var room := load("res://tests/manual/b_combat/combat_test.tscn").instantiate() as Node2D
	root.add_child(room)
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").set_physics_process(false)
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").collision_layer = 0
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").remove_from_group("combat_enemies")
	room.get_node("SpawnPoints/SentrySpawn/Sentry").set_physics_process(false)
	player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	player.set_physics_process(false)
	await physics_frame

	var straight := await travel(Vector2(160, 160), [&"move_right"], 30)
	var diagonal := await travel(Vector2(160, 160), [&"move_right", &"move_down"], 30)
	check(absf(straight.length() - 80.0) < 0.5, "Straight speed must be 160 px/s.")
	check(absf(straight.length() - diagonal.length()) < 0.5, "Diagonal must not accelerate.")

	var before := player.global_position
	await physics_frame
	player._physics_process(1.0 / 60.0)
	check(player.global_position.is_equal_approx(before), "Released movement must stop.")
	player.aim_at(player.global_position + Vector2.LEFT * 100.0)
	check(player.aim_direction.is_equal_approx(Vector2.LEFT), "Aim must use world target.")
	check(player.global_position.is_equal_approx(before), "Aiming must not move the player.")
	player.aim_at(player.global_position)
	check(player.aim_direction.is_equal_approx(Vector2.LEFT), "Zero aim must preserve facing.")
	player.velocity = Vector2.UP * 160.0
	player.aim_at(player.global_position + Vector2.RIGHT * 100.0)
	check(player.velocity == Vector2.UP * 160.0, "Aim must not alter movement velocity.")
	check(absf(player.get_node("Facing").global_rotation) < 0.001, "Visual must face target.")

	await travel(Vector2(160, 320), [&"move_left"], 90)
	check(player.global_position.x >= 41.9, "Player must not cross outer wall.")
	await travel(Vector2(350, 224), [&"move_right"], 60)
	check(player.global_position.x <= 390.1, "Player must not cross central partition.")
	await travel(Vector2(650, 448), [&"move_right"], 60)
	check(player.global_position.x <= 686.1, "Player must not cross thin wall.")
	var slide := await travel(Vector2(390, 200), [&"move_right", &"move_down"], 30)
	check(player.global_position.x <= 390.1 and slide.y > 40.0, "Player must slide along wall.")

	# A large per-frame displacement must still collide, rather than teleport through.
	player.move_speed = 12000.0
	await travel(Vector2(650, 448), [&"move_right"], 1)
	check(player.global_position.x <= 686.1, "Swept movement must not tunnel through thin wall.")
	print("Movement checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
