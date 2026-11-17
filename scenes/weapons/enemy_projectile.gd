extends Node2D

const PARAMETERS := preload("res://scenes/weapons/combat_parameters.gd")
var direction := Vector2.RIGHT
var travelled: float = 0.0
var spent: bool = false
var speed: float = PARAMETERS.ENEMY_BULLET_SPEED
var unlimited_range := false
@onready var sweep: ShapeCast2D = $Sweep

func _physics_process(delta: float) -> void:
	if spent:
		return
	var step := speed * delta
	if not unlimited_range:
		step = minf(step, PARAMETERS.ENEMY_BULLET_RANGE - travelled)
	var end := global_position + direction * step
	# Sweep the visible 8x6 core, rather than a zero-width ray. Check the
	# starting overlap too, so a muzzle already touching a wall cannot skip it.
	sweep.target_position = Vector2.ZERO
	sweep.force_shapecast_update()
	if not sweep.is_colliding():
		sweep.target_position = sweep.to_local(end)
		sweep.force_shapecast_update()
	if sweep.is_colliding():
		global_position = global_position.lerp(end,sweep.get_closest_collision_safe_fraction())
		spent = true
		var collider := sweep.get_collider(0)
		if is_instance_valid(collider) and collider.has_method("apply_damage"):
			collider.apply_damage(PARAMETERS.ENEMY_BULLET_DAMAGE)
		queue_free()
		return
	global_position = end
	travelled += step
	if not unlimited_range and travelled >= PARAMETERS.ENEMY_BULLET_RANGE:
		spent = true
		queue_free()
