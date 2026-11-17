extends "res://tests/manual/b_combat/web_cleaner.gd"
## The two exit cleaners coordinate around the existing machine in the abdomen.
const ROUTE_CLEARANCE := 48.0
const RETREAT_LEAD := 56.0
const COVERING_DISTANCE := 300.0

var partner: CharacterBody2D
var retreat_point := Vector2.ZERO
var engaged := false
var covers_retreat := false
var taking_side_route := false
var side_waypoint := Vector2.ZERO

func configure_pair(other: CharacterBody2D, machine: Node2D, retreat: Vector2) -> void:
	partner = other
	retreat_point = retreat
	var bounds := Rect2(Vector2.ZERO, machine.size).grow(ROUTE_CLEARANCE)
	var left := machine.to_global(Vector2(bounds.position.x, bounds.end.y))
	var right := machine.to_global(bounds.end)
	side_waypoint = left if home.distance_squared_to(left) <= home.distance_squared_to(right) else right

func engage(covering: bool) -> void:
	engaged = true
	covers_retreat = covering
	taking_side_route = not covering
	if covering:
		web_cooldown = 0.0

func disengage() -> void:
	engaged = false
	taking_side_route = false

func _partner_alive() -> bool:
	return is_instance_valid(partner) and partner.health > 0

func _partner_winding_up() -> bool:
	# Winding up only after the other strike starts leaves at least one
	# full telegraph (0.55 s for silk, 0.65 s for melee) between strike starts.
	return _partner_alive() and (partner.web_phase == 1 or partner.state == State.WARNING)

func _can_start_web() -> bool:
	return (covers_retreat or not _partner_alive()) and not _partner_winding_up() and is_on_screen() and super._can_start_web()

func _web_aim_point() -> Vector2:
	if covers_retreat and _partner_alive():
		# Place silk on the way back to the entrance. Keep the telegraphed
		# direction fixed after aiming and use the player if cover blocks the lead.
		var lead := target.global_position.move_toward(retreat_point, RETREAT_LEAD)
		if has_clear_line(eye_origin(), lead):
			return lead
	return super._web_aim_point()

func _chase_target() -> void:
	var destination := target.global_position
	var distance := global_position.distance_to(destination)
	if distance <= PARAMETERS.CLEANER_ATTACK_DISTANCE and has_clear_line(global_position, destination):
		velocity = Vector2.ZERO
		if not _partner_winding_up():
			super._chase_target()
		return
	if _partner_alive():
		if taking_side_route:
			if global_position.distance_squared_to(side_waypoint) > 14.0 * 14.0:
				move_toward_point(side_waypoint, PARAMETERS.CLEANER_CHASE_SPEED)
				return
			taking_side_route = false
		if covers_retreat and distance > WEB_MIN_DISTANCE and distance <= COVERING_DISTANCE and is_on_screen() and has_clear_line(eye_origin(), _web_aim_point()):
			velocity = Vector2.ZERO
			return
	move_toward_point(destination, PARAMETERS.CLEANER_CHASE_SPEED, ATTACK_APPROACH_DISTANCE)

func patrol() -> void:
	if global_position.distance_squared_to(home) > 6.0 * 6.0:
		move_toward_point(home, PARAMETERS.CLEANER_PATROL_SPEED)
	else:
		velocity = Vector2.ZERO
