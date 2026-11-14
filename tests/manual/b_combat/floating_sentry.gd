extends "res://scenes/enemies/sentry/sentry.gd"
## Graybox-only floating sentry. Shared AI timing/damage remain unchanged.
@export var alternating_attacks := false
@export var screen_detection := false
var persistent_projectiles := false
var attack_mode := 0 # A fan, B sweep
var next_attack_mode := 0
var attack_center := 0.0
var shot_index := 0
var model: Node2D

func can_detect() -> bool:
	if not screen_detection:
		return super.can_detect()
	return state != State.DEAD and is_instance_valid(target) and not target.is_dead \
		and is_instance_valid(projectile_parent) and visibility_query.is_valid() \
		and visibility_query.call(self)

func is_model_on_screen() -> bool:
	if not is_instance_valid(model) or not is_visible_in_tree():
		return false
	var viewport_rect := get_viewport_rect()
	for sprite in [model.head,model.pedestal]:
		var screen_rect: Rect2 = sprite.get_global_transform_with_canvas()*sprite.get_rect()
		if sprite.is_visible_in_tree() and viewport_rect.intersects(screen_rect):
			return true
	return false

func _ready() -> void:
	super._ready()
	$Facing/Body.hide()
	$Facing/Barrel.hide()
	model = preload("res://tests/manual/b_combat/floating_sentry_visual.gd").new()
	add_child(model)
	$Health.position.y = -105.0
	# Keep the floor footprint, and let shots hit the visible column and orb too.
	var column := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(15,54)
	column.shape = shape
	column.position = Vector2(0,-30)
	add_child(column)
	var orb := CollisionShape2D.new()
	var sphere := CircleShape2D.new()
	sphere.radius = 15
	orb.shape = sphere
	orb.position = Vector2(0,-78)
	add_child(orb)

func fire_one() -> void:
	if alternating_attacks:
		_fire_alternating()
		return
	if not can_detect() or state == State.DEAD:
		super.fire_one()
		return
	if shots_left == PARAMETERS.SENTRY_BURST_COUNT:
		locked_direction = (target.global_position-model.head_origin()).normalized()
		model.aim_angle = locked_direction.angle()
		model.update_pose()
	var muzzle: Vector2 = model.muzzle_origin()
	# Prevent the raised/offset muzzle from spawning through a wall.
	var ray := PhysicsRayQueryParameters2D.create(global_position,muzzle,1)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		state = State.RECOVERY
		shots_left = 0
		remaining = PARAMETERS.SENTRY_RECOVERY
		return
	super.fire_one()
	var bullet = projectile_parent.get_child(projectile_parent.get_child_count()-1)
	_configure_projectile(bullet)
	bullet.global_position = muzzle
	bullet.get_node("Core").color = Color(1,0.78,0.32)
	bullet.get_node("Core").polygon = PackedVector2Array([Vector2(-5,-2),Vector2(2,-2),Vector2(5,0),Vector2(2,2),Vector2(-5,2)])
	model.recoil = 1.0

func update_visuals() -> void:
	super.update_visuals()
	$Facing/Warning.hide()

func restore_combat_state(snapshot: Dictionary) -> void:
	super.restore_combat_state(snapshot)
	attack_mode = 0
	next_attack_mode = 0
	shot_index = 0
	if is_instance_valid(model):
		model.recoil = 0.0
		model.aim_angle = 0.0
		model.update_pose()

func _physics_process(delta: float) -> void:
	if not alternating_attacks:
		super._physics_process(delta)
		return
	if state == State.DEAD: return
	hurt_flash = maxf(0,hurt_flash-delta)
	if not can_detect():
		state = State.IDLE
		remaining = 0
		shots_left = 0
		update_visuals()
		return
	match state:
		State.IDLE:
			attack_mode = next_attack_mode
			state = State.WARNING
			remaining = PARAMETERS.SENTRY_WARNING
		State.WARNING:
			remaining -= delta
			if remaining <= 0.000001:
				attack_center = (target.global_position-model.head_origin()).angle()
				shot_index = 0
				shots_left = 3 if attack_mode == 0 else 6
				state = State.BURST
				fire_one()
		State.BURST:
			remaining -= delta
			if remaining <= 0.000001:
				fire_one()
			elif attack_mode == 1:
				var progress := clampf((shot_index-1+(1-remaining/PARAMETERS.SENTRY_BURST_INTERVAL))/5.0,0,1)
				locked_direction = Vector2.from_angle(attack_center+deg_to_rad(lerpf(-30,30,progress)))
		State.RECOVERY:
			remaining -= delta
			if remaining <= 0: state = State.IDLE
	update_visuals()

func _configure_projectile(bullet: Node2D) -> void:
	if persistent_projectiles:
		bullet.speed = PARAMETERS.ENEMY_BULLET_SPEED*1.5
		bullet.unlimited_range = true

func _fire_alternating() -> void:
	if not can_detect() or state != State.BURST:
		return
	var spread := (-12.0+12.0*shot_index) if attack_mode == 0 else (-30.0+12.0*shot_index)
	locked_direction = Vector2.from_angle(attack_center+deg_to_rad(spread))
	model.aim_angle = locked_direction.angle()
	model.update_pose()
	var muzzle: Vector2 = model.muzzle_origin()
	var query := PhysicsRayQueryParameters2D.create(global_position,muzzle,1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		state = State.RECOVERY
		remaining = PARAMETERS.SENTRY_RECOVERY
		shots_left = 0
		return
	var bullet := BULLET.instantiate()
	_configure_projectile(bullet)
	projectile_parent.add_child(bullet)
	bullet.global_position = muzzle
	bullet.direction = locked_direction
	bullet.global_rotation = locked_direction.angle()
	model.recoil = 1.0
	shot_fired.emit()
	shot_index += 1
	shots_left -= 1
	if shots_left == 0:
		next_attack_mode = 1-attack_mode
		state = State.RECOVERY
		remaining = PARAMETERS.SENTRY_RECOVERY
	else:
		remaining = PARAMETERS.SENTRY_BURST_INTERVAL
