extends Node2D
## Graybox scatter: visible streaks and damage share the same swept trajectories.
const COUNT := 12
const SPEED := 448.0
const RANGE := 128.0
var player: Node2D
var age := 0.0
var points: Array[Vector2] = []
var directions: Array[Vector2] = []
var distances: Array[float] = []
var spent: Array[bool] = []
var impacts: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("b_scatter_flashes")
	z_index = 4
	for i in range(COUNT):
		points.append(Vector2.ZERO)
		directions.append(Vector2.RIGHT.rotated(deg_to_rad(lerpf(-14,14,float(i)/(COUNT-1)))))
		distances.append(0.0)
		spent.append(false)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.is_dead or not player.controls_enabled:
		queue_free()
		return
	var old_age := age
	age += delta
	for i in range(COUNT):
		if spent[i]: continue
		var launch := (i % 6)*0.009
		var step := maxf(0.0,age-maxf(old_age,launch))
		if step <= 0: continue
		var distance := minf(SPEED*step,RANGE-distances[i])
		var next := points[i]+directions[i]*distance
		var ray := PhysicsRayQueryParameters2D.create(to_global(points[i]),to_global(next),5)
		ray.collide_with_areas = true
		ray.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			points[i] = to_local(hit.position)
			spent[i] = true
			impacts.append({"point":points[i],"born":age,"normal":Vector2(hit.normal).rotated(-global_rotation)})
			if hit.collider.has_method("apply_damage"): hit.collider.apply_damage(1)
		else:
			points[i] = next
			distances[i] += distance
			spent[i] = distances[i] >= RANGE
	if age > 0.55: queue_free()
	queue_redraw()

func _draw() -> void:
	# Short asymmetric muzzle petals; dark smoke outlives the white-hot core.
	if age < 0.24:
		var smoke := age/0.24
		for i in range(3):
			draw_circle(Vector2(6+smoke*13,i*3-3),2+smoke*4,Color(0.36,0.33,0.30,(1-smoke)*0.22))
	if age < 0.09:
		var fade := 1.0-age/0.09
		var length := 12.0+sin(age/0.09*PI)*9
		var flame := PackedVector2Array([Vector2(-2,-3),Vector2(6,-5),Vector2(length*0.65,-2),Vector2(length,0),Vector2(length*0.7,2),Vector2(5,5),Vector2(-2,3)])
		draw_colored_polygon(flame,Color(1,0.47,0.12,fade))
		draw_line(Vector2(-1,0),Vector2(length*0.65,0),Color(1,0.91,0.64,fade),3)
	for i in range(COUNT):
		if spent[i] or distances[i] <= 0: continue
		var fade := clampf((RANGE-distances[i])/25.0,0,1)
		var tip := points[i]
		var tail := tip-directions[i]*minf(distances[i],9.0+(i%3)*2)
		draw_line(tail,tip,Color(1,0.47,0.13,fade*0.35),3)
		draw_line(tail,tip,Color(1,0.78,0.40,fade),1)
		draw_circle(tip,0.8,Color(1,0.96,0.75,fade))
	for impact in impacts:
		var elapsed: float = age-impact.born
		if elapsed > 0.16: continue
		var fade := 1.0-elapsed/0.16
		var center: Vector2 = impact.point
		for i in range(5):
			var direction := Vector2(impact.normal).rotated(lerpf(-1.3,1.3,i/4.0))
			draw_line(center+direction*elapsed*25,center+direction*(2+elapsed*55),Color(1,0.65,0.26,fade),1)
		draw_circle(center,2*fade,Color(1,0.93,0.68,fade))
