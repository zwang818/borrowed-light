extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died(entity_id: StringName)
signal melee_warning_changed(active: bool)
const PARAMETERS := preload("res://scenes/weapons/combat_parameters.gd")
const PATHFINDER := preload("res://scenes/enemies/cleaner/cleaner_pathfinder.gd")
const ATTACK_APPROACH_DISTANCE := PARAMETERS.CLEANER_ATTACK_DISTANCE - 10.0
const ROUTE_REPLAN_DISTANCE := 28.0
const ROUTE_RETRY_SECONDS := 0.3
enum State { PATROL, CHASE, WARNING, ATTACK, RECOVERY, DEAD }
@export var entity_id: StringName = &"cleaner_test_01"
@export var max_health: int = PARAMETERS.CLEANER_HEALTH
@export var patrol_offsets := PackedVector2Array([Vector2.ZERO, Vector2(96, 0)])
var health: int
var state: State = State.PATROL:
	set(value):
		var was_warning := state == State.WARNING
		state = value
		var is_warning := state == State.WARNING
		if was_warning != is_warning:
			melee_warning_changed.emit(is_warning)
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
var _path := PackedVector2Array()
var _path_target := Vector2.INF
var _path_stop_distance := -1.0
var _path_retry := 0.0

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
	return has_clear_line(global_position, target.global_position)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_path_retry = maxf(0.0, _path_retry - delta)
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
			_chase_target()
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

func _chase_target() -> void:
	var offset := target.global_position - global_position
	if offset.length() <= PARAMETERS.CLEANER_ATTACK_DISTANCE and has_clear_line(global_position, target.global_position):
		_clear_path()
		velocity = Vector2.ZERO
		locked_direction = offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
		$Facing.global_rotation = locked_direction.angle()
		state = State.WARNING
		remaining = PARAMETERS.CLEANER_WARNING
	else:
		move_toward_point(target.global_position, PARAMETERS.CLEANER_CHASE_SPEED, ATTACK_APPROACH_DISTANCE)

func patrol() -> void:
	if patrol_offsets.is_empty():
		velocity = Vector2.ZERO
		return
	var point := home + patrol_offsets[patrol_index]
	if global_position.distance_to(point) < 6.0:
		patrol_index = (patrol_index + 1) % patrol_offsets.size()
		point = home + patrol_offsets[patrol_index]
	move_toward_point(point, PARAMETERS.CLEANER_PATROL_SPEED)

func move_toward_point(point: Vector2, speed: float, stop_distance := 0.0) -> void:
	var same_purpose := is_equal_approx(stop_distance, _path_stop_distance)
	# Keep the chosen side while the target makes small movements around a corner.
	if same_purpose and _path_target.distance_squared_to(point) < ROUTE_REPLAN_DISTANCE * ROUTE_REPLAN_DISTANCE and _follow_path(speed):
		return
	var approach := point.move_toward(global_position, stop_distance)
	if PATHFINDER.can_travel(self, global_position, approach) and (stop_distance == 0.0 or has_clear_line(approach, point)):
		_clear_path()
		_step_toward(approach, speed)
		return
	if _path_retry <= 0.0 or not same_purpose:
		_path = PATHFINDER.find_route(self, point, stop_distance)
		_path_target = point
		_path_stop_distance = stop_distance
		_path_retry = ROUTE_RETRY_SECONDS
	if _follow_path(speed):
		return
	velocity = Vector2.ZERO

func _follow_path(speed: float) -> bool:
	while not _path.is_empty() and global_position.distance_squared_to(_path[0]) < 1.0:
		_path.remove_at(0)
	if _path.is_empty():
		return false
	if not PATHFINDER.can_travel(self, global_position, _path[0]):
		_path.clear()
		return false
	_step_toward(_path[0], speed)
	return true

func _step_toward(point: Vector2, speed: float) -> void:
	var offset := point - global_position
	if offset.is_zero_approx():
		velocity = Vector2.ZERO
		return
	velocity = offset.normalized() * minf(speed, offset.length() / get_physics_process_delta_time())
	$Facing.global_rotation = offset.angle()
	move_and_slide()

func _clear_path() -> void:
	_path.clear()
	_path_target = Vector2.INF
	_path_stop_distance = -1.0
	_path_retry = 0.0

func has_clear_line(from: Vector2, to: Vector2) -> bool:
	return PATHFINDER.has_clear_line(self, from, to)

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
	_clear_path()
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
	_clear_path()
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
