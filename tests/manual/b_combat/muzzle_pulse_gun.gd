extends "res://scenes/weapons/pulse_gun.gd"
## B-only muzzle adapter. Shared beam timing/damage logic remains inherited.
var muzzle_owner: Node2D
var use_muzzle: bool = true

func request_fire(direction: Vector2) -> bool:
	var accepted := super.request_fire(direction)
	refresh_muzzle_visuals()
	return accepted

func advance_time(delta: float, origin: Vector2, current_direction: Vector2 = Vector2.ZERO) -> void:
	var start := origin
	if use_muzzle and is_instance_valid(muzzle_owner):
		start = muzzle_owner.get_shot_origin(1).position
	super.advance_time(delta, start, current_direction)
	refresh_muzzle_visuals()

func update_beam(origin: Vector2) -> void:
	if not use_muzzle or not is_instance_valid(muzzle_owner):
		super.update_beam(origin)
		return
	var start: Dictionary = muzzle_owner.get_shot_origin(1)
	if start.blocked and state == State.FIRING:
		# The body-to-muzzle segment cannot bypass a wall or an overlapping enemy.
		beam_points = PackedVector2Array([start.position])
		beam.visible = false
		beam_core.visible = false
		if contact_remaining < 0.0:
			contact_remaining = CONTACT_DURATION
		var target: Object = start.target
		if is_instance_valid(target) and not damaged_targets.has(target.get_instance_id()):
			damaged_targets[target.get_instance_id()] = true
			target.apply_damage(beam_damage)
		return
	super.update_beam(start.position)

func refresh_muzzle_visuals() -> void:
	if not use_muzzle or not is_instance_valid(muzzle_owner):
		return
	var start: Dictionary = muzzle_owner.get_shot_origin(1)
	charge_glow.position = to_local(start.position)
	if state == State.FIRING:
		update_beam(start.position)
