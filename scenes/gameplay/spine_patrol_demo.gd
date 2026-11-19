extends "res://tests/manual/b_combat/web_cleaner.gd"
## This maintenance unit demonstrates a route and never enters combat.
const SPEED := 94.0
const START_PAUSE := 0.7
const INSPECTION_PAUSE := 1.25

var waypoints := PackedVector2Array()
var loop_time := 0.0
var loop_duration := START_PAUSE
var stop_after := 0
var _inspection_time := 0.0

func _ready() -> void:
	super._ready()
	remove_from_group("combat_enemies")
	remove_from_group("cleaners")
	collision_layer = 0
	collision_mask = 0
	$Health.hide()

func configure_loop(points: PackedVector2Array, inspection_after_segment: int) -> void:
	waypoints = points.duplicate()
	stop_after = inspection_after_segment
	loop_duration = START_PAUSE
	for i in range(waypoints.size()):
		loop_duration += waypoints[i].distance_to(waypoints[(i + 1) % waypoints.size()]) / SPEED
		if i + 1 == stop_after:
			_inspection_time = loop_duration
	loop_duration += INSPECTION_PAUSE
	var visual := combat_visual()
	visual.hurt_shape = null
	var hurtbox := get_node_or_null("ModelHurtbox")
	if hurtbox != null:
		remove_child(hurtbox)
		hurtbox.queue_free()
	restore_loop(0.0)

func can_detect() -> bool:
	return false

func apply_damage(_amount: int) -> void:
	pass

func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return
	var was_inspecting := _is_inspecting()
	loop_time = fposmod(loop_time + delta, loop_duration)
	_place_on_loop()
	if was_inspecting != _is_inspecting():
		queue_redraw()

func _draw() -> void:
	# Matches the starting marker so players can pick out the guide in a group.
	draw_arc(Vector2(0, 4), 16.0, 0.0, TAU, 24, Color("302823"), 4.0)
	draw_arc(Vector2(0, 4), 16.0, 0.0, TAU, 24, Color("f0cd8a"), 2.0)
	if _is_inspecting():
		draw_arc(Vector2(0, 4), 23.0, 0.0, TAU, 28, Color("81e2db"), 3.0)

func _is_inspecting() -> bool:
	return stop_after > 0 and loop_time >= _inspection_time and loop_time < _inspection_time + INSPECTION_PAUSE

func restore_combat_state(snapshot: Dictionary) -> void:
	super.restore_combat_state(snapshot)
	restore_loop(0.0)

func restore_loop(seconds: float) -> void:
	health = max_health
	state = State.PATROL
	remaining = 0.0
	hurt_flash = 0.0
	web_phase = 0
	attack_hit = false
	velocity = Vector2.ZERO
	collision_layer = 0
	loop_time = fposmod(seconds, loop_duration)
	if not waypoints.is_empty():
		_place_on_loop()
	update_visuals()
	queue_redraw()

func _place_on_loop() -> void:
	var inspection_elapsed := clampf(loop_time - _inspection_time, 0.0, INSPECTION_PAUSE)
	var travel := maxf(0.0, loop_time - START_PAUSE - inspection_elapsed) * SPEED
	for i in range(waypoints.size()):
		var from := waypoints[i]
		var to := waypoints[(i + 1) % waypoints.size()]
		var distance := from.distance_to(to)
		if travel <= distance:
			global_position = from.move_toward(to, travel)
			$Facing.rotation = from.angle_to_point(to)
			return
		travel -= distance
