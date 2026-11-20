extends "res://scenes/weapons/pulse_gun.gd"
## Room-local muzzle and contact presentation, with the shared pulse timing.
const TRACE_MASK := 1 | 4
var muzzle_owner: Node2D
var use_muzzle := true
var trace_debug := false
var first_contact: Dictionary = {}
var feed_contact: Dictionary = {}
var report_key := ""
var overlay: Node2D
var impact_fx: Node2D

func _ready() -> void:
	# The player may rotate its Facing after advance_time() (aim assist).
	# Leave the two rendered lines and contact spark at their traced world points.
	for line in [beam, beam_core]:
		line.top_level = true
		line.transform = Transform2D.IDENTITY
	impact_fx = Node2D.new()
	impact_fx.top_level = true
	add_child(impact_fx)
	impact_fx.global_transform = Transform2D.IDENTITY
	impact_fx.draw.connect(_draw_impact)
	overlay = Node2D.new()
	overlay.z_index = 9
	overlay.top_level = true
	add_child(overlay)
	overlay.global_transform = Transform2D.IDENTITY
	overlay.draw.connect(_draw_debug)

func advance_time(delta: float, origin: Vector2, current_direction := Vector2.ZERO) -> void:
	feed_contact.clear()
	if state == State.IDLE:
		return
	var start := origin
	if use_muzzle and is_instance_valid(muzzle_owner):
		var model := muzzle_owner.get_node_or_null("Facing/XiaoyiCombatVisual")
		if model != null:
			var desired: Vector2 = model.get_muzzle_world_position(1)
			feed_contact = trace_contact(get_world_2d().direct_space_state, origin, desired)
			start = feed_contact.get("position", desired)
	charge_glow.position = to_local(start)
	super.advance_time(delta, start, current_direction)

static func trace_contact(space: PhysicsDirectSpaceState2D, start: Vector2, end: Vector2) -> Dictionary:
	if start.is_equal_approx(end):
		return {}
	var ray := PhysicsRayQueryParameters2D.create(start, end, TRACE_MASK)
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	return space.intersect_ray(ray)

func update_beam(origin: Vector2) -> void:
	if state != State.FIRING:
		return
	var elapsed := maxf(0.0, BEAM_DURATION - remaining)
	var length := LASER_TRACE.distance_to_boundary(origin, locked_direction, map_bounds)
	var end := origin + locked_direction * length * clampf(elapsed / maxf(beam_extension_duration, 0.001), 0.0, 1.0)
	first_contact = feed_contact if not feed_contact.is_empty() else trace_contact(get_world_2d().direct_space_state, origin, end)
	end = first_contact.get("position", end)
	var start := muzzle_owner.global_position if not feed_contact.is_empty() and is_instance_valid(muzzle_owner) else origin
	beam_points = PackedVector2Array([start, end])
	beam.points = PackedVector2Array([beam.to_local(start), beam.to_local(end)])
	beam_core.points = PackedVector2Array([beam_core.to_local(start), beam_core.to_local(end)])
	beam.visible = true
	beam_core.visible = true
	var did_damage := false
	if not first_contact.is_empty():
		if contact_remaining < 0.0:
			contact_remaining = CONTACT_DURATION
		var collider: CollisionObject2D = first_contact.collider
		if (collider.collision_layer & 1) == 0:
			var receiver := LASER_TRACE.damage_receiver(collider)
			if is_instance_valid(receiver) and receiver.has_method("apply_damage") and not damaged_targets.has(receiver.get_instance_id()):
				damaged_targets[receiver.get_instance_id()] = true
				if receiver.has_method("take_pulse_hit"):
					receiver.take_pulse_hit(beam_damage, muzzle_owner)
				else:
					receiver.apply_damage(beam_damage)
				did_damage = true
		var key := str(collider.get_path())
		if trace_debug and (key != report_key or did_damage):
			print("[Boss pulse] first=%s world=%s drawn=%s damage=%s" % [key, end, beam.to_global(beam.points[-1]), did_damage])
		report_key = key
	else:
		report_key = ""
	impact_fx.queue_redraw()
	overlay.queue_redraw()

func cancel() -> void:
	super.cancel()
	first_contact.clear()
	report_key = ""
	if is_instance_valid(impact_fx):
		impact_fx.queue_redraw()
	if is_instance_valid(overlay):
		overlay.queue_redraw()

func _draw_impact() -> void:
	if state != State.FIRING or first_contact.is_empty():
		return
	var tip := impact_fx.to_local(first_contact.position)
	var fade := clampf(contact_remaining / CONTACT_DURATION, 0.0, 1.0)
	impact_fx.draw_circle(tip, 2.0 + fade * 2.0, Color(0.78, 0.98, 1.0, fade))
	for i in range(4):
		var d := Vector2.from_angle(PI * (i + 0.5) / 2.0)
		impact_fx.draw_line(tip + d * 2.0, tip + d * (8.0 - fade * 4.0), Color(0.45, 0.92, 1.0, fade), 1.0)

func _draw_debug() -> void:
	if not trace_debug or state != State.FIRING or beam_points.size() < 2:
		return
	var start := overlay.to_local(beam_points[0])
	var end := overlay.to_local(beam_points[-1])
	overlay.draw_circle(start, 3, Color.CHARTREUSE)
	overlay.draw_circle(end, 5, Color.YELLOW if not first_contact.is_empty() else Color.AQUAMARINE, false, 1.5)
	overlay.draw_dashed_line(start, end, Color(0.75, 1.0, 0.55, 0.7), 1.0, 5.0)
