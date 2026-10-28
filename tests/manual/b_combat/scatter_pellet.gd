extends Node2D

var direction := Vector2.RIGHT
var remaining_range: float = 128.0
var speed: float = 448.0
var damage: int = 1 # Graybox test value, not final balance.
var spent: bool = false

func _ready() -> void:
	add_to_group("b_scatter_pellets")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if spent:
		return
	var distance := minf(speed * delta, remaining_range)
	var end := global_position + direction * distance
	var query := PhysicsRayQueryParameters2D.create(global_position, end, 5)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spent = true
		global_position = hit.position
		if hit.collider.has_method("apply_damage"):
			hit.collider.apply_damage(damage)
		queue_free()
		return
	global_position = end
	remaining_range -= distance
	if remaining_range <= 0.0:
		spent = true
		queue_free()

func _draw() -> void:
	draw_line(-direction * 5.0, Vector2.ZERO, Color(1.0, 0.7, 0.25), 3.0)
