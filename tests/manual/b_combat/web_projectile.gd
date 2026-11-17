extends Node2D
## Swept, non-damaging silk projectile; world geometry blocks it.
var direction := Vector2.RIGHT
var speed := 220.0
var lifetime := 1.5
var persistent_flight := false
var spent := false
var source: Node2D
func _ready() -> void:
	add_to_group("b_cleaner_webs")
	z_index = 4
func _physics_process(delta: float) -> void:
	if spent:
		return
	if not persistent_flight and (not is_instance_valid(source) or source.state == source.State.DEAD):
		queue_free()
		return
	var travel := speed*(delta if persistent_flight else minf(delta,lifetime))
	var end := global_position+direction*travel
	var query := PhysicsRayQueryParameters2D.create(global_position,end,3)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		spent = true
		if hit.collider.has_method("apply_web_slow"):
			hit.collider.apply_web_slow(2.0,0.6)
		queue_free()
		return
	global_position = end
	lifetime -= delta
	if not persistent_flight and lifetime <= 0.0:
		queue_free()
	queue_redraw()
func _draw() -> void:
	var tail := -direction*15.0
	var side := direction.orthogonal()*3.0
	draw_line(tail,Vector2.ZERO,Color(0.82,0.96,0.91,0.9),2.0,true)
	draw_polyline(PackedVector2Array([tail+side,-direction*7.0-side,side,Vector2.ZERO]),Color(0.95,1,0.96),1.0,true)
	draw_circle(Vector2.ZERO,3.0,Color(0.86,0.98,0.92,0.85))
