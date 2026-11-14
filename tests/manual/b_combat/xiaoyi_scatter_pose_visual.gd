extends "res://tests/manual/b_combat/xiaoyi_spark_visual.gd"
## Shared graybox pose: keep the torso and shooting shoulder on the same side.
var scatter_body_row := -1
var scatter_flip := false
var relaxed_walk_arms := false
var relaxed_walk_strength := 0.0
var relaxed_walk_phase := 0.0
const TURN_MARGIN := 0.07
var shoulder_head_material: ShaderMaterial
# Pixel coordinates on the cropped reference body frames, clockwise from down.
# Only the head/neck boundary is authored; the source alpha retains its fine edge.
const HEAD_SIZES := [Vector2(142,200),Vector2(129,212),Vector2(119,208),Vector2(124,216),Vector2(141,209),Vector2(123,210),Vector2(119,203),Vector2(132,216)]
const HEAD_EDGES := [
	[Vector2(0,85),Vector2(17,96),Vector2(27,110),Vector2(42,116),Vector2(60,121),Vector2(80,121),Vector2(100,115),Vector2(116,105),Vector2(125,94),Vector2(142,85)],
	[Vector2(0,85),Vector2(10,100),Vector2(26,111),Vector2(43,117),Vector2(60,119),Vector2(76,114),Vector2(91,107),Vector2(106,97),Vector2(119,85),Vector2(129,83)],
	[Vector2(0,78),Vector2(8,95),Vector2(25,108),Vector2(43,114),Vector2(60,113),Vector2(75,111),Vector2(91,105),Vector2(107,96),Vector2(119,78)],
	[Vector2(0,70),Vector2(12,91),Vector2(28,104),Vector2(46,111),Vector2(65,110),Vector2(87,105),Vector2(107,93),Vector2(124,66)],
	[Vector2(0,78),Vector2(14,92),Vector2(28,102),Vector2(43,109),Vector2(70,112),Vector2(98,108),Vector2(113,100),Vector2(129,91),Vector2(141,76)],
	[Vector2(0,78),Vector2(14,91),Vector2(29,100),Vector2(44,105),Vector2(63,109),Vector2(82,111),Vector2(101,104),Vector2(115,91),Vector2(123,77)],
	[Vector2(0,73),Vector2(12,88),Vector2(27,99),Vector2(45,104),Vector2(64,110),Vector2(82,109),Vector2(99,99),Vector2(113,83),Vector2(119,72)],
	[Vector2(0,82),Vector2(16,99),Vector2(34,108),Vector2(53,115),Vector2(72,119),Vector2(88,114),Vector2(107,105),Vector2(122,91),Vector2(132,75)]
]

func _load_rig() -> void:
	super._load_rig()
	for i in range(body_frames.size()):
		# The shader now selects the head silhouette, not a fixed-height rectangle.
		head_frames[i].region = body_frames[i].region

func _ready() -> void:
	super._ready()
	# Ordinary arms < charge light < head; explicit foreground-arm poses stay above.
	player.pulse_gun.charge_glow.z_index = 5
	head_occluder.z_index = 6
	shoulder_head_material = ShaderMaterial.new()
	shoulder_head_material.shader = preload("res://tests/manual/b_combat/shoulder_head_occlusion.gdshader")
	head_occluder.material = shoulder_head_material
	_show_frame()

func _show_frame() -> void:
	super._show_frame()
	if relaxed_walk_arms and head_occluder != null and player.attack_mode == 2 and not _inspecting():
		# Replace the old vertical bounce; move the complete rig together, not its shadow.
		var bob := -absf(sin(relaxed_walk_phase))*0.5*relaxed_walk_strength
		var correction := Vector2(0,bob-gait_offset.y)
		gait_offset += correction
		sprite.position += correction
		head_occluder.position += correction
		if leg_sprite != null:
			leg_sprite.position += correction
		for pivot in arm_nodes:
			pivot.position += correction
	if shoulder_head_material != null:
		var points := PackedVector2Array()
		for point in HEAD_EDGES[facing_row]:
			points.append(point/HEAD_SIZES[facing_row])
		var count := points.size()
		points.resize(12)
		shoulder_head_material.set_shader_parameter("lower_edge",points)
		shoulder_head_material.set_shader_parameter("edge_count",count)
		shoulder_head_material.set_shader_parameter("frame_size",head_occluder.texture.get_size())

# Authored chest-level holds, ordered down through down-right. Far-side holds
# sit lower so a horizontal barrel cannot emerge from behind the face.
const SCATTER_SHOULDERS := [Vector2(-8.5,-19),Vector2(-7,-15),Vector2(-5,-14),Vector2(8,-14),Vector2(8.5,-17),Vector2(2,-15),Vector2(-2,-16),Vector2(-9,-20)]
const SCATTER_LENGTHS := [27.0,25.0,24.0,23.0,24.0,25.0,27.0,27.0]
# Left side-on rest is seated on the visible yellow shoulder cap; mirroring this
# same anchor gives the right side-on shotgun rest while the laser is active.
const IDLE_SHOULDERS := [Vector2(8,-19),Vector2(8,-18),Vector2(6,-19),Vector2(-7.5,-18),Vector2(-8.5,-18),Vector2(-2,-19),Vector2(6,-19),Vector2(8.5,-19)]
# Screen-space projection of a relaxed rearward arm, not a universal down angle.
# Preserve the approved down-left/left poses and mirror the rearward lean on right.
const IDLE_ANGLES := [52.0,65.0,58.0,65.0,108.0,122.0,122.0,115.0]
# Front-facing idle arms cover the torso's shoulder cap in either weapon mode.
const IDLE_DEPTH := [2,2,2,2,2,0,0,0]
# Second-room carry poses: lowered barrels, with a small forward lean in profile.
# Left-arm values; the right arm uses the opposite view, mirrored at the shoulder.
const WALK_CARRY_ANGLES := [74.0,96.0,108.0,106.0,102.0,110.0,116.0,106.0]
const WALK_CARRY_LENGTHS := [22.0,22.0,22.0,21.5,21.5,20.0,20.0,20.5]

func shoulder(side: int) -> Vector2:
	var point := _pose_shoulder(side)
	return point+Vector2(-1 if side == 0 else 1,-2) if facing_row == 4 else point

func _pose_shoulder(side: int) -> Vector2:
	if player != null and player.attack_mode == 2 and not _inspecting():
		var row := facing_row if side == 0 else posmod(-facing_row,8)
		var point: Vector2 = IDLE_SHOULDERS[row]
		# Carry over the approved side-on socket rather than the old generic shoulder.
		if row == 2:
			point = Vector2(1,-17)
		if side == 1:
			point.x = -point.x
		return point+gait_offset
	if player != null and player.attack_mode == 1 and side == 0 and facing_row == 1:
		# Match the original body frame's yellow socket (about 99,118 in 129x212).
		return Vector2(7.5,-18)+gait_offset
	# Mirror the approved right-facing shotgun hold onto the left-facing laser.
	if player != null and player.attack_mode == 1 and side == 0 and facing_row == 2:
		return Vector2(1,-15)+gait_offset
	# Up-left laser: seat the arm root over the torso's yellow shoulder joint.
	if player != null and player.attack_mode == 1 and side == 0 and facing_row == 3:
		return Vector2(-5,-18)+gait_offset
	if player != null and player.attack_mode == 1 and side == 1 and _installed(1):
		var mirrored: Vector2 = IDLE_SHOULDERS[posmod(-facing_row,8)]
		if facing_row == 6:
			mirrored.y += 2.0
		return Vector2(-mirrored.x,mirrored.y)+gait_offset
	if player != null and player.attack_mode == 3:
		if side == 1:
			return SCATTER_SHOULDERS[facing_row]+gait_offset
		if facing_row == 2:
			return IDLE_SHOULDERS[facing_row]+Vector2(-1,2)+gait_offset
		return IDLE_SHOULDERS[facing_row]+gait_offset
	return super.shoulder(side)

func get_muzzle_world_position(mode: int) -> Vector2:
	if mode != 3:
		return super.get_muzzle_world_position(mode)
	_refresh_arms()
	return player.global_position+shoulder(1)+aim_vector(mode)*(SCATTER_LENGTHS[facing_row]*0.94-3.0)

func update_animation(delta: float, displacement: Vector2, stopped: bool) -> void:
	if relaxed_walk_arms:
		var carrying: bool = player.attack_mode == 2 and not _inspecting() and not player.is_dead and player.controls_enabled
		var moving: bool = carrying and not stopped and displacement.length_squared() > 0.0001
		relaxed_walk_strength = move_toward(relaxed_walk_strength,1.0 if moving else 0.0,delta/(0.1 if moving else 0.15))
		if moving:
			var travel := displacement
			if player.has_method("gait_displacement"):
				travel = player.gait_displacement(displacement)
			var row := posmod(roundi((displacement.angle()-PI/2.0)/(PI/4.0)),8)
			var cycle: float = CYCLE_DISTANCE.get(row,STRIDE_PIXELS*4.0)
			relaxed_walk_phase = (walk_distance+travel.length())/cycle*TAU
		elif not carrying:
			relaxed_walk_strength = 0.0
	super.update_animation(delta,displacement,stopped)
	if player.attack_mode != 3 or stopped:
		scatter_body_row = -1
		return
	var aim := aim_vector(3)
	var nearest := posmod(roundi((aim.angle()-PI/2)/(PI/4)),8)
	if scatter_body_row < 0:
		scatter_body_row = nearest
	else:
		var current_angle := PI/2+scatter_body_row*PI/4
		if absf(angle_difference(current_angle,aim.angle())) > PI/8+TURN_MARGIN:
			scatter_body_row = nearest
	# Do not traverse unrelated body facings while the right arm already aims back.
	facing_row = scatter_body_row
	target_row = facing_row
	turn_elapsed = 0.0
	_show_frame()

func _refresh_arms() -> void:
	super._refresh_arms()
	if arm_nodes.is_empty(): return
	for pivot in arm_nodes:
		pivot.get_node("Art").flip_v = false
		# Back view: arms cover torso (1), while the head occluder (3) covers arms.
		if facing_row == 4 and player.attack_mode in [1,3]:
			pivot.z_index = 2
	if player.attack_mode == 2 and not _inspecting():
		_refresh_walking_arms()
		return
	if player.attack_mode == 1 and facing_row == 2:
		arm_nodes[0].z_index = 7
		arm_nodes[0].get_node("Art").flip_v = true
	if player.attack_mode == 1 and facing_row == 1:
		arm_nodes[0].z_index = 2 # Torso (1) < arm (2) < head (6).
	if player.attack_mode == 1 and _installed(1):
		# Mirror the approved left-arm rest onto the anatomical right arm.
		var row := posmod(-facing_row,8)
		var resting := arm_nodes[1]
		resting.rotation = PI-deg_to_rad(IDLE_ANGLES[row])-sin(walk_distance/32*PI)*0.035*gait_strength
		resting.z_index = IDLE_DEPTH[row]
		resting.get_node("Art").scale.x *= LASER_ARM_LENGTH*0.84/ARM_LENGTH
		return
	if player.attack_mode != 3: return
	# Mirroring across the arm axis keeps its upper surface upright when aiming left.
	var horizontal := aim_vector(3).x
	if absf(horizontal) > 0.12:
		scatter_flip = horizontal < 0.0
	arm_nodes[1].get_node("Art").flip_v = scatter_flip
	var weapon := arm_nodes[1].get_node("Art") as Sprite2D
	weapon.scale.x *= SCATTER_LENGTHS[facing_row]/ARM_LENGTH
	# The left-facing root sits inside the torso, which covers its yellow pivot.
	arm_nodes[1].z_index = 0 if facing_row in [1,2,3] else 2
	# User-approved right-facing exception: shotgun may overlap the head.
	if facing_row == 6:
		arm_nodes[1].z_index = 7
	# Keep the installed but inactive laser close to the torso, clear of the shotgun.
	var idle := arm_nodes[0]
	idle.rotation = deg_to_rad(IDLE_ANGLES[facing_row])+sin(walk_distance/32*PI)*0.035*gait_strength
	# Seat the root under the existing shoulder cap rather than floating outside it.
	idle.z_index = IDLE_DEPTH[facing_row]
	# Foreshorten the resting module so its barrel does not cover the active grip.
	idle.get_node("Art").scale.x *= 0.84

func _refresh_walking_arms() -> void:
	# Match the approved leg cycle, including sprint's distance compensation.
	var cycle: float = CYCLE_DISTANCE.get(facing_row,STRIDE_PIXELS*4.0)
	var swing := sin(walk_distance/cycle*TAU)*deg_to_rad(4.0)*gait_strength
	for side in range(2):
		var row := facing_row if side == 0 else posmod(-facing_row,8)
		var pivot := arm_nodes[side]
		var rest := deg_to_rad(IDLE_ANGLES[row])
		pivot.rotation = rest+swing if side == 0 else PI-rest-swing
		# Side-on walking: mirror the near arm across the shoulder's vertical axis
		# so it leans into travel, retaining the same swing range and shoulder anchor.
		if (facing_row in [2,3] and side == 0) or (facing_row in [5,6] and side == 1):
			pivot.rotation = PI-pivot.rotation
		if relaxed_walk_arms:
			# Slightly delayed shoulders follow the step; modules have different weight.
			var phase := sin(relaxed_walk_phase-0.12) * (1.0 if side == 0 else -1.0)
			var carry := deg_to_rad(WALK_CARRY_ANGLES[row])
			var base := carry if side == 0 else PI-carry
			# Positive rotation leans left from a lowered arm; negative leans right.
			var forward_sign := 1.0 if facing_row in [1,2,3] else -1.0
			if facing_row in [0,4]:
				forward_sign = 1.0 if side == 0 else -1.0
			var weight := 0.85+0.15*phase*forward_sign
			var amplitude := 10.0 if side == 0 else 8.0
			pivot.rotation = base+phase*weight*deg_to_rad(amplitude)*relaxed_walk_strength
		pivot.z_index = IDLE_DEPTH[row]
		var art := pivot.get_node("Art") as Sprite2D
		# Compact carrying posture keeps heavy modules clear of knees and each other.
		var length := 21.0 if _installed(side) else 19.0
		if relaxed_walk_arms:
			length = WALK_CARRY_LENGTHS[row] if _installed(side) else 20.0
		art.scale.x = length/art.texture.get_width()
