extends "res://tests/manual/b_combat/xiaoyi_combat_visual.gd"
## Independent-arm visual shared by the combat graybox and main map.
const BODY_SHEET = preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_body_rig.png")
const ARM_SHEET = preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_arm_rig.png")
var body_frames: Array[AtlasTexture] = []
var arm_textures: Array[AtlasTexture] = []
var arm_nodes: Array[Node2D] = []
var body_scale := 1.0
var head_occluder: Sprite2D
var head_frames: Array[AtlasTexture] = []
const ARM_LENGTH := 27.0
const LASER_ARM_LENGTH := 25.0
const REST_ARM_LENGTH := 21.0
const ARM_THICKNESS := 1.12

func _ready() -> void:
	_load_rig()
	super._ready()
	sprite.z_index = 1
	for i in range(2):
		var pivot := Node2D.new()
		var art := Sprite2D.new()
		art.name = "Art"
		art.centered = false
		pivot.add_child(art)
		add_child(pivot)
		arm_nodes.append(pivot)
	# The head stays in front of a raised arm; rotating the arm must never
	# paint its barrel across the face or the back of the head.
	head_occluder = Sprite2D.new()
	head_occluder.centered = false
	head_occluder.z_index = 3
	add_child(head_occluder)
	_show_frame()

func _load_rig() -> void:
	var source := BODY_SHEET.get_image()
	var maximum := 1.0
	for row in range(8):
		for column in range(4):
			var x0 := roundi(float(column)*source.get_width()/4)
			var x1 := roundi(float(column+1)*source.get_width()/4)
			var y0 := roundi(float(ROW_EDGES[row])*source.get_height()/1774)
			var y1 := roundi(float(ROW_EDGES[row+1])*source.get_height()/1774)
			var tex := _part(source,Rect2i(x0,y0,x1-x0,y1-y0))
			body_frames.append(tex)
			var head := AtlasTexture.new()
			head.atlas = tex.atlas
			head.region = Rect2(tex.region.position, Vector2(tex.region.size.x, floorf(tex.region.size.y*0.56)))
			head_frames.append(head)
			maximum = maxf(maximum,tex.get_height())
	body_scale = display_height/maximum
	source = ARM_SHEET.get_image()
	var cell := Vector2i(source.get_width()/2,source.get_height()/2)
	for i in range(4):
		arm_textures.append(_part(source,Rect2i(Vector2i(i%2,i/2)*cell,cell)))

func _part(source: Image, rect: Rect2i) -> AtlasTexture:
	var pixels := FRAME_CLEANUP.clean_frame(source.get_region(rect))
	var tex := AtlasTexture.new()
	tex.atlas = ImageTexture.create_from_image(pixels)
	tex.region = Rect2(pixels.get_used_rect())
	return tex

func aim_vector(mode: int) -> Vector2:
	if mode == 1 and player.pulse_gun.state == player.pulse_gun.State.FIRING:
		return player.pulse_gun.locked_direction.normalized()
	return player.mouse_facing.normalized() if not player.mouse_facing.is_zero_approx() else Vector2.RIGHT

func shoulder(side: int) -> Vector2:
	var forward := Vector2.from_angle(PI/2+facing_row*PI/4)
	var lateral := forward.rotated(-PI/2) * (1.0 if side == 0 else -1.0)
	return Vector2(lateral.x*8.5-lateral.y*6.0,-18.0+lateral.y*1.5)+gait_offset

func _show_frame() -> void:
	if _inspecting():
		facing_row = 0
		current_column = 0
	super._show_frame()
	if body_frames.is_empty() or sprite == null:
		return
	if _uses_rig():
		sprite.texture = body_frames[facing_row*4+current_column]
		sprite.scale = Vector2.ONE*body_scale
		sprite.position = Vector2(0,7-sprite.texture.get_height()*body_scale/2)+gait_offset
	else:
		sprite.scale = Vector2.ONE*display_scale
	if head_occluder != null:
		head_occluder.visible = _uses_rig()
		head_occluder.texture = head_frames[facing_row*4+current_column]
		head_occluder.scale = sprite.scale
		head_occluder.position = sprite.position - sprite.texture.get_size()*sprite.scale/2
	_refresh_arms()

func _installed(side: int) -> bool:
	return player.has_method("has_arm_module") and player.has_arm_module(side)

func _uses_rig() -> bool:
	return player.attack_mode != 2 or _installed(0) or _installed(1)

func _inspecting() -> bool:
	return player.has_method("has_arm_module") and player.inspection_remaining > 0.0 and player.attack_mode == 2

func _refresh_arms() -> void:
	if arm_nodes.is_empty():
		return
	for side in range(2):
		var pivot := arm_nodes[side]
		pivot.visible = _uses_rig()
		var active: bool = (side == 0 and player.attack_mode == 1) or (side == 1 and player.attack_mode == 3)
		var equipped := active or _installed(side)
		var tex: AtlasTexture = arm_textures[0 if side == 0 else 1] if equipped else arm_textures[2]
		var art := pivot.get_node("Art") as Sprite2D
		art.texture = tex
		var length := ARM_LENGTH if equipped else REST_ARM_LENGTH
		if equipped and side == 0:
			length = LASER_ARM_LENGTH
		var factor := length/tex.get_width()
		# Shorten only the laser's longitudinal axis, retaining its thickness.
		var thickness_length := ARM_LENGTH if equipped else REST_ARM_LENGTH
		art.scale = Vector2(factor, thickness_length/tex.get_width()*ARM_THICKNESS)
		art.position = Vector2(-3,-tex.get_height()*art.scale.y/2)
		pivot.position = shoulder(side)
		# Relaxed arms open slightly away from the torso instead of hanging over the feet.
		var outward := signf(pivot.position.x-gait_offset.x)
		var rest_angle := PI/2-outward*deg_to_rad(30.0)
		pivot.rotation = aim_vector(player.attack_mode).angle() if active else rest_angle + sin(walk_distance/32*PI)*0.12*gait_strength
		art.modulate = Color.WHITE
		if side == 0 and _inspecting():
			var progress: float = 1.0-player.inspection_remaining/player.INSPECTION_DURATION
			var lift := sin(progress*PI)
			pivot.rotation = lerpf(rest_angle, -0.43, lift)
			art.modulate = Color(1.0,1.0+lift*0.35,1.0+lift*0.65)
		pivot.z_index = 0 if pivot.position.y-gait_offset.y < -18.1 else 2

func get_muzzle_world_position(mode: int) -> Vector2:
	_refresh_arms()
	var length := LASER_ARM_LENGTH if mode == 1 else ARM_LENGTH
	return player.global_position+shoulder(0 if mode == 1 else 1)+aim_vector(mode)*(length*0.94-3.0)
