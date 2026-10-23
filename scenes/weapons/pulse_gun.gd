extends Node2D

signal state_changed(state_name: StringName)
signal shot_fired(world_position: Vector2)
signal beam_finished

const LASER_TRACE := preload("res://scenes/weapons/laser_trace.gd")
const CHARGE_DURATION: float = 0.8
const BEAM_DURATION: float = 0.5
const CONTACT_DURATION: float = 0.15
var contact_remaining: float = -1.0

enum State { IDLE, CHARGING, FIRING }

const AIM_HALF_ANGLE: float = PI / 18.0
@export var beam_damage: int = 1
## Reach any map-sized path progressively, without a fixed distance cap.
@export var beam_extension_duration: float = 0.3
var map_bounds := Rect2()
var aim_visibility: Callable

func configure_space(bounds: Rect2, visible_query: Callable) -> void:
	map_bounds = bounds
	aim_visibility = visible_query


var state: State = State.IDLE
var remaining: float = 0.0
var locked_direction: Vector2 = Vector2.RIGHT
var pending_direction: Vector2 = Vector2.RIGHT
var damaged_targets: Dictionary = {}
var beam_points := PackedVector2Array()

@onready var beam: Line2D = $Beam
@onready var beam_core: Line2D = $BeamCore
@onready var charge_glow: Polygon2D = $ChargeGlow


func request_fire(direction: Vector2) -> bool:
	if state != State.IDLE or direction.is_zero_approx():
		return false
	if map_bounds.size.x <= 0.0 or map_bounds.size.y <= 0.0:
		push_error("PulseGun requires current map world bounds via configure_space().")
		return false
	pending_direction = direction.normalized()
	damaged_targets.clear()
	contact_remaining = -1.0
	state = State.CHARGING
	remaining = CHARGE_DURATION
	charge_glow.visible = true
	charge_glow.scale = Vector2.ONE * 0.35
	state_changed.emit(&"charging")
	return true


func advance_time(delta: float, origin: Vector2, current_direction: Vector2 = Vector2.ZERO) -> void:
	if state == State.IDLE:
		return
	if state == State.FIRING and contact_remaining >= 0.0:
		contact_remaining -= delta
		if contact_remaining <= 0.000001:
			cancel()
			return
	remaining -= delta
	if state == State.CHARGING:
		if not current_direction.is_zero_approx():
			pending_direction = current_direction.normalized()
		charge_glow.scale = Vector2.ONE * lerpf(0.35, 1.0, clampf(1.0 - remaining / CHARGE_DURATION, 0.0, 1.0))
		if remaining > 0.000001:
			return
		locked_direction = assisted_direction(origin, pending_direction)
		state = State.FIRING
		# Carry over the fractional frame, so low FPS never lengthens the beam.
		remaining = BEAM_DURATION + minf(remaining, 0.0)
		charge_glow.visible = false
		state_changed.emit(&"firing")
		shot_fired.emit(origin)
	if remaining <= 0.000001 and contact_remaining < 0.0:
		cancel()
		return
	update_beam(origin)


func update_beam(origin: Vector2) -> void:
	if state != State.FIRING:
		return
	# Trace from the body, not a muzzle that could already be on the far side of a wall.
	var elapsed := maxf(0.0, BEAM_DURATION - remaining)
	var full_length := LASER_TRACE.distance_to_boundary(origin, locked_direction, map_bounds)
	var visible_length := full_length * clampf(elapsed / maxf(beam_extension_duration, 0.001), 0.0, 1.0)
	# Collision and damage use the visible tip, never the unrevealed full path.
	var result := LASER_TRACE.trace(get_world_2d().direct_space_state, origin, locked_direction, visible_length)
	if result.hit and contact_remaining < 0.0:
		contact_remaining = CONTACT_DURATION
	beam_points = result.points
	var local_points := PackedVector2Array()
	for point in beam_points:
		local_points.append(beam.to_local(point))
	beam.points = local_points
	beam_core.points = local_points
	beam.visible = true
	beam_core.visible = true
	var target: Object = result.target
	if is_instance_valid(target):
		var target_id := target.get_instance_id()
		if not damaged_targets.has(target_id):
			# Record before callbacks; the same enemy still blocks subsequent frames.
			damaged_targets[target_id] = true
			if target.has_method("apply_damage"):
				target.apply_damage(beam_damage)
			else:
				push_error("Laser enemy collider must provide apply_damage(amount).")


func cancel() -> void:
	var was_firing := state == State.FIRING
	var was_active := state != State.IDLE
	state = State.IDLE
	remaining = 0.0
	contact_remaining = -1.0
	damaged_targets.clear()
	beam_points.clear()
	beam.clear_points()
	beam_core.clear_points()
	beam.visible = false
	beam_core.visible = false
	charge_glow.visible = false
	if was_active:
		state_changed.emit(&"idle")
	if was_firing:
		beam_finished.emit()


func assisted_direction(origin: Vector2, requested: Vector2) -> Vector2:
	var chosen := requested.normalized()
	var best_angle := AIM_HALF_ANGLE + 0.000001
	var best_distance := INF
	if not aim_visibility.is_valid():
		return chosen
	for enemy in get_tree().get_nodes_in_group("combat_enemies"):
		if not enemy is CollisionObject2D or not enemy.has_method("get_combat_state"):
			continue
		if not enemy.get_combat_state().alive or not map_bounds.has_point(enemy.global_position):
			continue
		if not aim_visibility.call(enemy):
			continue
		var offset: Vector2 = enemy.global_position - origin
		if offset.is_zero_approx():
			continue
		var angle := absf(requested.angle_to(offset))
		if angle > AIM_HALF_ANGLE + 0.000001:
			continue
		var distance := offset.length_squared()
		if angle > best_angle or (is_equal_approx(angle, best_angle) and distance >= best_distance):
			continue
		var query := PhysicsRayQueryParameters2D.create(origin, enemy.global_position, 5)
		query.collide_with_areas = true
		query.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider != enemy:
			continue
		chosen = offset.normalized()
		best_angle = angle
		best_distance = distance
	return chosen
