extends "res://scenes/player/player.gd"
## Keep acquisition separate from the currently raised arm.
enum AttackMode { LASER = 1, UNARMED = 2, SCATTER = 3 }
const PELLET := preload("res://tests/manual/b_combat/scatter_pellet.gd")
@export var scatter_unlocked := false
var attack_mode: int = AttackMode.UNARMED
var scatter_remaining := 0.0
var enemies_on_screen := false
var selected_mode: int = AttackMode.LASER
var holster_remaining := 0.0
var inspection_remaining := 0.0
const HOLSTER_DELAY := 2.0
const INSPECTION_DURATION := 1.2
var mouse_facing: Vector2:
	get:
		return global_position.direction_to(get_global_mouse_position())

func _ready() -> void:
	# Reuse the tested muzzle adapter without granting either ability.
	var previous := $Facing/PulseGun
	$Facing.remove_child(previous)
	previous.free()
	pulse_gun = preload("res://tests/manual/b_combat/muzzle_pulse_gun.tscn").instantiate()
	pulse_gun.name = "PulseGun"
	pulse_gun.muzzle_owner = self
	$Facing.add_child(pulse_gun)
	super._ready()

func has_visible_enemy() -> bool:
	var screen := get_viewport().get_visible_rect()
	for enemy in get_tree().get_nodes_in_group("combat_enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D or not enemy.is_visible_in_tree():
			continue
		if enemy.has_method("get_combat_state") and not enemy.get_combat_state().get("alive", false):
			continue
		if screen.has_point(enemy.get_global_transform_with_canvas().origin):
			return true
	return false

func has_arm_module(side: int) -> bool:
	return pulse_gun_equipped if side == 0 else scatter_unlocked

func learn_pulse() -> void:
	if pulse_gun_equipped:
		return
	pulse_gun_equipped = true
	selected_mode = AttackMode.LASER
	inspection_remaining = INSPECTION_DURATION

func update_combat_mode() -> void:
	enemies_on_screen = has_visible_enemy()
	if is_dead:
		attack_mode = AttackMode.UNARMED
		inspection_remaining = 0.0
		pulse_gun.cancel()
		return
	if not has_arm_module(0 if selected_mode == AttackMode.LASER else 1):
		selected_mode = AttackMode.LASER
	var available := has_arm_module(0 if selected_mode == AttackMode.LASER else 1)
	var firing: bool = pulse_gun.state != pulse_gun.State.IDLE or scatter_remaining > 0.0
	attack_mode = selected_mode if available and (enemies_on_screen or firing or holster_remaining > 0.0) else AttackMode.UNARMED
	if inspection_remaining > 0.0 and not firing:
		attack_mode = AttackMode.UNARMED

func advance_pose_time(delta: float) -> void:
	inspection_remaining = maxf(0.0, inspection_remaining-delta)
	if pulse_gun.state != pulse_gun.State.IDLE or scatter_remaining > 0.0:
		holster_remaining = HOLSTER_DELAY
	else:
		holster_remaining = maxf(0.0, holster_remaining-delta)

func _physics_process(delta: float) -> void:
	advance_pose_time(delta)
	scatter_remaining = maxf(0.0, scatter_remaining-delta)
	update_combat_mode()
	super._physics_process(delta)
	pulse_gun.visible = can_fire_pulse()

func can_fire_pulse() -> bool:
	return pulse_gun_equipped and attack_mode == AttackMode.LASER and not is_dead

func set_attack_mode(mode: int) -> bool:
	update_combat_mode()
	if is_dead or not controls_enabled or has_protocol:
		return false
	if mode != AttackMode.LASER and mode != AttackMode.SCATTER:
		return false
	if (mode == AttackMode.LASER and not pulse_gun_equipped) or (mode == AttackMode.SCATTER and not scatter_unlocked):
		return false
	if pulse_gun.state != pulse_gun.State.IDLE or scatter_remaining > 0.0:
		return false
	selected_mode = mode
	update_combat_mode()
	return true

func _unhandled_input(event: InputEvent) -> void:
	update_combat_mode()
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_1, KEY_2]:
			set_attack_mode(AttackMode.LASER if key == KEY_1 else AttackMode.SCATTER)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(shoot_action) and controls_enabled and not is_dead and not has_protocol and has_arm_module(0 if selected_mode == AttackMode.LASER else 1):
		inspection_remaining = 0.0
		holster_remaining = HOLSTER_DELAY
		attack_mode = selected_mode
	if attack_mode == AttackMode.SCATTER and event.is_action_pressed(shoot_action):
		fire_scatter(mouse_facing)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func fire_scatter(direction: Vector2) -> bool:
	if not scatter_unlocked or attack_mode != AttackMode.SCATTER or is_dead or not controls_enabled or has_protocol or scatter_remaining > 0.0 or direction.is_zero_approx():
		return false
	holster_remaining = HOLSTER_DELAY
	scatter_remaining = 0.75
	var start := get_shot_origin(AttackMode.SCATTER)
	for angle in [-12.0, 0.0, 12.0]:
		var pellet := Node2D.new()
		pellet.set_script(PELLET)
		pellet.direction = direction.normalized().rotated(deg_to_rad(angle))
		get_parent().add_child(pellet)
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
	holster_remaining = 0.0
	inspection_remaining = 0.0
	attack_mode = AttackMode.UNARMED
	for pellet in get_tree().get_nodes_in_group("b_scatter_pellets"):
		pellet.queue_free()

func get_shot_origin(mode: int) -> Dictionary:
	var visual := get_node_or_null("Facing/XiaoyiCombatVisual")
	var desired: Vector2 = visual.get_muzzle_world_position(mode) if visual != null else global_position
	var query := PhysicsRayQueryParameters2D.create(global_position, desired, 5)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.collider if hit.collider.has_method("apply_damage") and (hit.collider.collision_layer & 1) == 0 else null
		target = preload("res://scenes/weapons/laser_trace.gd").damage_receiver(target)
		return {"position": hit.position, "blocked": true, "target": target}
	var bounds: Rect2 = pulse_gun.map_bounds
	var outside := bounds.has_area() and not bounds.has_point(desired)
	return {"position": desired if not outside else global_position, "blocked": outside, "target": null}

