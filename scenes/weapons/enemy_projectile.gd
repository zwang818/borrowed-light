extends Node2D

const PARAMETERS := preload("res://scenes/weapons/combat_parameters.gd")
var direction := Vector2.RIGHT
var travelled: float = 0.0
var spent: bool = false

func _physics_process(delta: float) -> void:
	if spent:
		return
	var step := minf(PARAMETERS.ENEMY_BULLET_SPEED * delta, PARAMETERS.ENEMY_BULLET_RANGE - travelled)
	var end := global_position + direction * step
	# Sweep against world and player only: no enemy friendly fire.
	var query := PhysicsRayQueryParameters2D.create(global_position, end, 3)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		spent = true
		if hit.collider.has_method("apply_damage"):
			hit.collider.apply_damage(PARAMETERS.ENEMY_BULLET_DAMAGE)
		queue_free()
		return
	global_position = end
	travelled += step
	if travelled >= PARAMETERS.ENEMY_BULLET_RANGE:
		spent = true
		queue_free()
