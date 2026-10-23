extends StaticBody2D

signal health_changed(current: int, maximum: int)
signal died(entity_id: StringName)
signal shot_fired

const PARAMETERS := preload("res://scenes/weapons/combat_parameters.gd")
const BULLET := preload("res://scenes/weapons/enemy_projectile.tscn")
enum State { IDLE, WARNING, BURST, RECOVERY, DEAD }

@export var entity_id: StringName = &"sentry_test_01"
@export var max_health: int = PARAMETERS.SENTRY_HEALTH
var health: int
var state: State = State.IDLE
var remaining: float = 0.0
var shots_left: int = 0
var locked_direction := Vector2.RIGHT
var target: Node2D
var visibility_query: Callable
var projectile_parent: Node
var hurt_flash: float = 0.0
var reported_missing_configuration: bool = false

func _ready() -> void:
	add_to_group("combat_enemies")
	health = max_health
	update_visuals()

func configure(player: Node2D, visible_query: Callable, bullets: Node) -> void:
	target = player
	visibility_query = visible_query
	projectile_parent = bullets

func can_detect() -> bool:
	if not is_instance_valid(target) or target.is_dead:
		return false
	if not visibility_query.is_valid() or not is_instance_valid(projectile_parent):
		if not reported_missing_configuration:
			push_error("Sentry requires visibility query and projectile parent from runtime.")
			reported_missing_configuration = true
		return false
	if global_position.distance_to(target.global_position) > PARAMETERS.SENTRY_DETECTION_RANGE:
		return false
	if not visibility_query.call(self):
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	hurt_flash = maxf(0.0, hurt_flash - delta)
	if not can_detect():
		state = State.IDLE
		remaining = 0.0
		shots_left = 0
		update_visuals()
		return
	match state:
		State.IDLE:
			state = State.WARNING
			remaining = PARAMETERS.SENTRY_WARNING
		State.WARNING:
			$Facing.global_rotation = (target.global_position - global_position).angle()
			remaining -= delta
			if remaining <= 0.000001:
				locked_direction = (target.global_position - global_position).normalized()
				state = State.BURST
				shots_left = PARAMETERS.SENTRY_BURST_COUNT
				fire_one()
		State.BURST:
			remaining -= delta
			if remaining <= 0.000001:
				fire_one()
		State.RECOVERY:
			remaining -= delta
			if remaining <= 0.000001:
				state = State.IDLE
	update_visuals()

func fire_one() -> void:
	# Recheck immediately before spawning; old bullets continue if visibility is lost.
	if not can_detect() or state == State.DEAD:
		state = State.IDLE
		shots_left = 0
		return
	var bullet := BULLET.instantiate()
	projectile_parent.add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = locked_direction
	bullet.global_rotation = locked_direction.angle()
	shots_left -= 1
	shot_fired.emit()
	if shots_left == 0:
		state = State.RECOVERY
		remaining = PARAMETERS.SENTRY_RECOVERY
	else:
		remaining = PARAMETERS.SENTRY_BURST_INTERVAL

func apply_damage(amount: int) -> void:
	if state == State.DEAD or amount <= 0:
		return
	health = maxi(0, health - amount)
	hurt_flash = 0.12
	health_changed.emit(health, max_health)
	if health == 0:
		state = State.DEAD
		shots_left = 0
		remaining = 0.0
		set_deferred("collision_layer", 0)
		died.emit(entity_id)
	update_visuals()

func get_combat_state() -> Dictionary:
	return {"entity_id": entity_id, "health": health, "alive": state != State.DEAD}

func restore_combat_state(snapshot: Dictionary) -> void:
	assert(snapshot.entity_id == entity_id, "Cannot restore a different entity.")
	health = clampi(int(snapshot.health), 0, max_health)
	state = State.IDLE if health > 0 else State.DEAD
	remaining = 0.0
	shots_left = 0
	hurt_flash = 0.0
	collision_layer = 4 if health > 0 else 0
	health_changed.emit(health, max_health)
	update_visuals()

func update_visuals() -> void:
	$Facing.modulate = Color.WHITE
	if state == State.DEAD:
		$Facing.modulate = Color(0.3, 0.3, 0.3)
	elif hurt_flash > 0:
		$Facing.modulate = Color(2, 2, 2)
	$Facing/Warning.visible = state == State.WARNING
	$Health.value = health
	$Health.max_value = max_health
