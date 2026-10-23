extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died(entity_id: StringName)
const PARAMETERS := preload("res://scenes/weapons/combat_parameters.gd")
enum State { PATROL, CHASE, WARNING, ATTACK, RECOVERY, DEAD }
@export var entity_id: StringName = &"cleaner_test_01"
@export var max_health: int = PARAMETERS.CLEANER_HEALTH
@export var patrol_offsets := PackedVector2Array([Vector2.ZERO, Vector2(96, 0)])
var health: int
var state: State = State.PATROL
var remaining: float = 0.0
var hurt_flash: float = 0.0
var attack_hit: bool = false
var locked_direction := Vector2.RIGHT
var target: Node2D
var visibility_query: Callable
var protocol_query: Callable
var home := Vector2.ZERO
var patrol_index: int = 0
var reported_missing_configuration: bool = false
var attack_shape := RectangleShape2D.new()

func _ready() -> void:
	add_to_group("combat_enemies")
	health = max_health
	home = global_position
	attack_shape.size = Vector2(44, 44)
	update_visuals()

func configure(player: Node2D, visible_query: Callable, in_protocol: Callable) -> void:
	target = player
	visibility_query = visible_query
	protocol_query = in_protocol

func can_detect() -> bool:
	if not visibility_query.is_valid() or not protocol_query.is_valid() or not is_instance_valid(target):
		if not reported_missing_configuration:
			push_error("Cleaner requires player, visibility and protocol queries.")
			reported_missing_configuration = true
		return false
	if target.is_dead or protocol_query.call():
		return false
	if not visibility_query.call(self) or global_position.distance_to(target.global_position) > PARAMETERS.CLEANER_DETECTION_RANGE:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	hurt_flash = maxf(0, hurt_flash - delta)
	var detected := can_detect()
	# Cancellation is evaluated before movement or damage in this update.
	if not detected and state in [State.CHASE, State.WARNING, State.ATTACK]:
		begin_recovery()
		update_visuals()
		return
	match state:
		State.PATROL:
			if detected:
				state = State.CHASE
				velocity = Vector2.ZERO
			else:
				patrol()
		State.CHASE:
			var offset := target.global_position - global_position
			if offset.length() <= PARAMETERS.CLEANER_ATTACK_DISTANCE:
				velocity = Vector2.ZERO
				locked_direction = offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
				$Facing.global_rotation = locked_direction.angle()
				state = State.WARNING
				remaining = PARAMETERS.CLEANER_WARNING
			else:
				move_toward_point(target.global_position, PARAMETERS.CLEANER_CHASE_SPEED)
		State.WARNING:
			remaining -= delta
			if remaining <= 0.000001:
				state = State.ATTACK
				remaining = PARAMETERS.CLEANER_ACTIVE
				attack_hit = false
				try_melee_hit()
		State.ATTACK:
			remaining -= delta
			if remaining <= 0.000001:
				begin_recovery()
			else:
				try_melee_hit()
		State.RECOVERY:
			remaining -= delta
			if remaining <= 0.000001:
				state = State.PATROL
	update_visuals()

func patrol() -> void:
	if patrol_offsets.is_empty():
		velocity = Vector2.ZERO
		return
	var point := home + patrol_offsets[patrol_index]
	if global_position.distance_to(point) < 6.0:
		patrol_index = (patrol_index + 1) % patrol_offsets.size()
		point = home + patrol_offsets[patrol_index]
	move_toward_point(point, PARAMETERS.CLEANER_PATROL_SPEED)

func move_toward_point(point: Vector2, speed: float) -> void:
	var desired := (point - global_position).normalized()
	velocity = Vector2.ZERO
	# Small local steering for corners; no tracking through a wall or stale target.
	for degrees in [0, 30, -30, 60, -60, 90, -90]:
		var direction := desired.rotated(deg_to_rad(degrees))
		if not test_move(global_transform, direction * 24.0):
			velocity = direction * speed
			$Facing.global_rotation = direction.angle()
			break
	move_and_slide()

func try_melee_hit() -> void:
	if state != State.ATTACK or attack_hit or not can_detect():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(locked_direction.angle(), global_position + locked_direction * 34.0)
	query.collision_mask = 2
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		if hit.collider == target:
			attack_hit = true
			target.apply_damage(PARAMETERS.CLEANER_DAMAGE)
			break

func begin_recovery() -> void:
	state = State.RECOVERY
	remaining = PARAMETERS.CLEANER_RECOVERY
	velocity = Vector2.ZERO
	attack_hit = false

func apply_damage(amount: int) -> void:
	if state == State.DEAD or amount <= 0:
		return
	health = maxi(0, health - amount)
	hurt_flash = 0.12
	health_changed.emit(health, max_health)
	if health == 0:
		state = State.DEAD
		remaining = 0.0
		velocity = Vector2.ZERO
		attack_hit = false
		set_deferred("collision_layer", 0)
		died.emit(entity_id)
	update_visuals()

func get_combat_state() -> Dictionary:
	return {"entity_id": entity_id, "health": health, "alive": state != State.DEAD, "position": global_position, "patrol_index": patrol_index}

func restore_combat_state(snapshot: Dictionary) -> void:
	assert(snapshot.entity_id == entity_id, "Cannot restore a different cleaner.")
	health = clampi(int(snapshot.health), 0, max_health)
	global_position = snapshot.get("position", home)
	patrol_index = clampi(int(snapshot.get("patrol_index", 0)), 0, maxi(0, patrol_offsets.size() - 1))
	state = State.PATROL if health > 0 else State.DEAD
	remaining = 0.0
	velocity = Vector2.ZERO
	hurt_flash = 0.0
	attack_hit = false
	collision_layer = 4 if health > 0 else 0
	health_changed.emit(health, max_health)
	update_visuals()

func update_visuals() -> void:
	$Facing/AttackZone.visible = state in [State.WARNING, State.ATTACK]
	$Facing/AttackZone.color = Color(1, 0.25, 0.1, 0.65) if state == State.ATTACK else Color(1, 0.85, 0.2, 0.35)
	$Facing.modulate = Color(0.3, 0.3, 0.3) if state == State.DEAD else (Color(2, 2, 2) if hurt_flash > 0.0 else Color.WHITE)
	$Health.max_value = max_health
	$Health.value = health
