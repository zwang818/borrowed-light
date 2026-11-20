extends CharacterBody2D

signal defeated
signal slammed(at: Vector2)
signal throw_landed(direction: Vector2)

class ArmorHitbox extends Area2D:
	func get_damage_receiver() -> Node:
		return get_parent()

const ART := "res://assets/sprites/enemies/parallel_cleaner/"
const POSE := {
	"assembly": [0, 0, 0, 1, 2], "neutral": [2, 2, 2, 2], "walk": [2, 3, 2, 3],
	"web_shot": [5, 5, 6, 4], "reel": [4, 6, 6, 5],
	"web_recover": [6, 4, 4],
	"grab_warn": [2, 7, 7, 7],
	"miss": [8, 11, 11, 11, 2],
}
const ROUTER := preload("res://scenes/enemies/cleaner/cleaner_pathfinder.gd")
const SWEEP_ART := preload("res://scenes/enemies/parallel_cleaner/sweep_visual.gd")
const GROUND_FX := preload("res://scenes/enemies/parallel_cleaner/ground_fx.gd")
const GRAB_VISUAL := preload("res://scenes/enemies/parallel_cleaner/grab_visual.gd")
const GROUND_ART := ART + "ground_actions/"
const CLEARANCE := preload("res://scenes/enemies/parallel_cleaner/clearance.gd")
const WORLD := 1
const ARMOR_LAYER := 4
const CHASSIS_LAYER := 1 << 8 # Reserved for the abdomen Boss encounter.
const PLAYER_FEET_LAYER := 1 << 9 # Layer 2 also carries the existing tall damage proxy.
const CHASSIS_HALF := Vector2(36, 18)
const MAX_HP := 20
const RAGE_HP := 10
const RAGE_ATTACK_PACE := 1.25
const RAGE_FLASH_TIME := 0.45
const WEB_RANGE := 400.0
const WEB_SPEED := 620.0
const WEB_CATCH_RADIUS := 38.0
const WEB_TIP_REACH := 25.0
const WEB_MIN_ATTACK_DISTANCE := 128.0
const WEB_COOLDOWN_TIME := 2.65
const WEB_MISS_COOLDOWN := 0.90
const WEB_MISS_RECOVERY := 0.08
const WEB_RECOVERY := 0.24
const REEL_STOP := 48.0
const REEL_SPEED := 230.0
const REEL_DURATION := 1.05
const REEL_MAX_PULL := 190.0
const REEL_SLACK_TIME := 0.12
const REEL_BIND_OFFSET := Vector2(0, -13)
const REEL_GRAB_WINDUP := 0.30
# Start close enough that part of the locked warning remains after the reel
# stops at 48. Steering can still take Xiaoyi out of the cone at that point.
const REEL_GRAB_START := 72.0
const REEL_GRAB_REACH := REEL_STOP + 6.0
const GRAB_MIN_PULL := 16.0
const GRAB_REACH := 96.0
const GRAB_LOCK_TIME := 0.04
const GRAB_HIGH_HOLD := 0.18
const GRAB_RELEASE_POSE_TIME := 0.075
const THROW_DURATION := 0.33
const THROW_SPEED := 264.0
const THROW_DISTANCE := 87.0
# Preserve the previous contact-to-ready interval after shortening the hold.
const THROW_RECOVERY := 0.84 + 0.34 - GRAB_LOCK_TIME - GRAB_HIGH_HOLD
const PINCH_MOUTH_OFFSET := 28.0
const PINCH_REACH := 43.0
const PINCH_TIME := [0.12, 0.33, 0.08, 0.30]
const SWEEP_REACH := 100.0
const SWEEP_NEAR := 45.0
const SWEEP_WINDUP := 0.32
const SWEEP_DAMAGE := 2
const SWEEP_COOLDOWN_TIME := 1.95
const SWEEP_LATERAL_SPEED := 65.0
const SWEEP_HALF := deg_to_rad(90.0)
const SWEEP_SLICES := 90
const PRESSURE_TIME := 3.0
const PRESSURE_MELEE_MULT := 1.18
const PRESSURE_MOVE_MULT := 1.20
const MELEE_PACE_CAP := 1.35
const SWEEP_HIT_TINT := Color(1.0, 0.52, 0.42)
const FOLLOW_DISTANCE := 48.0
const ROUTE_RETRY := 0.24
const PEEK_WINDOW := 5.0
const PEEK_CORNER_REACH := 88.0
const PEEK_EXIT_OFFSETS := [0.0, 10.0, 20.0]
const GROUND_WEB_RADIUS := 50.0
const GROUND_WEB_LIFETIME := 30.0
const GROUND_WEB_MAX_PATCHES := 10
const GROUND_WEB_FACTOR := 0.74
const GROUND_WEB_MAX_SLOW := 0.80
const OWN_WEB_MOVE_MULT := 1.20
const REEL_WEB_FACTOR := 0.58
const SLAM_RADIUS := 60.0
const SLAM_DAMAGE := 3
const SLAM_NEAR := 66.0
const SLAM_FAR := 105.0
const SLAM_COOLDOWN_TIME := 4.4
const SLAM_RELEASE_GRACE := 1.0
const SLAM_HITSTOP := 0.05
const FLANK_SPEED := 190.0
const CHASE_SPEED := 130.0
const RAGE_CHASE_SPEED := 156.0
const WALK_UNITS_PER_POSE := 9.5
const GRAB_HALF := deg_to_rad(30.0)
const PINCH_HALF := deg_to_rad(48.0)
const SILK := Color(0.72, 0.76, 0.61)
const CAUTION := Color(0.92, 0.60, 0.24)
const RAGE_RED := Color("f46b50")
enum Phase { ASSEMBLE, STALK, FLANK, WEB_SHOT, REEL, PINCH, SWEEP, SLAM, GRAB_WARN, LIFT, THROW, RECOVER, OFFLINE, CLEARANCE }
enum PeekResponse { NONE, QUEUED, CROSSING, SEARCHING }

var target: CharacterBody2D
var visual_scale := 0.85
var combat_debug := false
var arena_zone: Polygon2D
var arena := Rect2()
var machine_bounds := Rect2()
var chassis: CollisionShape2D
var health := MAX_HP
var applying_feedback_hit := false
var holding_fatal_feedback := false
var attack_pace := 1.0
var rage_flash := 0.0
var phase := Phase.ASSEMBLE
var left := 1.38
var span := 1.38
var locked := Vector2.DOWN
var face_right := true
var body_sprite := Sprite2D.new()
var art: Array[Texture2D] = []
var current_pose := 0
var web_tip := Vector2.ZERO
var web_direction := Vector2.DOWN
var flown := 0.0
var web_active := false
var web_close_peek := false
var bound := false
var reel_socket := Vector2.ZERO
var reel_slack_left := 0.0
var drawn_pull := 0.0
var reel_grab_warning := false
var reel_grab_elapsed := 0.0
var held := false
var throw_remaining := 0.0
var hit_flash := 0.0
var impact_left := 0.0
var impact_at := Vector2.ZERO
var route := PackedVector2Array()
var route_wait := 0.0
var route_target := Vector2.INF
var encounter_time := 0.0
var peek_hits: Dictionary[Vector2i, float] = {}
var peek_response := PeekResponse.NONE
var peek_corner := Vector2i.ZERO
var peek_last_seen := Vector2.ZERO
var peek_route := PackedVector2Array()
var peek_exit_index := 0
var peek_needs_flank := false
var web_followup := false
var web_result := "未发射"
var reel_end := "无"
var sidestep_goal := Vector2.INF
var flank_goal := Vector2.ZERO
var action_frame := 0
var action_left := 0.0
var miss_pose := false
var web_cooldown := 0.0
var grab_origin := Vector2.ZERO
var grab_hold_position := Vector2.ZERO
var grab_visual: GRAB_VISUAL
var throw_offset := Vector2.ZERO
var pose_anchors: Array = []
var armor := ArmorHitbox.new()
var metal := ArmorHitbox.new()
var metal_shape := CollisionShape2D.new()
var metal_mount := CollisionShape2D.new()
var metal_key := -1
var actions: Dictionary = {}
var flank_time := PackedFloat32Array()
var foot_anchor := Vector2(100, 122)
var claw_anchor := Vector2(100, 122)
var claw_flipped_anchor := Vector2(124, 122)
var sweep_offsets := PackedFloat32Array()
var sweep_total := 0.0
var sweep_clock := 0.0
var sweep_start_index := 0
var sweep_contact_index := 0
var sweep_struck := false
var sweep_hitstop := 0.0
var sweep_limits := PackedFloat32Array()
var sweep_visual: SWEEP_ART
var sweep_cooldown := 0.0
var sweep_after_dodge := 0.0
var pressure_left := 0.0
var pressure_lights := Node2D.new()
var previous_target := Vector2.INF
var target_lateral_speed := 0.0
var ground_visual: GROUND_FX
var clearance: CLEARANCE
var clearance_damage := 2
var clearance_pending := false
var clearance_used := false
var shadow_texture: Texture2D
var slam_anchor := Vector2(100, 168)
var slam_flip_anchor := Vector2(124, 168)
var slam_touch := Vector2.ZERO
var slam_flip_touch := Vector2.ZERO
var slam_offsets := PackedFloat32Array()
var slam_contact_frame := 5
var slam_total := 0.0
var slam_clock := 0.0
var slam_warning_pace := 1.0
var slam_point := Vector2.ZERO
var slam_limits := PackedFloat32Array()
var slam_impact: Dictionary = {}
var slam_hitstop := 0.0
var slam_cooldown := 0.0
var slam_grace := 0.0
var leftover_silk: Array[Dictionary] = []
var route_side := 0
var alternate_side := 0
var last_blocker := ""
var decision := ""
var walk_cycle := 0.0
var debug_shapes := Node2D.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0
	collision_mask = WORLD | PLAYER_FEET_LAYER
	motion_mode = MOTION_MODE_FLOATING
	process_physics_priority = 14
	add_to_group("combat_enemies")
	chassis = CollisionShape2D.new()
	chassis.name = "CollisionShape2D"
	var hull := CapsuleShape2D.new()
	hull.radius = _chassis_half().y
	hull.height = _chassis_half().x * 2.0
	chassis.rotation = PI * 0.5
	chassis.shape = hull
	chassis.disabled = true
	add_child(chassis)
	armor.name = "ShellHurtbox"
	armor.collision_layer = 0
	armor.collision_mask = 0
	armor.monitoring = false
	var armor_shape := CollisionShape2D.new()
	var silhouette := CapsuleShape2D.new()
	silhouette.radius = 25.0 * visual_scale
	silhouette.height = 87.0 * visual_scale
	armor_shape.shape = silhouette
	armor_shape.rotation = PI * 0.5
	armor.add_child(armor_shape)
	add_child(armor)
	metal.name = "LowerMetalHurtbox"
	metal.collision_layer = 0
	metal.collision_mask = 0
	metal.monitoring = false
	metal_shape.name = "LowerCrossmember"
	metal_mount.name = "NearLegMount"
	metal.add_child(metal_shape)
	metal.add_child(metal_mount)
	add_child(metal)
	for i in range(12):
		art.append(load(ART + "pose_%02d.png" % i) as Texture2D)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "anchors.json"))
	pose_anchors = parsed["spool"]
	_load_actions()
	_load_claw()
	_load_slam()
	shadow_texture = load(GROUND_ART + "contact_shadow.png") as Texture2D
	add_child(body_sprite)
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_sprite.centered = false
	body_sprite.z_index = 1
	body_sprite.scale = Vector2.ONE * visual_scale
	sweep_visual = SWEEP_ART.new()
	add_child(sweep_visual)
	pressure_lights.z_index = 2
	add_child(pressure_lights)
	pressure_lights.draw.connect(_draw_pressure_lights)
	pressure_lights.hide()
	ground_visual = GROUND_FX.new()
	add_child(ground_visual)
	clearance = CLEARANCE.new()
	clearance.silk_requested.connect(_drop_silk)
	add_child(clearance)
	grab_visual = GRAB_VISUAL.new()
	add_child(grab_visual)
	debug_shapes.z_index = 6
	add_child(debug_shapes)
	debug_shapes.draw.connect(_draw_debug_shapes)
	_set_pose(0)

func _load_actions() -> void:
	var folder := ART + "actions/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "frames.json"))
	var anchor: Array = manifest["foot_anchor"]
	foot_anchor = Vector2(float(anchor[0]), float(anchor[1]))
	for animation: Dictionary in manifest["animations"]:
		var textures: Array[Texture2D] = []
		for frame: Dictionary in animation["frames"]:
			textures.append(load(folder + str(frame["file"])) as Texture2D)
			if animation["id"] == "flank_step":
				flank_time.append(float(frame["preview_ms"]) / 1000.0)
		actions[animation["id"]] = textures

func _load_claw() -> void:
	var folder := ART + "right_claw/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "frames.json"))
	claw_anchor = Vector2(float(manifest.foot_anchor[0]), float(manifest.foot_anchor[1]))
	claw_flipped_anchor = Vector2(float(manifest.mirror_foot_anchor[0]), float(manifest.mirror_foot_anchor[1]))
	var textures: Array[Texture2D] = []
	var windup_scale := SWEEP_WINDUP / maxf(0.001, -float(manifest.frames[0].relative_to_vfx_ms) * 0.001)
	for frame: Dictionary in manifest.frames:
		var event: String = frame.get("event", "")
		if event == "start_sweep_vfx":
			sweep_start_index = textures.size()
		elif event == "sweep_hit_once":
			sweep_contact_index = textures.size()
		sweep_offsets.append(sweep_total)
		var hold := float(frame.hold_ms) * 0.001
		sweep_total += hold * windup_scale if float(frame.relative_to_vfx_ms) < 0.0 else hold
		textures.append(load(folder + str(frame.file)) as Texture2D)
	actions["wide_sweep"] = textures

func _load_slam() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GROUND_ART + "slam_frames.json"))
	slam_anchor = _pair(manifest.foot_anchor)
	slam_flip_anchor = _pair(manifest.mirror_foot_anchor)
	slam_contact_frame = int(manifest.contact_index)
	slam_touch = _pair(manifest.frames[slam_contact_frame].impact_point) - slam_anchor
	slam_flip_touch = _pair(manifest.mirror_landing_point) - slam_flip_anchor
	var textures: Array[Texture2D] = []
	for frame: Dictionary in manifest.frames:
		slam_offsets.append(slam_total)
		slam_total += float(frame.hold_ms) * 0.001
		textures.append(load(GROUND_ART + str(frame.file)) as Texture2D)
	actions["slam"] = textures

func _pair(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))

func _set_pose(index: int) -> void:
	current_pose = index
	body_sprite.texture = art[index]
	_align_sprite(index)

func _align_sprite(index: int, authored_anchor := Vector2.ZERO) -> void:
	body_sprite.flip_h = not face_right
	var anchor := foot_anchor if authored_anchor == Vector2.ZERO else authored_anchor
	body_sprite.position = -anchor * visual_scale
	var shell_y := -47 if index in [0, 4] else (-58 if index == 11 else -66)
	armor.position = Vector2(-7 if face_right else 7, shell_y) * visual_scale
	_align_lower_metal(14 if index in [0, 4] else (3 if index == 11 else 0))
	if hit_flash > 0.0:
		body_sprite.modulate = Color(1.55, 1.33, 1.12)
	elif _is_enraged():
		body_sprite.modulate = Color(1.16, 0.66, 0.57).lerp(RAGE_RED.lightened(0.23), 0.48 * rage_flash / RAGE_FLASH_TIME)
	else:
		body_sprite.modulate = Color(0.89, 0.88, 0.84)
	if phase == Phase.OFFLINE:
		body_sprite.modulate = Color(0.47, 0.48, 0.44)

func _align_lower_metal(drop: int) -> void:
	var key := drop * 2 + int(face_right)
	if key == metal_key:
		return
	metal_key = key
	# Back the visible metal crossmember and the chunky front leg root with
	# separate convex shapes. The disconnected tips, claw and ground gap
	# still do not take pulse hits.
	metal_shape.shape = _metal_profile(PackedVector2Array([Vector2(-28, -43), Vector2(16, -48),
		Vector2(35, -43), Vector2(38, -36), Vector2(23, -29), Vector2(-4, -26),
		Vector2(-24, -32), Vector2(-34, -38)]), drop)
	metal_mount.shape = _metal_profile(PackedVector2Array([Vector2(-30, -50), Vector2(-16, -50),
		Vector2(-9, -41), Vector2(-13, -29), Vector2(-21, -23), Vector2(-30, -25), Vector2(-37, -36)]), drop)

func _metal_profile(points: PackedVector2Array, drop: int) -> ConvexPolygonShape2D:
	for i in range(points.size()):
		var point := points[i]
		point.x *= 1.0 if face_right else -1.0
		point.y += drop
		points[i] = point * visual_scale
	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	return shape

func _switch(next: Phase, seconds: float) -> void:
	if phase == Phase.CLEARANCE and next != Phase.CLEARANCE and clearance.active:
		clearance.reset()
	if phase == Phase.SWEEP and next != Phase.SWEEP:
		sweep_hitstop = 0.0
		sweep_visual.clear()
	if phase == Phase.SLAM and next != Phase.SLAM and is_instance_valid(ground_visual):
		ground_visual.warning = false
	var duration := seconds
	if next in [Phase.PINCH, Phase.SWEEP, Phase.SLAM, Phase.GRAB_WARN]:
		# Snapshot the pace once. Pressure speeds up ordinary melee and the
		# return from a slam, while the heavy tell keeps its original cadence.
		attack_pace = _rage_pace() if next == Phase.GRAB_WARN else _melee_pace()
		if next == Phase.SLAM:
			slam_warning_pace = _rage_pace()
			var tell := slam_offsets[slam_contact_frame]
			duration = tell / slam_warning_pace + (seconds - tell) / attack_pace
		else:
			duration /= attack_pace
	if next in [Phase.WEB_SHOT, Phase.PINCH, Phase.SWEEP, Phase.SLAM, Phase.GRAB_WARN, Phase.LIFT]:
		web_followup = false
		sidestep_goal = Vector2.INF
	if combat_debug and phase != next:
		print("[Boss state] %s -> %s next_timer=%.2f %s" % [Phase.keys()[phase], Phase.keys()[next], duration, _diagnose()])
	phase = next
	left = duration
	span = duration
	velocity = Vector2.ZERO

func _recover(missed: bool, seconds: float) -> void:
	_release_tether()
	_release_grab()
	miss_pose = missed
	_switch(Phase.RECOVER, seconds)

func _begin_action(next: Phase, seconds: float) -> void:
	_switch(next, seconds)
	action_frame = 0
	action_left = seconds
	_update_frame()

func _progress() -> float:
	return clampf(1.0 - left / maxf(span, 0.001), 0.0, 0.999)

func _is_enraged() -> bool:
	return health > 0 and health <= RAGE_HP

func _rage_pace() -> float:
	return RAGE_ATTACK_PACE if _is_enraged() else 1.0

func _melee_pace() -> float:
	return minf(MELEE_PACE_CAP, _rage_pace() * (PRESSURE_MELEE_MULT if pressure_left > 0.0 else 1.0))

func _movement_multiplier() -> float:
	var multiplier := PRESSURE_MOVE_MULT if pressure_left > 0.0 else 1.0
	if not leftover_silk.is_empty():
		var space := get_world_2d().direct_space_state
		for patch in leftover_silk:
			if GROUND_FX.covers(space, patch.at, global_position, patch.limits):
				return multiplier * OWN_WEB_MOVE_MULT
	return multiplier

func _chase_speed() -> float:
	return (RAGE_CHASE_SPEED if _is_enraged() else CHASE_SPEED) * _movement_multiplier()

func _socket() -> Vector2:
	var pair: Array = pose_anchors[current_pose]
	var x := float(pair[0]) if face_right else 200.0 - float(pair[0])
	return body_sprite.position + Vector2(x, float(pair[1])) * visual_scale

func _on_screen() -> bool:
	return get_viewport_rect().grow(-10).has_point(get_global_transform_with_canvas() * armor.position)

func _can_see_player() -> bool:
	return _can_warn_at_target() and _line_clear(global_position, target.global_position)

func _can_warn_at_target() -> bool:
	return _on_screen() and is_instance_valid(target) and not target.is_dead and not target.has_protocol and _in_arena(target.global_position)

func configure_arena(zone: Polygon2D) -> void:
	arena_zone = zone
	# ExitCombat is a rectangle. Its world-space extent is used for the
	# navigation inset; attack eligibility uses the map polygon itself.
	arena = Rect2(zone.to_global(zone.polygon[0]), Vector2.ZERO)
	for point in zone.polygon:
		arena = arena.expand(zone.to_global(point))

func _in_arena(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(arena_zone.to_local(point), arena_zone.polygon)

func _line_clear(a: Vector2, b: Vector2) -> bool:
	if a.is_equal_approx(b):
		return true
	return _world_ray(a, b).is_empty()

func _world_ray(a: Vector2, b: Vector2) -> Dictionary:
	var ray := PhysicsRayQueryParameters2D.create(a, b, WORLD)
	ray.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(ray)

func _set_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.10:
		face_right = direction.x > 0

func _lock_at_player() -> void:
	locked = global_position.direction_to(target.global_position)
	if locked.is_zero_approx():
		locked = Vector2.DOWN
	_set_facing(locked)

func _physics_process(delta: float) -> void:
	encounter_time += delta
	left = maxf(0.0, left - delta)
	pressure_left = maxf(0.0, pressure_left - delta)
	var cooldown_delta := delta * _rage_pace()
	web_cooldown = maxf(0.0, web_cooldown - cooldown_delta)
	sweep_cooldown = maxf(0.0, sweep_cooldown - cooldown_delta)
	sweep_after_dodge = maxf(0.0, sweep_after_dodge - delta)
	slam_cooldown = maxf(0.0, slam_cooldown - cooldown_delta)
	slam_grace = maxf(0.0, slam_grace - delta)
	rage_flash = maxf(0.0, rage_flash - delta)
	_sample_target_motion(delta)
	_advance_slam_impact(delta)
	if is_instance_valid(target):
		grab_visual.advance(delta, target.global_position)
	hit_flash = maxf(0.0, hit_flash - delta)
	if sweep_hitstop <= 0.0 and clearance.hitstop <= 0.0:
		impact_left = maxf(0.0, impact_left - delta)
	if not is_instance_valid(target) or target.is_dead or target.has_protocol:
		if holding_fatal_feedback and is_instance_valid(target) and target.is_dead:
			# Only advance the finishing pose and effects while the death menu waits.
			if phase == Phase.SLAM:
				_slam(delta)
			elif phase == Phase.SWEEP:
				_sweep(delta)
			elif phase == Phase.CLEARANCE:
				_advance_clearance(delta)
		elif phase not in [Phase.ASSEMBLE, Phase.STALK, Phase.RECOVER, Phase.OFFLINE]:
			_recover(false, 0.5)
	else:
		match phase:
			Phase.ASSEMBLE:
				if left <= 0 and _chassis_is_clear_at(global_position, safe_margin):
					chassis.disabled = false
					collision_layer = CHASSIS_LAYER
					armor.collision_layer = ARMOR_LAYER
					metal.collision_layer = ARMOR_LAYER
					web_cooldown = 0.25
					_switch(Phase.STALK, 0.48)
			Phase.STALK:
				if not _try_begin_clearance():
					_stalk(delta)
			Phase.CLEARANCE:
				_advance_clearance(delta)
			Phase.FLANK:
				_flank(delta)
			Phase.WEB_SHOT:
				if web_active:
					_fly_web(delta)
			Phase.REEL:
				_reel(delta)
			Phase.PINCH:
				_pinch(delta)
			Phase.SWEEP:
				_sweep(delta)
			Phase.SLAM:
				_slam(delta)
			Phase.GRAB_WARN:
				if left <= 0:
					_resolve_grab()
			Phase.LIFT, Phase.THROW:
				_move_grab(delta)
			Phase.RECOVER:
				if left <= 0:
					if not _try_begin_clearance():
						_switch(Phase.STALK, 0.0)
						_stalk(delta)
	_update_ground_silk(delta)
	ground_visual.patches = leftover_silk
	if phase != Phase.CLEARANCE:
		ground_visual.impact = slam_impact
	ground_visual.queue_redraw()
	_update_frame()
	pressure_lights.visible = clearance.clock < clearance.time_to_finisher if phase == Phase.CLEARANCE else pressure_left > 0.0
	if pressure_lights.visible:
		pressure_lights.queue_redraw()
	queue_redraw()
	debug_shapes.queue_redraw()

func _try_begin_clearance() -> bool:
	if not clearance_pending or bound or held or not target.controls_enabled or not _in_arena(target.global_position):
		return false
	clearance_pending = false
	clearance_used = true
	_switch(Phase.CLEARANCE, clearance.duration)
	route.clear()
	sidestep_goal = Vector2.INF
	var speed_factor := minf(1.0, target.web_movement_factor())
	# Existing patches could overlap the route. Budget for the deepest legal slow.
	if not leftover_silk.is_empty():
		speed_factor = minf(speed_factor, 1.0 - GROUND_WEB_MAX_SLOW)
	clearance.start(global_position, face_right, visual_scale, arena, target, target.move_speed * speed_factor, ground_visual)
	face_right = clearance.face_right
	if combat_debug:
		print("[Boss clearance] planted=%s gap=%.1f entry=%s seals=%d" % [global_position, rad_to_deg(clearance.gap_angle),
			clearance.gap_entry, clearance.silk_spots.size()])
	return true

func _advance_clearance(delta: float) -> void:
	var holding := clearance.hitstop > 0.0
	var source := clearance.advance(delta, target.global_position, not target.is_dead and not target.has_protocol)
	if source != &"" and _apply_feedback_hit(clearance_damage):
		clearance.confirm_hit(source)
		_impact(target.global_position)
		holding = true
	if holding:
		target.facing.modulate = SWEEP_HIT_TINT
	left = clearance.duration - clearance.clock
	if left <= CLEARANCE.EPS:
		_switch(Phase.STALK, 0.0)

func _sample_target_motion(delta: float) -> void:
	target_lateral_speed = 0.0
	if not is_instance_valid(target) or (peek_response != PeekResponse.NONE and not _can_see_player()):
		previous_target = Vector2.INF
		return
	var at := target.global_position
	if previous_target.is_finite():
		var travel := at - previous_target
		if travel.length() <= target.move_speed * 1.7 * delta + 0.2:
			target_lateral_speed = absf(global_position.direction_to(at).cross(travel)) / delta
	previous_target = at

func _stalk(delta: float) -> void:
	route_wait = maxf(0.0, route_wait - delta)
	if peek_response != PeekResponse.NONE:
		_respond_to_peek(delta)
		return
	var point := target.global_position
	if not _in_arena(point):
		sidestep_goal = Vector2.INF
		var edge := _chassis_arena()
		_pursue(point.clamp(edge.position, edge.end - Vector2.ONE), 0.0, delta)
		return
	var offset := point - global_position
	_approach_target(delta, offset, offset.length())

func _visible_peek_corner(at: Vector2) -> Vector2i:
	var middle := machine_bounds.get_center()
	var side := Vector2i(-1 if at.x < middle.x else 1, -1 if at.y < middle.y else 1)
	var corner := Vector2(machine_bounds.position.x if side.x < 0 else machine_bounds.end.x,
		machine_bounds.position.y if side.y < 0 else machine_bounds.end.y)
	if (at.x - corner.x) * side.x < 0.0 or (global_position.x - middle.x) * side.x >= -machine_bounds.size.x * 0.5:
		return Vector2i.ZERO
	var hidden_point := Vector2(at.x, lerpf(corner.y, middle.y, 0.5))
	return side if at.distance_to(corner) <= PEEK_CORNER_REACH and not _line_clear(global_position, hidden_point) else Vector2i.ZERO

func _observe_peek() -> void:
	if peek_response != PeekResponse.NONE or not _can_see_player():
		return
	var seen := target.global_position
	var corner := _visible_peek_corner(seen)
	if corner == Vector2i.ZERO:
		return
	var previous: float = peek_hits.get(corner, -INF)
	peek_hits[corner] = encounter_time
	if encounter_time - previous <= PEEK_WINDOW:
		peek_response = PeekResponse.QUEUED
		peek_corner = corner
		peek_last_seen = seen
		peek_hits.clear()
		_decide("同侧露头两次：收招后换边")

func _respond_to_peek(delta: float) -> void:
	if peek_response == PeekResponse.SEARCHING:
		_reacquire_after_peek(delta)
		return
	if peek_response == PeekResponse.QUEUED:
		route.clear()
		route_wait = 0.0
		peek_exit_index = 0
		peek_response = PeekResponse.CROSSING
		if _select_peek_exit() and _try_close_peek():
			return

	while not peek_route.is_empty() and global_position.distance_to(peek_route[0]) <= 1.0:
		peek_route.remove_at(0)
		if peek_route.is_empty():
			peek_response = PeekResponse.SEARCHING
			_decide("已到另一侧：观察出口")
			_reacquire_after_peek(delta)
			return
	if not peek_route.is_empty() and not _can_peek_step(global_position, peek_route[0]):
		peek_route.clear()
		route_wait = 0.0
	if peek_route.is_empty() and (route_wait > 0.0 or not _select_peek_exit()):
		velocity = Vector2.ZERO
		_decide("换边出口受阻：重查路线")
		return
	var next := peek_route[0]
	_set_facing(global_position.direction_to(next))
	_decide("侧探：绕向对侧出口")
	if peek_needs_flank and global_position.distance_to(next) > 9.0:
		peek_needs_flank = false
		flank_goal = global_position.move_toward(next, 22.0)
		_begin_action(Phase.FLANK, _flank_frame_time(0))
	elif _move_chassis(next, _chase_speed(), delta):
		peek_route.clear()
		route_wait = 0.0

func _select_peek_exit() -> bool:
	var clearance := _chassis_half() + Vector2(9, 9)
	var middle := machine_bounds.get_center()
	var edge_y := machine_bounds.end.y if peek_corner.y < 0 else machine_bounds.position.y
	var span_x := machine_bounds.size.x * 0.5 + clearance.x
	while peek_exit_index < PEEK_EXIT_OFFSETS.size():
		var y := edge_y - peek_corner.y * (clearance.y + float(PEEK_EXIT_OFFSETS[peek_exit_index]))
		peek_exit_index += 1
		var exit := Vector2(middle.x + peek_corner.x * span_x, y)
		var entry := Vector2(middle.x - peek_corner.x * span_x, y)
		# The approach stays on this bank; only the opposite corridor
		# connects the two banks, regardless of hidden player movement.
		var already_at_corridor := (global_position.y - edge_y) * -peek_corner.y >= clearance.y - 1.0
		if already_at_corridor and _can_peek_step(global_position, exit):
			peek_route = PackedVector2Array([exit])
		elif (global_position.x - middle.x) * peek_corner.x <= 0.0 and _can_peek_step(entry, exit):
			peek_route = _peek_entry_path(entry)
			if not peek_route.is_empty():
				peek_route.append(exit)
		if not peek_route.is_empty():
			peek_needs_flank = true
			return true
	peek_exit_index = 0
	route_wait = 0.8
	return false

func _peek_entry_path(entry: Vector2) -> PackedVector2Array:
	if _can_peek_step(global_position, entry):
		return PackedVector2Array([entry])
	for offset: float in [24.0, 48.0]:
		var outside_x := entry.x - peek_corner.x * offset
		var bend := Vector2(outside_x, entry.y)
		var start := Vector2(outside_x, global_position.y)
		if _can_peek_step(global_position, start) and _can_peek_step(start, bend) and _can_peek_step(bend, entry):
			return PackedVector2Array([start, bend, entry])
	return PackedVector2Array()

func _can_peek_step(from: Vector2, to: Vector2) -> bool:
	if not _chassis_arena().has_point(to):
		return false
	# Plan against solid scenery only. move_and_collide still checks the
	# full chassis mask when the boss actually takes the step.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = chassis.shape
	query.collision_mask = WORLD
	var pose := chassis.global_transform
	pose.origin += to - global_position
	query.transform = pose
	var space := get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	pose.origin += from - to
	query.transform = pose
	query.motion = to - from
	return space.cast_motion(query)[0] >= 0.999

func _reacquire_after_peek(delta: float) -> void:
	if not _can_see_player():
		velocity = Vector2.ZERO
		return
	var offset := target.global_position - global_position
	var distance := offset.length()
	if _can_begin_slam(distance):
		peek_response = PeekResponse.NONE
		_begin_slam()
	elif _can_begin_sweep(distance):
		peek_response = PeekResponse.NONE
		_begin_sweep()
	elif distance > FOLLOW_DISTANCE + 0.5:
		_pursue(target.global_position, FOLLOW_DISTANCE, delta)
	elif not _sidestep(offset.normalized(), delta):
		velocity = Vector2.ZERO

func _approach_target(delta: float, offset: Vector2, distance: float) -> void:
	var clear := _can_see_player()
	var aim := offset.normalized()
	_set_facing(aim)
	if clear and left <= 0.0:
		var sweep_ready := _can_begin_sweep(distance)
		if sweep_ready and (target_lateral_speed >= SWEEP_LATERAL_SPEED or sweep_after_dodge > 0.0):
			_begin_sweep()
			return
		if _can_begin_slam(distance):
			_begin_slam()
			return
		if sweep_ready:
			_begin_sweep()
			return
		if _pinch_contains(target.global_position, aim):
			_lock_at_player()
			_begin_action(Phase.PINCH, PINCH_TIME[0])
			return
		if _can_begin_web(distance) and _try_fire_web(false):
			return
	if not clear and left <= 0.0 and _can_begin_web(distance, true) and _try_fire_web(true):
		return
	if clear and distance <= FOLLOW_DISTANCE + 0.5:
		if not _sidestep(aim, delta):
			_decide("贴身：等待攻击窗口")
			var ahead := global_position.move_toward(target.global_position, 6.0)
			if _can_step(global_position, ahead):
				_move_chassis(ahead, _chase_speed(), delta)
			else:
				velocity = Vector2.ZERO
		return
	sidestep_goal = Vector2.INF
	_pursue(target.global_position, FOLLOW_DISTANCE, delta)

func _pursue(destination: Vector2, stop_distance: float, delta: float) -> void:
	var distance := global_position.distance_to(destination)
	var limits := _chassis_arena()
	var goal := global_position.move_toward(destination, maxf(0.0, distance - stop_distance)).clamp(limits.position, limits.end - Vector2.ONE)
	if stop_distance == 0.0 and distance <= 1.0:
		route.clear()
		velocity = Vector2.ZERO
		_decide("战区边缘：跟住玩家")
		return
	if goal.distance_to(global_position) > 0.2 and _can_step(global_position, goal) and _line_clear(goal, destination):
		route.clear()
		route_wait = 0.0
		_decide("正面逼近" if _on_screen() else "从画面外靠近，不出招")
		_set_facing(global_position.direction_to(goal))
		_move_chassis(goal, _chase_speed(), delta)
		return
	while not route.is_empty() and global_position.distance_to(route[0]) <= 1.0:
		route.remove_at(0)
	if not route.is_empty() and not _can_step(global_position, route[0]):
		_replan_after_block()
	if route_wait == 0.0 and (route.is_empty() or route_target.distance_to(destination) > 32.0):
		if _try_flank_route(destination, stop_distance):
			return
	if route.is_empty():
		velocity = Vector2.ZERO
		_decide("通道堵塞：继续寻找路径")
	else:
		_decide("沿设备侧面逼近")
		_set_facing(global_position.direction_to(route[0]))
		if _move_chassis(route[0], _chase_speed(), delta):
			_replan_after_block()

func _sidestep(aim: Vector2, delta: float) -> bool:
	if not sidestep_goal.is_finite() or not _can_step(global_position, sidestep_goal):
		sidestep_goal = Vector2.INF
		var side := aim.orthogonal()
		for reach: float in [18.0, -18.0, 8.0, -8.0]:
			var point := global_position + side * reach
			if _can_step(global_position, point):
				sidestep_goal = point
				break
	if not sidestep_goal.is_finite():
		return false
	route.clear()
	_decide("近身：侧移找角度")
	if _move_chassis(sidestep_goal, _chase_speed() * 0.86, delta) or global_position.distance_to(sidestep_goal) <= 1.0:
		sidestep_goal = Vector2.INF
	return true

func _decide(reason: String) -> void:
	if combat_debug and reason != decision:
		print("[Boss decision] %s %s" % [reason, _diagnose()])
	decision = reason

func _diagnose() -> String:
	if not is_instance_valid(target):
		return "no target"
	var distance := global_position.distance_to(target.global_position)
	var clear := _line_clear(global_position, target.global_position)
	var options: Array[String] = []
	if clear and _can_begin_sweep(distance):
		options.append("sweep")
	if clear and _can_begin_slam(distance):
		options.append("slam")
	if clear and phase == Phase.REEL and bound and reel_grab_warning and drawn_pull >= GRAB_MIN_PULL and distance <= REEL_GRAB_REACH:
		options.append("grab")
	if _can_begin_web(distance, not clear):
		options.append("web" if clear else "web_cover")
	var waypoints := peek_route if not peek_route.is_empty() else route
	return "state=%s t=%.2f action=%.2f d=%.1f feet=%s in_arena=%s on_screen=%s LOS=%s pinch_locked=%s options=%s web_cd=%.2f web=%s reel_end=%s slack=%.2f pulled=%.1f peek=%s next=%s blocker=%s" % [
		Phase.keys()[phase], left, action_left, distance, target.global_position, _in_arena(target.global_position), _on_screen(), clear, _pinch_contains(target.global_position, locked),
		options, web_cooldown, web_result, reel_end, reel_slack_left, drawn_pull, PeekResponse.keys()[peek_response], waypoints[0] if not waypoints.is_empty() else "-", last_blocker]

func _can_begin_web(distance: float, cover_shot := false) -> bool:
	if not _can_warn_at_target() or web_cooldown > 0.0:
		return false
	if cover_shot:
		return distance <= WEB_RANGE + WEB_TIP_REACH
	return distance >= WEB_MIN_ATTACK_DISTANCE and distance <= WEB_RANGE

func _try_fire_web(cover_shot: bool) -> bool:
	var origin := _web_origin()
	var aim := target.global_position
	var wall := _world_ray(origin, aim)
	if wall.is_empty() and cover_shot:
		wall = _world_ray(global_position, aim)
	if not wall.is_empty():
		var surface: Vector2 = wall.position
		if origin.distance_to(surface) > WEB_RANGE:
			return false
		# Aim a little inside the near face so the projectile sweep stops there.
		aim = surface - Vector2(wall.normal) * 2.0
	elif cover_shot:
		return false
	var direction := origin.direction_to(aim)
	if direction.is_zero_approx():
		return false
	web_tip = origin
	web_direction = direction
	_fire_web()
	return true

func _web_origin() -> Vector2:
	# Keep the original spool origin and lock direction on the firing tick.
	var anchor: Array = pose_anchors[4]
	var x := float(anchor[0]) if face_right else 200.0 - float(anchor[0])
	return to_global((Vector2(x, float(anchor[1])) - foot_anchor) * visual_scale)

func _try_close_peek() -> bool:
	if web_cooldown > 0.0 or not _on_screen():
		return false
	var edge_y := machine_bounds.position.y if peek_corner.y < 0 else machine_bounds.end.y
	var aim := Vector2(machine_bounds.get_center().x, edge_y - peek_corner.y * 10.0)
	_set_facing(global_position.direction_to(aim))
	var origin := _web_origin()
	var wall := _world_ray(origin, aim)
	if not _is_peek_wall(wall):
		return false
	var contact: Vector2 = wall.position
	if origin.distance_to(contact) > WEB_RANGE or not _has_clean_peek_escape(contact.move_toward(origin, 2.0)):
		return false
	web_tip = origin
	web_direction = origin.direction_to(contact)
	if web_direction.is_zero_approx():
		return false
	_decide("吐丝封住旧露头口")
	_fire_web(true)
	return true

func _is_peek_wall(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var edge_y := machine_bounds.position.y if peek_corner.y < 0 else machine_bounds.end.y
	var at: Vector2 = hit.position
	return machine_bounds.grow(1.0).has_point(at) and absf(at.y - edge_y) <= GROUND_WEB_RADIUS * 0.6

func _has_clean_peek_escape(silk_at: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var limits := GROUND_FX.clip_disk(space, silk_at, GROUND_WEB_RADIUS)
	if not Array(limits).any(func(radius: float) -> bool: return radius > 0.25):
		return false
	# Verify an escape for the player's actual collision shape, starting
	# where we last saw the peek. Hidden movement never moves this origin.
	for direction: Vector2 in [Vector2(peek_corner.x, 0), Vector2(0, -peek_corner.y), Vector2(0, peek_corner.y)]:
		var exit := peek_last_seen + direction * (GROUND_WEB_RADIUS + 26.0)
		if not _in_arena(exit) or not arena.grow(-4.0).has_point(exit) or not ROUTER.can_travel(target, peek_last_seen, exit):
			continue
		var clean := true
		for i in range(13):
			var point := peek_last_seen.lerp(exit, i / 12.0)
			if GROUND_FX.covers(space, silk_at, point, limits) or leftover_silk.any(
				func(patch: Dictionary) -> bool: return GROUND_FX.covers(space, patch.at, point, patch.limits)):
				clean = false
				break
		if clean:
			return true
	return false

func _try_flank_route(destination: Vector2, stop_distance: float) -> bool:
	var new_detour := route.is_empty()
	route_wait = ROUTE_RETRY
	route_target = destination
	route = _route_around_machine(destination, 59.0 if stop_distance > 0.0 else 0.0)
	var aim := global_position.direction_to(destination)
	if route.is_empty() or global_position.direction_to(route[0]).dot(aim) < -0.1:
		# The corners only describe the compressor. Gates and other fixtures
		# use the general planner with the same solid chassis.
		var detour := ROUTER.find_route(self, destination, stop_distance)
		var limits := _chassis_arena()
		for point in detour:
			if not limits.has_point(point):
				detour.clear()
				break
		if not detour.is_empty() and (route.is_empty() or _route_length(detour) < _route_length(route)):
			route = detour
	route_side = _path_side(route)
	alternate_side = 0
	if not new_detour or route.is_empty() or global_position.distance_to(route[0]) <= 9.0:
		return false
	flank_goal = global_position.move_toward(route[0], 22.0)
	_set_facing(global_position.direction_to(flank_goal))
	_begin_action(Phase.FLANK, _flank_frame_time(0))
	return true

func _route_length(waypoints: PackedVector2Array) -> float:
	var distance := 0.0
	var previous := global_position
	for point in waypoints:
		distance += previous.distance_to(point)
		previous = point
	return distance

func _chassis_half() -> Vector2:
	return CHASSIS_HALF * visual_scale

func _chassis_is_clear_at(at: Vector2, margin := 0.0) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = chassis.shape
	var placement := chassis.global_transform
	placement.origin += at - global_position
	query.transform = placement
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = margin
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _chassis_arena() -> Rect2:
	var half := _chassis_half()
	return arena.grow_individual(-half.x, -half.y, -half.x, -half.y)

func _can_step(from: Vector2, to: Vector2) -> bool:
	return _chassis_arena().has_point(to) and _chassis_is_clear_at(to) and ROUTER.can_travel(self, from, to)

func _move_chassis(goal: Vector2, speed: float, delta: float) -> bool:
	var step := (goal - global_position).limit_length(speed * delta)
	velocity = Vector2.ZERO
	if step.is_zero_approx():
		return false
	if not _chassis_arena().has_point(global_position + step):
		return true
	var before := global_position
	var collision := move_and_collide(step)
	last_blocker = str(collision.get_collider().name) if collision != null and is_instance_valid(collision.get_collider()) else ""
	var displacement := global_position - before
	velocity = displacement / delta
	walk_cycle = fposmod(walk_cycle + displacement.length() / WALK_UNITS_PER_POSE, float(POSE["walk"].size()))
	return collision != null

func _route_around_machine(destination: Vector2, stand_off := 59.0) -> PackedVector2Array:
	# Four clearance corners give routes on either side of the real equipment.
	# Every link uses the same rotated capsule as movement, not a centre ray.
	var clearance := _chassis_half() + Vector2(9, 9)
	var corners := Rect2(machine_bounds.position - clearance, machine_bounds.size + clearance * 2.0)
	var points := PackedVector2Array([global_position, corners.position, Vector2(corners.end.x, corners.position.y), corners.end, Vector2(corners.position.x, corners.end.y)])
	var graph := AStar2D.new()
	for i in range(points.size()):
		graph.add_point(i, points[i])
		for j in range(i):
			if _can_step(points[i], points[j]) and _can_step(points[j], points[i]):
				graph.connect_points(i, j)
	var best := PackedVector2Array()
	var best_length := INF
	for i in range(1 if stand_off == 0.0 else 8):
		var approach := destination + Vector2.from_angle(i * TAU / 8.0) * stand_off
		if not _chassis_arena().has_point(approach) or not _line_clear(approach, destination):
			continue
		var goal_id := points.size()
		graph.add_point(goal_id, approach)
		for j in range(points.size()):
			if _can_step(points[j], approach):
				graph.connect_points(j, goal_id, false)
		var trial := _preferred_machine_path(graph, goal_id) if stand_off > 0.0 else PackedVector2Array()
		var used_alternate := not trial.is_empty()
		if not used_alternate:
			trial = graph.get_point_path(0, goal_id)
		graph.remove_point(goal_id)
		if trial.size() < 2:
			continue
		var length := 0.0
		for j in range(1, trial.size()):
			length += trial[j - 1].distance_to(trial[j])
		if used_alternate:
			length -= 1000.0
		if length < best_length:
			best = trial.slice(1)
			best_length = length
	return best

func _preferred_machine_path(graph: AStar2D, goal_id: int) -> PackedVector2Array:
	if alternate_side == 0:
		return PackedVector2Array()
	var east := global_position.x >= machine_bounds.get_center().x
	var west_corner := 1 if alternate_side < 0 else 4
	var east_corner := 2 if alternate_side < 0 else 3
	var entry := east_corner if east else west_corner
	var departure := west_corner if east else east_corner
	# Only force the other side if that corridor actually connects. Otherwise
	# the general search can still use the remaining route.
	if not graph.are_points_connected(entry, departure, false):
		return PackedVector2Array()
	var approach := graph.get_point_path(0, entry)
	var exit_path := graph.get_point_path(departure, goal_id)
	if approach.is_empty() or exit_path.is_empty():
		return PackedVector2Array()
	approach.append_array(exit_path)
	return approach

func _path_side(points: PackedVector2Array) -> int:
	for point in points:
		if point.y < machine_bounds.position.y:
			return -1
		if point.y > machine_bounds.end.y:
			return 1
	return 0

func _flank(delta: float) -> void:
	if action_frame < 2:
		var can_step := _can_peek_step(global_position, flank_goal) if peek_response == PeekResponse.CROSSING else _can_step(global_position, flank_goal)
		if not can_step:
			_interrupt_flank()
			return
	if action_frame == 2 and action_left > 0.0 and _move_chassis(flank_goal, FLANK_SPEED * _movement_multiplier(), minf(delta, action_left)):
		_interrupt_flank()
		return
	action_left -= delta
	if action_left <= 0.0:
		velocity = Vector2.ZERO
		action_frame += 1
		if action_frame == 4:
			_switch(Phase.STALK, 0.0)
		else:
			action_left = _flank_frame_time(action_frame)

func _flank_frame_time(index: int) -> float:
	if index < 2:
		return flank_time[index] * (0.35 if web_followup else 0.55)
	return flank_time[index]

func _replan_after_block() -> void:
	alternate_side = -route_side
	route.clear()
	route_wait = 0.0

func _interrupt_flank() -> void:
	if peek_response == PeekResponse.CROSSING:
		peek_route.clear()
	_replan_after_block()
	if combat_debug:
		print("[Boss flank blocked] next_side=%d %s" % [alternate_side, _diagnose()])
	_switch(Phase.STALK, 0.0)

func _pinch_mouth(aim := Vector2.INF) -> Vector2:
	return global_position + (aim if aim.is_finite() else locked) * PINCH_MOUTH_OFFSET * visual_scale

func _pinch_contains(point: Vector2, aim := Vector2.INF) -> bool:
	var mouth := _pinch_mouth(aim)
	var offset := point - mouth
	var direction := aim if aim.is_finite() else locked
	return offset.length() <= PINCH_REACH and absf(direction.angle_to(offset)) <= PINCH_HALF \
		and _line_clear(global_position, mouth) and _line_clear(mouth, point)

func _pinch(delta: float) -> void:
	action_left -= delta * attack_pace
	if action_left > 0.0:
		return
	action_frame += 1
	if action_frame == PINCH_TIME.size():
		_recover(false, 0.36)
		return
	action_left += PINCH_TIME[action_frame]
	if action_frame == 2:
		if _can_see_player() and _pinch_contains(target.global_position, locked):
			target.apply_damage(1)
			_impact(target.global_position)
		elif _in_arena(target.global_position) and _line_clear(global_position, target.global_position):
			sweep_after_dodge = 1.55

func _can_begin_sweep(distance: float) -> bool:
	if sweep_cooldown > 0.0 or distance < SWEEP_NEAR or distance > SWEEP_REACH:
		return false
	var aim := global_position.direction_to(target.global_position)
	# The player is on the centre ray on commit. Check the same neighbouring
	# rays that form the first slice to the right of the centre.
	var step := SWEEP_HALF * 2.0 / SWEEP_SLICES
	for offset in [0.0, step * 0.5, step]:
		var hit := _world_ray(global_position, global_position + aim.rotated(offset) * SWEEP_REACH)
		if not hit.is_empty() and global_position.distance_to(hit.position) - 0.75 < distance:
			return false
	return true

func _begin_sweep() -> void:
	_lock_at_player()
	sweep_cooldown = SWEEP_COOLDOWN_TIME
	sweep_after_dodge = 0.0
	sweep_clock = 0.0
	sweep_struck = false
	sweep_hitstop = 0.0
	_begin_action(Phase.SWEEP, sweep_total)
	_refresh_sweep_limits()

func _sweep(delta: float) -> void:
	if sweep_hitstop > 0.0:
		var hold := minf(sweep_hitstop, delta)
		sweep_hitstop -= hold
		delta -= hold
		left += hold
		if is_instance_valid(target):
			target.facing.modulate = SWEEP_HIT_TINT
		# A moving shutter still clips the visual during the hold.
		_refresh_sweep_limits()
		_present_sweep()
		if delta <= 0.00001:
			return
	sweep_clock += delta * attack_pace
	var contact := not sweep_struck and sweep_clock + 0.00001 >= sweep_offsets[sweep_contact_index]
	if contact:
		sweep_clock = sweep_offsets[sweep_contact_index]
	if sweep_clock + 0.00001 >= sweep_total:
		if is_instance_valid(target) and not target.is_dead:
			pressure_left = PRESSURE_TIME
		_recover(false, 0.18)
		return
	while action_frame + 1 < sweep_offsets.size() and sweep_clock + 0.00001 >= sweep_offsets[action_frame + 1]:
		action_frame += 1
	action_left = (sweep_offsets[action_frame + 1] if action_frame + 1 < sweep_offsets.size() else sweep_total) - sweep_clock
	_refresh_sweep_limits()
	if action_frame >= sweep_start_index:
		_present_sweep()
	if contact:
		sweep_struck = true
		if _can_see_player() and _sweep_contains_point(target.global_position) and _apply_feedback_hit(SWEEP_DAMAGE):
			_impact(target.global_position)
			sweep_hitstop = sweep_visual.hitstop_seconds
			target.facing.modulate = SWEEP_HIT_TINT
		if combat_debug:
			print("[Boss sweep] claw=%02d effect=%02d t=%.3f hold=%.3f" % [action_frame + 1, sweep_visual.frame_index + 1, sweep_clock, sweep_hitstop])

func _present_sweep() -> void:
	var fx_age := maxf(0.0, sweep_clock - sweep_offsets[sweep_start_index])
	sweep_visual.present(locked, not face_right, fx_age, SWEEP_HALF, SWEEP_REACH, sweep_limits)

func _refresh_sweep_limits() -> void:
	# Sample the same world mask for the warning, atlas mesh, and hit check.
	var limits := PackedFloat32Array()
	var last := _sweep_ray_length(-SWEEP_HALF)
	var step := (SWEEP_HALF * 2.0) / SWEEP_SLICES
	for i in range(SWEEP_SLICES):
		var next := _sweep_ray_length(-SWEEP_HALF + (i + 1) * step)
		var mid := _sweep_ray_length(-SWEEP_HALF + (i + 0.5) * step)
		limits.append(minf(last, minf(mid, next)))
		last = next
	sweep_limits = limits

func _sweep_ray_length(angle: float) -> float:
	var end := global_position + locked.rotated(angle) * SWEEP_REACH
	var hit := _world_ray(global_position, end)
	return SWEEP_REACH if hit.is_empty() else maxf(0.0, global_position.distance_to(hit.position) - 0.75)

func _sweep_contains_point(point: Vector2) -> bool:
	var offset := point - global_position
	var angle := locked.angle_to(offset)
	if absf(angle) > SWEEP_HALF or sweep_limits.is_empty():
		return false
	var index := mini(int((angle + SWEEP_HALF) / (2.0 * SWEEP_HALF) * SWEEP_SLICES), SWEEP_SLICES - 1)
	return offset.length() <= sweep_limits[index] and _line_clear(global_position, point)

func _slam_landing(right: bool) -> Vector2:
	return global_position + (slam_touch if right else slam_flip_touch) * visual_scale

func _can_begin_slam(distance: float) -> bool:
	if slam_cooldown > 0.0 or slam_grace > 0.0 or distance < SLAM_NEAR or distance > SLAM_FAR:
		return false
	var aim := global_position.direction_to(target.global_position)
	var at := _slam_landing(aim.x > 0.0 if absf(aim.x) > 0.10 else face_right)
	return _in_arena(at) and arena.grow(-3.0).has_point(at) and at.distance_to(target.global_position) <= SLAM_RADIUS \
		and _line_clear(global_position, at) and _line_clear(at, target.global_position)

func _begin_slam() -> void:
	_lock_at_player()
	slam_point = _slam_landing(face_right)
	slam_clock = 0.0
	slam_hitstop = 0.0
	slam_cooldown = SLAM_COOLDOWN_TIME
	_begin_action(Phase.SLAM, slam_total)
	_refresh_slam_warning()

func _refresh_slam_warning() -> void:
	slam_limits = GROUND_FX.clip_disk(get_world_2d().direct_space_state, slam_point, SLAM_RADIUS)
	ground_visual.warning = action_frame >= 1 and action_frame < slam_contact_frame
	ground_visual.warning_point = slam_point
	ground_visual.warning_radii = slam_limits
	ground_visual.warning_progress = clampf(inverse_lerp(slam_offsets[1], slam_offsets[slam_contact_frame], slam_clock), 0.0, 1.0)

func _slam(delta: float) -> void:
	if slam_hitstop > 0.0:
		slam_hitstop = maxf(0.0, slam_hitstop - delta)
		if slam_hitstop > 0.00001:
			return
		slam_hitstop = 0.0
		# The authored contact hold is the hit stop, not a second extra hold.
		slam_clock = slam_offsets[slam_contact_frame + 1]
	else:
		var pace := slam_warning_pace if slam_clock + 0.00001 < slam_offsets[slam_contact_frame] else attack_pace
		slam_clock += delta * pace
	if slam_clock + 0.00001 >= slam_total:
		_recover(false, 0.50 if slam_impact.get("hurt", false) else 0.93)
		return
	var prior_frame := action_frame
	while action_frame + 1 < slam_offsets.size() and slam_clock + 0.00001 >= slam_offsets[action_frame + 1]:
		action_frame += 1
	action_left = (slam_offsets[action_frame + 1] if action_frame + 1 < slam_offsets.size() else slam_total) - slam_clock
	if prior_frame < slam_contact_frame:
		if not _line_clear(global_position, slam_point):
			_recover(false, 0.93)
			return
		_refresh_slam_warning()
		if action_frame == slam_contact_frame:
			_land_slam()

func _land_slam() -> void:
	slam_clock = slam_offsets[slam_contact_frame]
	slam_hitstop = SLAM_HITSTOP
	var hurt: bool = not target.is_dead and not target.has_protocol and _in_arena(target.global_position) \
		and GROUND_FX.covers(get_world_2d().direct_space_state, slam_point, target.global_position, slam_limits)
	slam_impact = {"at": slam_point, "age": 0.0, "radius": SLAM_RADIUS, "limits": slam_limits, "hurt": hurt}
	if combat_debug:
		print("[Boss slam] pose=%02d fx=01 point=%s radius=%.0f hurt=%s" % [action_frame + 1, slam_point, SLAM_RADIUS, hurt])
	slammed.emit(slam_point)
	if hurt:
		_apply_feedback_hit(SLAM_DAMAGE)

func _apply_feedback_hit(amount: int) -> bool:
	var before: int = target.health
	applying_feedback_hit = true
	target.apply_damage(amount)
	applying_feedback_hit = false
	return target.health < before

func _advance_slam_impact(delta: float) -> void:
	if slam_impact.is_empty():
		return
	slam_impact.age += delta
	if slam_impact.age >= ground_visual.duration(&"slam"):
		slam_impact.clear()
	else:
		slam_impact.limits = GROUND_FX.clip_disk(get_world_2d().direct_space_state, slam_impact.at, SLAM_RADIUS)

func _fire_web(close_peek := false) -> void:
	web_cooldown = WEB_COOLDOWN_TIME
	flown = 0.0
	web_active = true
	web_close_peek = close_peek
	web_result = "飞行中"
	reel_end = "无"
	drawn_pull = 0.0
	_switch(Phase.WEB_SHOT, WEB_RANGE / WEB_SPEED)

func _fly_web(delta: float) -> void:
	var amount := minf(WEB_SPEED * delta, WEB_RANGE - flown)
	var next := web_tip + web_direction * amount
	var ray := PhysicsRayQueryParameters2D.create(web_tip, next, 1)
	ray.hit_from_inside = true
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	var end: Vector2 = wall.get("position", next)
	if not web_close_peek and _web_can_catch(end):
		web_active = false
		bound = true
		reel_socket = to_local(_web_origin())
		reel_slack_left = 0.0
		web_result = "命中"
		_drop_silk(target.global_position)
		drawn_pull = 0.0
		reel_grab_warning = false
		reel_grab_elapsed = 0.0
		_switch(Phase.REEL, REEL_DURATION)
		return
	var previous_tip := web_tip
	flown += amount
	web_tip = end
	if not wall.is_empty() or flown >= WEB_RANGE:
		var landing := end.move_toward(previous_tip, 2.0) if not wall.is_empty() else end
		if not web_close_peek or (_is_peek_wall(wall) and _has_clean_peek_escape(landing)):
			_drop_silk(landing)
		_impact(end)
		web_result = "打空撞墙" if not wall.is_empty() else "打空到达射程"
		web_cooldown = minf(web_cooldown, WEB_MISS_COOLDOWN)
		_finish_web("无", WEB_MISS_RECOVERY)

func _web_can_catch(end: Vector2) -> bool:
	var point := target.global_position
	var on_path := Geometry2D.get_closest_point_to_segment(point, web_tip, end)
	var offset := point - on_path
	var catch_offset := Vector2(offset.dot(web_direction) / WEB_TIP_REACH, offset.cross(web_direction) / WEB_CATCH_RADIUS)
	return _in_arena(point) and catch_offset.length_squared() <= 1.0 and _line_clear(on_path, point)

func _drop_silk(at: Vector2) -> void:
	var limits := GROUND_FX.clip_disk(get_world_2d().direct_space_state, at, GROUND_WEB_RADIUS)
	if Array(limits).any(func(length: float) -> bool: return length > 0.25):
		if leftover_silk.size() >= GROUND_WEB_MAX_PATCHES:
			leftover_silk.pop_front()
		leftover_silk.append({"at": at, "age": 0.0, "left": GROUND_WEB_LIFETIME, "radius": GROUND_WEB_RADIUS, "limits": limits})

func _update_ground_silk(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	var can_count: bool = is_instance_valid(target) and not target.is_dead
	var slow := 0.0
	for i in range(leftover_silk.size() - 1, -1, -1):
		var patch := leftover_silk[i]
		patch.left -= delta
		if patch.left <= 0.0:
			leftover_silk.remove_at(i)
			continue
		patch.age += delta
		patch.limits = GROUND_FX.clip_disk(space, patch.at, GROUND_WEB_RADIUS)
		if can_count and slow < GROUND_WEB_MAX_SLOW and GROUND_FX.covers(space, patch.at, target.global_position, patch.limits):
			slow = minf(slow + (1.0 - GROUND_WEB_FACTOR), GROUND_WEB_MAX_SLOW)
	if not is_instance_valid(target):
		return
	var factor := 1.0 - slow
	if bound and reel_slack_left <= 0.0:
		factor = minf(factor, REEL_WEB_FACTOR)
	# Recompute only the Boss effect. Ordinary cleaner silk uses its own timer.
	target.boss_web_speed_factor = factor if target.controls_enabled and not target.is_dead and not target.has_protocol else 1.0

func _reel(delta: float) -> void:
	var before := target.global_position
	if not _in_arena(before):
		_finish_web("目标离场")
		return
	var distance := before.distance_to(global_position)
	var line_clear := _line_clear(to_global(reel_socket), _reel_binding_point())
	if left <= 0.0:
		if reel_slack_left > 0.0 or not line_clear:
			_finish_web("超时")
		else:
			_finish_reel(distance, "超时")
		return
	var direction := before.direction_to(global_position)
	var remaining_pull := maxf(0.0, REEL_MAX_PULL - drawn_pull)
	var pull := clampf(distance - REEL_STOP, 0.0, minf(REEL_SPEED * delta, remaining_pull))
	var step := direction * pull
	if not _in_arena(before + step):
		_finish_web("拉动到战区边界")
		return
	var blocked := not line_clear or (reel_slack_left > 0.0 and pull > 0.0 and target.test_move(target.global_transform, step))
	if blocked:
		_slacken_reel(delta)
		return
	if reel_slack_left > 0.0:
		reel_slack_left = 0.0
		reel_end = "无"
		_decide("继续收线：丝路恢复")
	if _progress() < 0.13:
		return
	if pull > 0.0:
		var collision := target.move_and_collide(step)
		drawn_pull = minf(REEL_MAX_PULL, drawn_pull + maxf(0.0, (target.global_position - before).dot(direction)))
		if collision != null:
			_slacken_reel(delta)
			return
	if reel_grab_warning:
		reel_grab_elapsed += delta
	elif distance <= REEL_GRAB_START:
		reel_grab_warning = true
		_lock_at_player()
	var reached := target.global_position.distance_to(global_position)
	if drawn_pull >= REEL_MAX_PULL - 0.05:
		_finish_reel(reached, "达到拉距上限")
	elif reached <= REEL_STOP + 0.05 and (drawn_pull < GRAB_MIN_PULL or reel_grab_elapsed >= REEL_GRAB_WINDUP):
		_finish_reel(reached, "到达近身停点")

func _reel_binding_point() -> Vector2:
	return target.global_position + REEL_BIND_OFFSET

func _slacken_reel(delta: float) -> void:
	if reel_slack_left <= 0.0:
		reel_slack_left = REEL_SLACK_TIME
		reel_end = "短暂遮挡"
		_decide("松线：短暂遮挡")
	else:
		reel_slack_left = maxf(0.0, reel_slack_left - delta)
		if reel_slack_left <= 0.0:
			_finish_web("持续遮挡")

func _finish_reel(distance: float, reason: String) -> void:
	if bound and reel_slack_left <= 0.0 and reel_grab_warning and reel_grab_elapsed >= REEL_GRAB_WINDUP \
		and drawn_pull >= GRAB_MIN_PULL and distance <= REEL_GRAB_REACH \
		and target.controls_enabled and target.invulnerability_remaining <= 0.0 and _in_cone(REEL_GRAB_REACH, GRAB_HALF):
		# The claw warned during the pull. Resolve it on this tick instead of
		# starting a second warning after the silk detaches.
		reel_end = reason + "，抓投预警完成且有效"
		_release_tether()
		_resolve_grab(REEL_GRAB_REACH)
	else:
		_finish_web(reason)

func _finish_web(reason: String, recovery := WEB_RECOVERY) -> void:
	reel_end = reason
	web_followup = true
	route.clear()
	route_wait = 0.0
	_recover(false, recovery)

func _release_tether() -> void:
	web_active = false
	web_close_peek = false
	if bound and is_instance_valid(target):
		slam_grace = SLAM_RELEASE_GRACE
	bound = false
	reel_slack_left = 0.0
	reel_grab_warning = false
	reel_grab_elapsed = 0.0

func _begin_grab_warning() -> void:
	_lock_at_player()
	_switch(Phase.GRAB_WARN, 0.86)

func _in_cone(radius: float, half: float) -> bool:
	if not _can_see_player():
		return false
	var off := target.global_position - global_position
	return off.length() <= radius and (off.length() < 5 or absf(locked.angle_to(off)) <= half)

func _resolve_grab(reach := GRAB_REACH) -> void:
	if not _in_cone(reach, GRAB_HALF) or target.invulnerability_remaining > 0.0 or not target.controls_enabled:
		_impact(global_position + locked * 63.0)
		_recover(true, 1.18)
		return
	held = true
	target.controls_enabled = false
	target.velocity = Vector2.ZERO
	target.pulse_gun.cancel()
	grab_origin = target.global_position
	grab_hold_position = global_position + global_position.direction_to(grab_origin) * REEL_STOP
	_switch(Phase.LIFT, GRAB_LOCK_TIME + GRAB_HIGH_HOLD)
	var socket := grab_visual.grip_point(0, face_right, visual_scale)
	grab_visual.begin_grip(socket, grab_origin, face_right, global_position.y - socket.y)
	_update_frame()

func _move_grab(delta: float) -> void:
	if phase == Phase.LIFT:
		var rise := clampf((span - left - GRAB_LOCK_TIME) / GRAB_HIGH_HOLD, 0.0, 1.0)
		var lift_position := grab_origin.lerp(grab_hold_position, rise)
		var motion := (lift_position - target.global_position).limit_length(175.0 * delta)
		if not _line_clear(global_position, target.global_position) or target.move_and_collide(motion):
			_recover(true, 0.83)
			return
		if left <= 0.0:
			_begin_throw()
		return
	var travel := minf(throw_remaining, THROW_SPEED * delta)
	var move := locked * travel
	var before := target.global_position
	var blocked := not _in_arena(before + move)
	if not blocked:
		blocked = target.move_and_collide(move) != null
	throw_remaining -= travel
	if blocked or left <= 0.0 or throw_remaining <= 0.0:
		_land_throw(blocked)
	else:
		var feet := target.global_position
		var air_ratio := 1.0 - pow(_progress(), 1.5)
		grab_visual.show_flight(feet + throw_offset * air_ratio, feet, feet - before, delta, air_ratio)

func _begin_throw() -> void:
	var ground := target.global_position
	var first_step := locked * (THROW_SPEED / float(Engine.physics_ticks_per_second))
	var contact := KinematicCollision2D.new()
	if not _in_arena(ground + first_step) or (target.test_move(target.global_transform, first_step, contact) and contact.get_travel().length() <= 0.15):
		_recover(true, 0.83)
		return
	# Start from exactly the last visible held position; decay only its visual
	# offset. Neither the held height nor the new claw art moves the real feet.
	var release_at := grab_visual.grip_point(1, face_right, visual_scale)
	throw_offset = release_at - ground
	throw_remaining = THROW_DISTANCE
	grab_visual.begin_flight(release_at, ground, locked)
	_switch(Phase.THROW, THROW_DURATION)
	_update_frame()

func _land_throw(blocked: bool) -> void:
	var landing := target.global_position
	_release_grab()
	# A collision stops this implementation rather than making a wall slide.
	# The last valid flight direction therefore stays active on early contact.
	grab_visual.land(landing, blocked)
	throw_landed.emit(grab_visual.last_motion)
	if combat_debug:
		print("[Boss throw] landed=%s dir=%s row=%d stop=%s" % [landing, grab_visual.last_motion, grab_visual.direction_row, blocked])
	_apply_feedback_hit(1)
	_recover(false, THROW_RECOVERY)

func _release_grab() -> void:
	if held:
		slam_grace = SLAM_RELEASE_GRACE
	if held and is_instance_valid(target) and not target.is_dead:
		target.controls_enabled = true
		target.velocity = Vector2.ZERO
	held = false
	if is_instance_valid(grab_visual):
		grab_visual.release_carried()

func _impact(at: Vector2) -> void:
	if _line_clear(global_position, at):
		impact_at = at
		impact_left = 0.24

func cancel_actions() -> void:
	holding_fatal_feedback = false
	_release_tether()
	_release_grab()
	if is_instance_valid(grab_visual):
		grab_visual.clear()
	impact_left = 0.0
	route.clear()
	peek_hits.clear()
	peek_route.clear()
	peek_response = PeekResponse.NONE
	peek_needs_flank = false
	peek_exit_index = 0
	web_followup = false
	sidestep_goal = Vector2.INF
	web_result = "未发射"
	reel_end = "无"
	drawn_pull = 0.0
	if is_instance_valid(sweep_visual):
		sweep_visual.clear()
	sweep_hitstop = 0.0
	pressure_left = 0.0
	pressure_lights.hide()
	if is_instance_valid(clearance):
		clearance.reset()
	clearance_pending = false
	clearance_used = false
	leftover_silk.clear()
	if is_instance_valid(target):
		target.boss_web_speed_factor = 1.0
	slam_impact.clear()
	if is_instance_valid(ground_visual):
		ground_visual.warning = false
		ground_visual.queue_redraw()
	action_frame = 0
	action_left = 0.0

func take_pulse_hit(amount: int, shooter: Node2D) -> void:
	if shooter == target and amount > 0 and phase not in [Phase.ASSEMBLE, Phase.OFFLINE]:
		_observe_peek()
	apply_damage(amount)

func apply_damage(amount: int) -> void:
	if phase in [Phase.ASSEMBLE, Phase.OFFLINE] or amount <= 0:
		return
	var was_enraged := _is_enraged()
	health = maxi(0, health - amount)
	if not was_enraged and _is_enraged():
		rage_flash = RAGE_FLASH_TIME
		if not clearance_used:
			clearance_pending = true
		if combat_debug:
			print("[Boss rage] hp=%d pace=%.2f (next attack)" % [health, RAGE_ATTACK_PACE])
	hit_flash = 0.11
	if health == 0:
		cancel_actions()
		_switch(Phase.OFFLINE, 0.0)
		set_deferred("collision_layer", 0)
		chassis.set_deferred("disabled", true)
		armor.set_deferred("collision_layer", 0)
		metal.set_deferred("collision_layer", 0)
		defeated.emit()

func get_combat_state() -> Dictionary:
	return {"alive": phase not in [Phase.ASSEMBLE, Phase.OFFLINE]}

func _exit_tree() -> void:
	cancel_actions()

func _update_frame() -> void:
	if phase == Phase.CLEARANCE:
		body_sprite.texture = clearance.pose_texture()
		var profile := 11 if clearance.clock >= clearance.time_to_finisher and clearance.pose_index() in [3, 4] else 2
		_align_sprite(profile, clearance.foot())
		return
	if phase == Phase.LIFT or phase == Phase.THROW:
		var index := 0 if span - left < GRAB_LOCK_TIME else 1
		if phase == Phase.THROW:
			index = 2 if span - left < GRAB_RELEASE_POSE_TIME else 3
		body_sprite.texture = grab_visual.boss_frames[index]
		_align_sprite(2, grab_visual.get_foot(face_right))
		grab_visual.show_jaw(index, face_right, visual_scale, body_sprite.modulate)
		if phase == Phase.LIFT:
			var socket := grab_visual.grip_point(index, face_right, visual_scale)
			grab_visual.show_gripped(socket, target.global_position, face_right, global_position.y - socket.y)
		return
	if phase == Phase.REEL and reel_grab_warning:
		_set_pose(7 if reel_grab_elapsed > 0.06 else 6)
		return
	if phase == Phase.SLAM:
		body_sprite.texture = actions["slam"][action_frame]
		var profile := 11 if action_frame in [4, 5, 6] else 2
		_align_sprite(profile, slam_anchor if face_right else slam_flip_anchor)
		return
	if phase == Phase.SWEEP:
		body_sprite.texture = actions["wide_sweep"][action_frame]
		_align_sprite(2, claw_anchor if face_right else claw_flipped_anchor)
		return
	if phase == Phase.FLANK or phase == Phase.PINCH:
		var action := "flank_step" if phase == Phase.FLANK else "low_pinch"
		body_sprite.texture = actions[action][action_frame]
		_align_sprite(2)
		return
	var key := "neutral"
	match phase:
		Phase.ASSEMBLE: key = "assembly"
		Phase.STALK: key = "walk" if velocity.length() > 10.0 else "neutral"
		Phase.WEB_SHOT: key = "web_shot"
		Phase.REEL: key = "reel"
		Phase.GRAB_WARN: key = "grab_warn"
		Phase.RECOVER:
			if miss_pose:
				key = "miss"
			elif web_followup:
				key = "web_recover"
		Phase.OFFLINE: key = "miss"
	var frames: Array = POSE[key]
	var i := int(_progress() * frames.size())
	if key == "walk":
		i = int(walk_cycle)
	elif phase == Phase.OFFLINE:
		i = 2
	_set_pose(frames[mini(i, frames.size() - 1)])

func _draw() -> void:
	if shadow_texture != null:
		# The alpha bounds are 64 x 22 in a 96 x 44 frame.
		var size := shadow_texture.get_size() * 0.875
		draw_texture_rect(shadow_texture, Rect2(-size * 0.5, size), false)
	if phase == Phase.REEL and reel_grab_warning:
		_draw_sector(global_position, REEL_GRAB_REACH, GRAB_HALF, CAUTION, clampf(reel_grab_elapsed / REEL_GRAB_WINDUP, 0.0, 1.0))
	elif phase == Phase.GRAB_WARN:
		_draw_sector(global_position, GRAB_REACH, GRAB_HALF, CAUTION, _progress())
	elif phase == Phase.PINCH and action_frame == 1 and _line_clear(global_position, _pinch_mouth(locked)):
		_draw_sector(_pinch_mouth(locked), PINCH_REACH, PINCH_HALF, Color("ef8360"), 1.0 - action_left / PINCH_TIME[1], true)
	elif phase == Phase.SWEEP and action_frame < sweep_start_index:
		_draw_sweep_warning()
	if web_active:
		var tip := to_local(web_tip)
		draw_line(tip - web_direction * 18.0, tip, SILK, 2.0)
		draw_circle(tip, 4.0, Color(0.80, 0.79, 0.64))
	if bound and is_instance_valid(target):
		var end := to_local(_reel_binding_point())
		var sag := 9 if reel_slack_left > 0.0 else (4 if _progress() < 0.13 else 1)
		var mid := _socket().lerp(end, 0.48) + Vector2(0, sag)
		draw_polyline(PackedVector2Array([_socket(), mid, end]), Color(0.24,0.24,0.16), 4.0)
		draw_polyline(PackedVector2Array([_socket(), mid, end]), SILK, 2.0)
		draw_arc(end, 13, 0, TAU, 12, Color(SILK,0.72), 1.3)
	if phase == Phase.ASSEMBLE:
		draw_arc(Vector2.ZERO, 19 + 29 * _progress(), 0, TAU, 24, Color(CAUTION, 0.62 * (1.0 - _progress())), 1.8)
	if impact_left > 0:
		var p := to_local(impact_at)
		var age := 1.0 - impact_left / 0.24
		for i in range(7):
			var d := Vector2.from_angle(i * TAU / 7.0 + 0.2)
			draw_line(p + d * (4.0 + age * 14.0), p + d * (9.0 + age * 19.0), Color(CAUTION, 1.0-age), 2.0)
	if phase not in [Phase.ASSEMBLE, Phase.OFFLINE]:
		_draw_health()

func _draw_pressure_lights() -> void:
	var reflection := 1.0 if face_right else -1.0
	var vents := [Vector2(-27, -22), Vector2(22, -22)]
	for i in range(vents.size()):
		if phase == Phase.CLEARANCE and clearance.clock < (0.08 if i == 0 else 0.18):
			continue
		var vent: Vector2 = vents[i]
		var at := Vector2(vent.x * reflection, vent.y) * visual_scale + Vector2(0, armor.position.y)
		var end := at + Vector2(11.0 * reflection, -3.0) * visual_scale
		pressure_lights.draw_line(at, end, Color(0.56, 0.27, 0.09, 0.65), 4.0 * visual_scale)
		pressure_lights.draw_line(at, end, Color("e8a751"), 2.0 * visual_scale)

func _draw_health() -> void:
	const BLOCK_SIZE := Vector2(4, 4)
	const CELL_SPACING := 5.0
	const PHASE_GAP := 4.0
	var width := (MAX_HP - 1) * CELL_SPACING + BLOCK_SIZE.x + PHASE_GAP
	var top_left := Vector2(-width * 0.5, -105.0)
	var lit := RAGE_RED if _is_enraged() else CAUTION
	draw_rect(Rect2((top_left - Vector2(2, 1)) * visual_scale, Vector2(width + 4.0, 6.0) * visual_scale), Color(0.08, 0.06, 0.05, 0.86))
	for i in range(MAX_HP):
		var separation := PHASE_GAP if i >= RAGE_HP else 0.0
		var at := top_left + Vector2(i * CELL_SPACING + separation, 0.0)
		draw_rect(Rect2(at * visual_scale, BLOCK_SIZE * visual_scale), lit if i < health else Color(0.29, 0.21, 0.17))
	if rage_flash > 0.0:
		draw_rect(Rect2((top_left - Vector2(2, 1)) * visual_scale, Vector2(width + 4.0, 6.0) * visual_scale), Color(RAGE_RED, rage_flash / RAGE_FLASH_TIME), false, 1.0)

func _draw_sweep_warning() -> void:
	var step := (SWEEP_HALF * 2.0) / SWEEP_SLICES
	var windup := clampf(sweep_clock / sweep_offsets[sweep_start_index], 0.0, 1.0)
	for i in range(sweep_limits.size()):
		if sweep_limits[i] < 0.1:
			continue
		var a := locked.rotated(-SWEEP_HALF + i * step) * sweep_limits[i]
		var b := locked.rotated(-SWEEP_HALF + (i + 1) * step) * sweep_limits[i]
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, a, b]), Color(0.88, 0.52, 0.19, lerpf(0.10, 0.24, windup)))
		draw_line(a, b, Color(0.98, 0.68, 0.30, lerpf(0.58, 0.94, windup)), 1.5)
		# The bars light in the same order as the mirrored blade, all inside
		# this slice's clipped reach. The plain outer arc shows the full danger.
		var order := i if not face_right else SWEEP_SLICES - 1 - i
		if order % 12 < 7 and float(order) / SWEEP_SLICES <= windup and sweep_limits[i] >= 12.0:
			draw_line(a * 0.83, b * 0.83, Color(1.0, 0.77, 0.39, 0.94), 3.0)

func _draw_debug_shapes() -> void:
	if not combat_debug or chassis.disabled:
		return
	_draw_debug_capsule(Vector2.ZERO, _chassis_half(), Color.CYAN)
	_draw_debug_capsule(armor.position, Vector2(43.5, 25.0) * visual_scale, Color.PALE_GREEN)
	for piece in [metal_shape, metal_mount]:
		var outline: PackedVector2Array = piece.shape.points
		outline.append(outline[0])
		debug_shapes.draw_polyline(outline, Color.ORANGE, 1.3)
	var waypoints := peek_route if not peek_route.is_empty() else route
	if not waypoints.is_empty():
		var path := PackedVector2Array([Vector2.ZERO])
		for point in waypoints:
			path.append(to_local(point))
		debug_shapes.draw_polyline(path, Color(1.0, 0.85, 0.36, 0.68), 1.3)

func _draw_debug_capsule(at: Vector2, half: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for side in range(2):
		var centre := at + Vector2((half.x - half.y) * (1 if side == 0 else -1), 0)
		for i in range(13):
			var angle := (-0.5 + side + float(i) / 12.0) * PI
			points.append(centre + Vector2.from_angle(angle) * half.y)
	points.append(points[0])
	debug_shapes.draw_polyline(points, color, 1.2)

func _draw_sector(origin: Vector2, distance: float, half: float, tint: Color, progress: float, pinch_mark := false) -> void:
	var start := to_local(origin)
	var points := PackedVector2Array()
	for i in range(33):
		var direction := locked.rotated(lerpf(-half, half, float(i) / 32.0))
		var end := origin + direction * distance
		var hit := _world_ray(origin, end)
		points.append(to_local(hit.get("position", end)))
		if i > 0 and not is_zero_approx((points[i - 1] - start).cross(points[i] - start)):
			draw_colored_polygon(PackedVector2Array([start, points[i - 1], points[i]]), Color(tint, 0.13 + 0.20 * progress))
	if pinch_mark:
		# Two closing jaw marks identify the short attack even without color.
		draw_polyline(points.slice(0, 14), Color(tint, 0.95), 2.0)
		draw_polyline(points.slice(19), Color(tint, 0.95), 2.0)
		for endpoint in [points[13], points[19]]:
			draw_line(endpoint.lerp(start, 0.24), endpoint, Color(tint, 0.95), 2.0)
	else:
		draw_polyline(points, Color(tint, 0.88), 2.0)
	draw_line(start, points[0], Color(tint, 0.74), 1.0)
	draw_line(start, points[-1], Color(tint, 0.74), 1.0)
