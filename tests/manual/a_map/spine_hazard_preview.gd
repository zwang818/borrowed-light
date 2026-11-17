extends Node2D
## Repeatable A preview of the entry devices. Geometry and positions come from the map.
signal actor_hit(device: String)

const METRICS = preload("res://scenes/levels/graybox/graybox_metrics.gd")
const ORB_SPEED := 294.0
const ORB_RADIUS := 6.0
const ORB_PERIOD := 3.7
const ORB_WARNING := 0.62
const RING_PERIOD := 4.6
const RING_WARNING := 0.86
const RING_SWEEP := 0.82
const RING_WIDTH := 10.0

class Orb:
	var position: Vector2
	var direction: Vector2
	var travel_left := 392.0

var actor: CharacterBody2D
var elapsed := 0.0
var emitters: Array[Marker2D] = []
var electrodes: Array[Marker2D] = []
var orbs: Array[Orb] = []
var ring_hit_cycle: Array[int] = []
var arena: PackedVector2Array

func configure(map: Node2D, target: CharacterBody2D) -> void:
	actor = target
	var shape: Polygon2D = map.get_node("Reservations/DefenseArena")
	for point in shape.polygon:
		arena.append(shape.to_global(point))
	for marker in map.get_node("Markers").get_children():
		match marker.get_meta("role", ""):
			"wall_emitter":
				emitters.append(marker)
			"recessed_electrode":
				electrodes.append(marker)
				ring_hit_cycle.append(-1)
	z_index = 4

func reset_motion() -> void:
	elapsed = 0.0
	orbs.clear()
	ring_hit_cycle.fill(-1)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var previous := elapsed
	elapsed += delta
	var space := get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(Vector2.ZERO, Vector2.ZERO, 1)
	for index in range(emitters.size()):
		var phase := index * 0.43
		if fposmod(elapsed + phase, ORB_PERIOD) < fposmod(previous + phase, ORB_PERIOD):
			var marker := emitters[index]
			var orb := Orb.new()
			orb.direction = Vector2.from_angle(marker.global_rotation)
			orb.position = marker.global_position + orb.direction * 34.0
			orbs.append(orb)

	var in_arena := Geometry2D.is_point_in_polygon(actor.global_position, arena)
	for index in range(orbs.size() - 1, -1, -1):
		var orb := orbs[index]
		var distance := minf(orb.travel_left, ORB_SPEED * delta)
		ray.from = orb.position
		ray.to = orb.position + orb.direction * distance
		var wall := space.intersect_ray(ray)
		var end := ray.to if wall.is_empty() else Vector2(wall.position)
		var closest := Geometry2D.get_closest_point_to_segment(actor.global_position, ray.from, end)
		if in_arena and actor.global_position.distance_to(closest) <= ORB_RADIUS + METRICS.BODY_RADIUS:
			actor_hit.emit("激光球")
			orbs.remove_at(index)
		elif not wall.is_empty() or orb.travel_left <= distance:
			orbs.remove_at(index)
		else:
			orb.position = end
			orb.travel_left -= distance

	if in_arena:
		for index in range(electrodes.size()):
			var cycle_time := elapsed + index * 0.51
			var cycle := floori(cycle_time / RING_PERIOD)
			var age := fposmod(cycle_time, RING_PERIOD)
			if age < RING_WARNING or age >= RING_WARNING + RING_SWEEP or ring_hit_cycle[index] == cycle:
				continue
			var marker := electrodes[index]
			var radius := _wave_radius(marker, age)
			if absf(marker.global_position.distance_to(actor.global_position) - radius) <= METRICS.BODY_RADIUS + RING_WIDTH * 0.5:
				ray.from = marker.global_position
				ray.to = actor.global_position
				if space.intersect_ray(ray).is_empty():
					ring_hit_cycle[index] = cycle
					actor_hit.emit("扩散电圈")
	queue_redraw()

func _wave_radius(marker: Marker2D, age: float) -> float:
	return lerpf(10.0, float(marker.get_meta("pulse_radius")), (age - RING_WARNING) / RING_SWEEP)

func _draw() -> void:
	for index in range(emitters.size()):
		var age := fposmod(elapsed + index * 0.43, ORB_PERIOD)
		if age >= ORB_PERIOD - ORB_WARNING:
			var marker := emitters[index]
			var axis := Vector2.from_angle(marker.global_rotation)
			var muzzle := marker.global_position + axis * 34.0
			draw_circle(muzzle, 8.0, Color("f9ab73"))
			draw_dashed_line(muzzle + axis * 8.0, muzzle + axis * 86.0, Color("ffb983"), 2.0, 8.0)
	for index in range(electrodes.size()):
		var marker := electrodes[index]
		var age := fposmod(elapsed + index * 0.51, RING_PERIOD)
		if age < RING_WARNING:
			_draw_ring(marker.global_position, float(marker.get_meta("pulse_radius")), true)
		elif age < RING_WARNING + RING_SWEEP:
			_draw_ring(marker.global_position, _wave_radius(marker, age), false)
	for orb in orbs:
		draw_line(orb.position - orb.direction * 22.0, orb.position, Color("f57d53"), 4.0)
		draw_circle(orb.position, ORB_RADIUS + 3.0, Color(1.0, 0.41, 0.26, 0.45))
		draw_circle(orb.position, ORB_RADIUS, Color("ffd995"))
		draw_circle(orb.position + orb.direction * 2.0, 2.6, Color("fff6dc"))

func _draw_ring(center: Vector2, radius: float, warning: bool) -> void:
	const STEPS := 64
	var a := center + Vector2.RIGHT * radius
	for step in range(STEPS):
		var b := center + Vector2.from_angle(TAU * float(step + 1) / STEPS) * radius
		if Geometry2D.is_point_in_polygon(a, arena) and Geometry2D.is_point_in_polygon(b, arena):
			if not warning:
				draw_line(a, b, Color(0.40, 0.68, 1.0, 0.32), RING_WIDTH)
				draw_line(a, b, Color("cceaff"), 2.5)
			elif step % 2 == 0:
				draw_line(a, b, Color("c6ac84"), 1.5)
		a = b
