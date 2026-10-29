extends SceneTree

const TRACE := preload("res://scenes/weapons/laser_trace.gd")

class DamageTarget extends StaticBody2D:
	var hit_count: int = 0
	func apply_damage(_amount: int) -> void:
		hit_count += 1

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func make_target(room: Node, location: Vector2) -> DamageTarget:
	var target := DamageTarget.new()
	target.collision_layer = 4
	target.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 32)
	shape.shape = rectangle
	target.add_child(shape)
	room.add_child(target)
	target.global_position = location
	return target

func _run() -> void:
	var room := load("res://tests/manual/b_combat/combat_test.tscn").instantiate() as Node2D
	root.add_child(room)
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").set_physics_process(false)
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").collision_layer = 0
	room.get_node("SpawnPoints/CleanerSpawn/Cleaner").remove_from_group("combat_enemies")
	room.get_node("SpawnPoints/SentrySpawn/Sentry").set_physics_process(false)
	current_scene = room
	var player := room.get_node("SpawnPoints/PlayerSpawn/Player")
	player.set_physics_process(false)
	var gun := player.get_node("Facing/PulseGun")
	gun.use_muzzle = false # Core beam tests supply explicit origins; muzzle integration has its own checks.
	await physics_frame
	var origin := Vector2(160, 500)
	check(gun.request_fire(Vector2.RIGHT), "Click must begin charging.")
	check(not gun.request_fire(Vector2.UP), "Cannot replace or queue a shot while busy.")
	gun.advance_time(0.799, origin)
	check(gun.state == gun.State.CHARGING and gun.beam_points.is_empty(), "No beam before 0.8 seconds.")
	player.aim_at(player.global_position + Vector2.UP * 100.0)
	check(player.aim_direction == Vector2.UP, "Charging follows the latest mouse direction.")
	gun.advance_time(0.001, origin)
	check(gun.state == gun.State.FIRING and gun.beam_points.size() == 1, "0.8 seconds starts beam.")
	check(gun.get_node("Audio/Laser").playing and not gun.get_node("Audio/Charge").playing, "Firing switches charge sound to laser sound.")
	check(gun.beam_points[0].is_equal_approx(origin), "Beam starts at supplied player position.")
	gun.advance_time(0.1, origin + Vector2(0, 20))
	check(gun.beam_points[0].distance_to(gun.beam_points[-1]) < 800.0, "Early beam must not reveal full range.")
	check(gun.beam_points[0].is_equal_approx(origin + Vector2(0, 20)), "Beam origin follows player.")
	check((gun.beam_points[1] - gun.beam_points[0]).normalized().is_equal_approx(Vector2.RIGHT), "Beam direction stays locked.")
	gun.advance_time(0.399, origin)
	check(gun.state == gun.State.FIRING, "Beam remains active just before half a second.")
	gun.advance_time(0.149, origin)
	check(gun.state == gun.State.FIRING, "Late contact still receives full contact duration.")
	gun.advance_time(0.001, origin)
	check(gun.state == gun.State.IDLE and gun.beam_points.is_empty(), "Beam ends 0.15 seconds after contact.")
	check(not gun.get_node("Audio/Charge").playing and not gun.get_node("Audio/Laser").playing, "End stops both sounds.")
	gun.advance_time(10.0, origin)
	check(gun.state == gun.State.IDLE, "No automatic repeat or queued shot.")
	check(gun.request_fire(Vector2.RIGHT), "Next click works immediately after beam ends.")
	gun.advance_time(3.1, origin)
	check(gun.state == gun.State.IDLE, "Large frame cannot extend total lifetime.")

	var space := room.get_world_2d().direct_space_state
	var front: PackedVector2Array = TRACE.trace(space, Vector2(350, 224), Vector2.RIGHT, 100.0).points
	check(front.size() == 2 and front[1].is_equal_approx(Vector2(400, 224)), "Wall terminates beam without reflection.")
	var thin: PackedVector2Array = TRACE.trace(space, Vector2(650, 448), Vector2.RIGHT, 100.0).points
	check(thin.size() == 2 and absf(thin[1].x - 696.0) < 0.01, "Thin wall stops beam.")
	var large_bounds := Rect2(0, 0, 10000, 10000)
	var distance := TRACE.distance_to_boundary(Vector2(2000, 2000), Vector2.RIGHT, large_bounds)
	check(distance == 8000.0, "No old 48-tile limit; path ends at map boundary.")
	var long_beam: PackedVector2Array = TRACE.trace(space, Vector2(2000, 2000), Vector2.RIGHT, distance).points
	check(long_beam[-1] == Vector2(10000, 2000), "Unobstructed beam reaches map boundary.")

	var sentry := room.get_node("SpawnPoints/SentrySpawn/Sentry")
	gun.aim_visibility = func(_enemy): return true # Explicit test adapter.
	var aim_origin := Vector2(700, 224)
	for degrees in [-10.0, -9.0, 9.0, 10.0]:
		var corrected: Vector2 = gun.assisted_direction(aim_origin, Vector2.RIGHT.rotated(deg_to_rad(degrees)))
		check(corrected.is_equal_approx(Vector2.RIGHT), "Targets within plus/minus 10 degrees are acquired.")
	var outside := Vector2.RIGHT.rotated(deg_to_rad(11.0))
	check(gun.assisted_direction(aim_origin, outside).is_equal_approx(outside), "Outside cone keeps original aim.")
	gun.aim_visibility = func(_enemy): return false
	var near := Vector2.RIGHT.rotated(deg_to_rad(5.0))
	check(gun.assisted_direction(aim_origin, near).is_equal_approx(near), "Unreadable enemy is not acquired.")
	gun.aim_visibility = func(_enemy): return true
	sentry.global_position = Vector2(500, 224)
	await physics_frame
	await physics_frame
	check(gun.assisted_direction(Vector2(380, 224), near).is_equal_approx(near), "Wall blocks aim assist.")
	sentry.global_position = Vector2(800, 224)
	sentry.apply_damage(3)
	await physics_frame
	check(gun.assisted_direction(aim_origin, near).is_equal_approx(near), "Dead enemy is not acquired.")
	sentry.restore_combat_state({"entity_id": &"sentry_test_01", "health": 3})
	await physics_frame
	await physics_frame
	check(gun.request_fire(Vector2.UP), "Assisted click starts charging.")
	gun.advance_time(0.7, aim_origin, Vector2.UP)
	gun.advance_time(0.1, aim_origin, near)
	check(gun.locked_direction.is_equal_approx(Vector2.RIGHT), "Charge completion uses latest aim and applies assistance.")
	gun.advance_time(0.05, aim_origin, Vector2.DOWN)
	check(gun.locked_direction.is_equal_approx(Vector2.RIGHT), "Mouse movement after firing cannot change locked direction.")
	gun.cancel()
	var target := make_target(room, Vector2(240, 500))
	var behind := make_target(room, Vector2(300, 500))
	await physics_frame
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.8, origin)
	gun.advance_time(0.02, origin)
	check(target.hit_count == 0, "Unrevealed beam must not damage distant enemy.")
	gun.advance_time(0.08, origin)
	check(target.hit_count == 1 and behind.hit_count == 0, "First enemy blocks beam and takes damage.")
	for index in range(20):
		gun.update_beam(origin)
	check(target.hit_count == 1, "Same beam must not damage same enemy repeatedly.")
	check(gun.beam_points[-1].x <= 232.1, "Visual beam ends at enemy surface.")
	target.position = Vector2(240, 560)
	await physics_frame
	gun.update_beam(origin)
	check(behind.hit_count == 1, "A new enemy can be hit when the previous one moves away.")
	target.position = Vector2(240, 500)
	await physics_frame
	gun.update_beam(origin)
	check(target.hit_count == 1, "Leaving and reentering same beam must not cause another hit.")
	gun.cancel()
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.9, origin)
	check(target.hit_count == 2, "A new beam can damage that enemy again.")
	gun.cancel()
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.8, origin)
	gun.advance_time(0.1, origin)
	check(is_equal_approx(gun.contact_remaining, 0.15), "Enemy contact starts 0.15 second timer.")
	gun.advance_time(0.149, origin)
	check(gun.state == gun.State.FIRING, "Contact beam remains for 0.149 seconds.")
	gun.advance_time(0.001, origin)
	check(gun.state == gun.State.IDLE, "Enemy contact beam disappears after 0.15 seconds.")
	var count_after_contact: int = target.hit_count
	target.position = Vector2(320, 224)
	await physics_frame
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.9, Vector2(350, 224))
	check(target.hit_count == count_after_contact and gun.beam_points.size() == 2, "Wall must not reflect beam into enemy behind shooter.")
	check(is_equal_approx(gun.contact_remaining, 0.15), "Wall contact starts timer.")
	gun.advance_time(0.15, Vector2(350, 224))
	check(gun.state == gun.State.IDLE, "Wall contact ends laser in 0.15 seconds.")
	gun.cancel()
	check(gun.beam_points.is_empty() and not gun.get_node("Beam").visible, "Cancel clears beam visuals and damage state.")

	var click := InputEventAction.new()
	click.action = &"shoot"
	click.pressed = true
	player._unhandled_input(click)
	check(gun.state == gun.State.CHARGING, "Player click event must start charging.")
	check(gun.get_node("Audio/Charge").playing, "Click starts charge audio.")
	Input.action_press(&"shoot")
	player._physics_process(3.1)
	player._physics_process(0.1)
	check(gun.state == gun.State.IDLE, "Holding the button must not trigger another charge.")
	Input.action_release(&"shoot")
	player._unhandled_input(click)
	check(gun.state == gun.State.CHARGING, "A new click must start a new charge.")
	player.controls_enabled = false
	player._physics_process(0.1)
	check(gun.state == gun.State.IDLE, "Disabling player controls must cancel attack.")
	player.controls_enabled = true

	# Real scene-tree pause must freeze the same clock used in normal player updates.
	player.set_physics_process(true)
	gun.request_fire(Vector2.RIGHT)
	paused = true
	var time_before: float = gun.remaining
	for index in range(4):
		await process_frame
	check(gun.remaining == time_before, "Pause freezes charge timer.")
	paused = false
	player.set_physics_process(false)
	gun.cancel()
	await create_timer(0.15).timeout
	room.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	print("Laser checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
