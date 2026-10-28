extends "res://scenes/player/player.gd"
## B-only mode prototype: both abilities explicitly granted for testing.

enum AttackMode { LASER = 1, UNARMED = 2, SCATTER = 3 }
const PELLET := preload("res://tests/manual/b_combat/scatter_pellet.gd")
const SCATTER_INTERVAL: float = 0.75
var attack_mode: int = AttackMode.LASER
var scatter_remaining: float = 0.0
var mouse_facing := Vector2.RIGHT

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

func _physics_process(delta: float) -> void:
	scatter_remaining = maxf(0.0, scatter_remaining - delta)
	super._physics_process(delta)
	var offset := get_global_mouse_position() - global_position
	if not offset.is_zero_approx():
		mouse_facing = offset.normalized()

func set_attack_mode(next_mode: int) -> bool:
	if next_mode < 1 or next_mode > 3 or is_dead or not controls_enabled:
		return false
	if pulse_gun.state != pulse_gun.State.IDLE or scatter_remaining > 0.0:
		return false
	attack_mode = next_mode
	pulse_gun_equipped = attack_mode == AttackMode.LASER
	pulse_gun.visible = pulse_gun_equipped
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_1, KEY_2, KEY_3]:
			set_attack_mode(key - KEY_1 + 1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(shoot_action) and attack_mode == AttackMode.SCATTER:
		var offset := get_global_mouse_position() - global_position
		if not offset.is_zero_approx():
			mouse_facing = offset.normalized()
		fire_scatter(mouse_facing)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func fire_scatter(direction: Vector2) -> bool:
	if attack_mode != AttackMode.SCATTER or is_dead or not controls_enabled or has_protocol or scatter_remaining > 0.0 or direction.is_zero_approx():
		return false
	scatter_remaining = SCATTER_INTERVAL
	var start := get_shot_origin(AttackMode.SCATTER)
	for angle in [-12.0, 0.0, 12.0]:
		var pellet := Node2D.new()
		pellet.set_script(PELLET)
		pellet.direction = direction.normalized().rotated(deg_to_rad(angle))
		get_parent().get_parent().get_parent().add_child(pellet)
		pellet.global_position = start.position
		if start.blocked:
			pellet.spent = true
			if is_instance_valid(start.target):
				start.target.apply_damage(pellet.damage)
			pellet.queue_free()
	return true

func restore_player(location: Vector2, checkpoint_health: int, retained_weapons: Array) -> void:
	super.restore_player(location, checkpoint_health, retained_weapons)
	scatter_remaining = 0.0
	attack_mode = AttackMode.LASER if pulse_gun_equipped else AttackMode.UNARMED
	for pellet in get_tree().get_nodes_in_group("b_scatter_pellets"):
		pellet.spent = true
		pellet.queue_free()
