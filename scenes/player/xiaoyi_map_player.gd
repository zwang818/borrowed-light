extends "res://scenes/player/player.gd"
## Map adapter: retain production acquisition and input; reuse B muzzle rendering.
var attack_mode: int:
	get:
		return 1 if pulse_gun_equipped else 2
var mouse_facing: Vector2:
	get:
		return global_position.direction_to(get_global_mouse_position())

func _ready() -> void:
	# Replace only this graybox's weapon with the inherited muzzle adapter.
	var previous := $Facing/PulseGun
	$Facing.remove_child(previous)
	previous.free()
	pulse_gun = preload("res://tests/manual/b_combat/muzzle_pulse_gun.tscn").instantiate()
	pulse_gun.name = "PulseGun"
	pulse_gun.muzzle_owner = self
	$Facing.add_child(pulse_gun)
	super._ready()

func get_shot_origin(mode: int) -> Dictionary:
	var visual := get_node_or_null("Facing/XiaoyiCombatVisual")
	var desired: Vector2 = visual.get_muzzle_world_position(mode) if visual != null else global_position
	var query := PhysicsRayQueryParameters2D.create(global_position, desired, 5)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.collider if hit.collider.has_method("apply_damage") and (hit.collider.collision_layer & 1) == 0 else null
		return {"position": hit.position, "blocked": true, "target": target}
	var bounds: Rect2 = pulse_gun.map_bounds
	var outside := bounds.has_area() and not bounds.has_point(desired)
	return {"position": desired if not outside else global_position, "blocked": outside, "target": null}

