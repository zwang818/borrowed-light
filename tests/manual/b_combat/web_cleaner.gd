extends "res://scenes/enemies/cleaner/cleaner.gd"
## Shared ranged behavior for the graybox and abdomen; base melee timings remain unchanged.
const WEB = preload("res://tests/manual/b_combat/web_projectile.gd")
const WEB_MIN_DISTANCE := 110.0
const WEB_WARNING := 0.55
const WEB_RELEASE := 0.25
const WEB_COOLDOWN := 3.0
var web_phase := 0 # 0 chase/melee, 1 telegraph, 2 release/recover
var web_remaining := 0.0
var web_cooldown := 0.8
var web_direction := Vector2.RIGHT

func _ready() -> void:
	add_to_group("cleaners")
	super._ready()

func combat_visual() -> Node2D:
	var visual := get_node_or_null("CleanerVisual")
	return visual if visual != null else get_node_or_null("CleanerModel")

func is_on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	var screen := get_viewport_rect()
	var visual := combat_visual()
	if visual == null or visual.pieces.is_empty():
		return screen.has_point(get_global_transform_with_canvas().origin)
	var pose: Dictionary = visual.sprite_pose()
	var bounds := Rect2(pose.origin,pose.size)
	if visual.face_left:
		bounds.position.x = -bounds.end.x
	return screen.intersects(visual.get_global_transform_with_canvas()*bounds)

func can_detect() -> bool:
	if state == State.DEAD or not is_instance_valid(target):
		return false
	if not visibility_query.is_valid() or not protocol_query.is_valid():
		return false
	if target.is_dead or protocol_query.call():
		return false
	# Graybox screen-awareness replaces both the old radius and sight ray.
	# Movement collision and projectile wall checks remain independent.
	return visibility_query.call(self)

func _physics_process(delta: float) -> void:
	web_cooldown = maxf(0.0,web_cooldown-delta)
	if web_phase != 0:
		velocity = Vector2.ZERO
		if state == State.DEAD or not can_detect():
			web_phase = 0
			if state != State.DEAD:
				begin_recovery()
			return
		if global_position.distance_to(target.global_position) <= PARAMETERS.CLEANER_ATTACK_DISTANCE:
			web_phase = 0
			state = State.CHASE
			super._physics_process(delta)
			return
		hurt_flash = maxf(0.0,hurt_flash-delta)
		web_remaining -= delta
		if web_remaining <= 0.0:
			if web_phase == 1:
				fire_web()
				web_phase = 2
				web_remaining = WEB_RELEASE
			else:
				web_phase = 0
				state = State.CHASE
		update_visuals()
		return
	if state == State.CHASE and web_cooldown <= 0.0 and can_detect() and global_position.distance_to(target.global_position) > WEB_MIN_DISTANCE:
		velocity = Vector2.ZERO
		web_phase = 1
		web_remaining = WEB_WARNING
		web_cooldown = WEB_COOLDOWN
		$Facing.rotation = global_position.direction_to(target.global_position).angle()
		var visual := combat_visual()
		visual.face_left = target.global_position.x < global_position.x
		visual.walked_this_tick = false
		web_direction = eye_origin().direction_to(target.global_position)
		return
	super._physics_process(delta)

func eye_origin() -> Vector2:
	var visual := combat_visual()
	return visual.eye_world_position() if visual != null else global_position

func fire_web() -> void:
	var origin := eye_origin()
	# The red eye can extend beyond body collision; never emit through a wall.
	var ray := PhysicsRayQueryParameters2D.create(global_position,origin,1)
	ray.hit_from_inside = true
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return
	var web := Node2D.new()
	web.set_script(WEB)
	web.source = self
	web.direction = web_direction
	get_parent().add_child(web)
	web.global_position = origin

func restore_combat_state(snapshot: Dictionary) -> void:
	web_phase = 0
	web_remaining = 0.0
	web_cooldown = 0.8
	for web in get_tree().get_nodes_in_group("b_cleaner_webs"):
		if web.source == self:
			web.queue_free()
	super.restore_combat_state(snapshot)

func try_melee_hit() -> void:
	if state != State.ATTACK or attack_hit or not can_detect():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(locked_direction.angle(),global_position+locked_direction*34.0)
	query.collision_mask = 2
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var receiver: Object = hit.collider
		if receiver.has_method("get_damage_receiver"):
			receiver = receiver.get_damage_receiver()
		if receiver == target:
			attack_hit = true
			target.apply_damage(PARAMETERS.CLEANER_DAMAGE)
			break
