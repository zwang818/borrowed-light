extends SceneTree
const TRACE = preload("res://scenes/weapons/laser_trace.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room := Node2D.new()
	root.add_child(room)
	var enemy = load("res://scenes/enemies/cleaner/cleaner.tscn").instantiate()
	room.add_child(enemy)
	enemy.position = Vector2(300, 200)
	enemy.set_physics_process(false)
	var visual = load("res://tests/manual/b_combat/cleaner_visual.gd").new()
	visual.match_hurtbox = true
	enemy.add_child(visual)
	visual.set_physics_process(false)
	var gun = load("res://scenes/weapons/pulse_gun.tscn").instantiate()
	room.add_child(gun)
	gun.configure_space(Rect2(0,0,800,600), func(_unit): return true)
	await physics_frame
	await physics_frame
	var space := room.get_world_2d().direct_space_state
	assert(enemy.get_node("CollisionShape2D").shape.radius == 12.0)
	# Upper shell is visibly above the old 12px foot circle.
	var origin := Vector2(200,180)
	assert(TRACE.trace(space,origin,Vector2.RIGHT,200).target == enemy)
	assert(TRACE.trace(space,Vector2(200,120),Vector2.RIGHT,200).target == null)
	assert(gun.assisted_direction(Vector2(200,200),Vector2(1,0.05)).is_equal_approx(Vector2.RIGHT))
	var initial: int = enemy.health
	gun.request_fire(Vector2.RIGHT)
	gun.advance_time(0.9,origin)
	assert(enemy.health == initial-1 and enemy.hurt_flash > 0)
	# One beam crossing both the visual area and original body still damages once.
	for i in range(5):
		gun.update_beam(Vector2(200,200))
	assert(enemy.health == initial-1)
	for state in [enemy.State.PATROL,enemy.State.WARNING,enemy.State.ATTACK,enemy.State.RECOVERY]:
		enemy.state = state
		enemy.remaining = 0.1
		for mirrored in [false,true]:
			visual.face_left = mirrored
			visual._update_hurtbox()
			assert(visual.hurt_shape.polygon.size() >= 3)
	# A wall must still stop the enlarged hurtbox from receiving damage.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10,100)
	shape.shape = box
	wall.add_child(shape)
	room.add_child(wall)
	wall.position = Vector2(240,200)
	await physics_frame
	await physics_frame
	assert(TRACE.trace(space,origin,Vector2.RIGHT,200).target == null)
	wall.queue_free()
	enemy.apply_damage(999)
	await physics_frame
	await physics_frame
	assert(TRACE.trace(space,origin,Vector2.RIGHT,200).target == null)
	enemy.restore_combat_state({"entity_id":enemy.entity_id,"health":enemy.max_health,"position":enemy.position})
	visual._update_hurtbox()
	await physics_frame
	await physics_frame
	assert(TRACE.trace(space,origin,Vector2.RIGHT,200).target == enemy)
	room.queue_free()
	await process_frame
	print("Cleaner hurtbox: upper shell, empty space, aim assistance, single damage, animation, walls, death/restore: PASS")
	quit()
