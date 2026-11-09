extends "res://tests/manual/b_combat/xiaoyi_aim_visual.gd"
## Shared eight-pose legs for the graybox and abdomen; right-up gait is unchanged.
const WALK_SHEET = preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_diagonal_walk_v2.png")
const SIDE_WALK_SHEET = preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_side_walk_v1.png")
const VERTICAL_WALK_SHEET = preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_vertical_walk_v1.png")
const DIAGONAL_ROWS := [1, 3, 7]
const HIP_RATIO := 0.70
const CYCLE_DISTANCE := {0: 80.0, 1: 64.0, 2: 80.0, 3: 104.0, 4: 80.0, 6: 80.0, 7: 64.0}
var diagonal_legs: Dictionary = {}
var upper_bodies: Dictionary = {}
var leg_scales: Dictionary = {}
var leg_offsets: Dictionary = {}
var leg_sprite: Sprite2D

func _ready() -> void:
	super._ready()
	_load_diagonal_legs()
	leg_sprite = Sprite2D.new()
	leg_sprite.centered = false
	leg_sprite.z_index = 1
	add_child(leg_sprite)
	_show_frame()

func _load_diagonal_legs() -> void:
	# Use an imported resource so the sheet is also included in exports.
	_load_leg_sheet(WALK_SHEET.get_image(), DIAGONAL_ROWS)
	_load_leg_sheet(SIDE_WALK_SHEET.get_image(), [2, 6])
	_load_leg_sheet(VERTICAL_WALK_SHEET.get_image(), [0, 4])

func _load_leg_sheet(source: Image, directions: Array) -> void:
	for row_index in range(directions.size()):
		var direction: int = directions[row_index]
		var original: AtlasTexture = body_frames[direction*4]
		var upper := AtlasTexture.new()
		upper.atlas = original.atlas
		var cut := floorf(original.region.size.y*HIP_RATIO)
		upper.region = Rect2(original.region.position, Vector2(original.region.size.x, cut))
		upper_bodies[direction] = upper
		var bank: Array[AtlasTexture] = []
		var offsets: Array[Vector2] = []
		var reference := FRAME_CLEANUP.clean_frame(source.get_region(_sheet_cell(source, row_index, 0, directions.size())))
		var bounds := reference.get_used_rect()
		var hip_y := bounds.position.y + roundi(bounds.size.y*HIP_RATIO)
		var scale_factor := original.region.size.y*body_scale / bounds.size.y
		leg_scales[direction] = scale_factor
		for column in range(8):
			var pixels := FRAME_CLEANUP.clean_frame(source.get_region(_sheet_cell(source, row_index, column, directions.size())))
			var cell := pixels.get_size()
			var frame_bounds := pixels.get_region(Rect2i(0,0,cell.x,hip_y)).get_used_rect()
			var tex := AtlasTexture.new()
			tex.atlas = ImageTexture.create_from_image(pixels)
			# A fixed hip cut and scale keep the pelvis steady across all eight poses.
			tex.region = Rect2(0,hip_y,cell.x,cell.y-hip_y)
			bank.append(tex)
			offsets.append(Vector2(-(frame_bounds.position.x+frame_bounds.size.x*0.5)*scale_factor,0))
		diagonal_legs[direction] = bank
		leg_offsets[direction] = offsets

func _sheet_cell(source: Image, row: int, column: int, row_count: int) -> Rect2i:
	var x0 := roundi(float(column)*source.get_width()/8.0)
	var x1 := roundi(float(column+1)*source.get_width()/8.0)
	var y0 := roundi(float(row)*source.get_height()/row_count)
	var y1 := roundi(float(row+1)*source.get_height()/row_count)
	return Rect2i(x0,y0,x1-x0,y1-y0)

func _show_frame() -> void:
	# Keep weight transfer in the same rhythm as each slower walk cycle.
	if facing_row in [0, 2, 3, 4, 6]:
		var phase := walk_distance / float(CYCLE_DISTANCE[facing_row]) * TAU
		gait_offset = Vector2(sin(phase)*0.6, -absf(sin(phase))*1.8)*gait_strength
	var original_column := current_column
	var custom := diagonal_legs.has(facing_row) and _uses_rig() and not _inspecting()
	# Keep the existing torso and head perfectly stable while feet articulate.
	if custom:
		current_column = 0
	super._show_frame()
	current_column = original_column
	if leg_sprite == null:
		return
	leg_sprite.visible = custom and walk_distance > 0.0 and not player.is_dead and player.controls_enabled
	if not leg_sprite.visible:
		return
	var index := int(walk_distance / (float(CYCLE_DISTANCE[facing_row])/8.0)) % 8
	# Right-facing views share their approved left-facing leg cycles, reflected only
	# below the hips. Never mirror the body, head, or anatomical weapon arms.
	var source_direction: int = {6: 2, 7: 1}.get(facing_row, facing_row)
	# Front/back legs are symmetric: reflect the first half-cycle for the
	# opposite foot, rather than repeat the generated leading-foot poses.
	var mirror_legs := facing_row in [6, 7] or (facing_row in [0, 4] and index >= 4)
	if facing_row in [0, 4]:
		index %= 4
	var original: AtlasTexture = body_frames[facing_row*4]
	var top_left := sprite.position - original.get_size()*body_scale*0.5
	sprite.texture = upper_bodies[facing_row]
	sprite.position = top_left + sprite.texture.get_size()*body_scale*0.5
	leg_sprite.texture = diagonal_legs[source_direction][index]
	leg_sprite.scale = Vector2.ONE*float(leg_scales[source_direction])
	leg_sprite.position = Vector2(gait_offset.x, top_left.y+sprite.texture.get_height()*body_scale) + leg_offsets[source_direction][index]
	if mirror_legs:
		leg_sprite.scale.x *= -1.0
		leg_sprite.position.x = gait_offset.x - leg_offsets[source_direction][index].x
	if gait_material != null:
		gait_material.set_shader_parameter("strength",0.0)


func update_animation(delta: float, displacement: Vector2, stopped: bool) -> void:
	if player.has_method("gait_displacement"):
		displacement = player.gait_displacement(displacement)
	super.update_animation(delta, displacement, stopped)

func _draw() -> void:
	super._draw()
	if player == null or not player.has_method("gait_displacement"):
		return
	if player.web_slow_remaining > 0.0 and not player.is_dead:
		var silk := Color(0.85,0.97,0.91,0.8)
		draw_ellipse_web(silk)
	if not player.sprint_active or player.is_dead or not player.controls_enabled or player.sprint_motion.length_squared() < 0.01:
		return
	var heading: Vector2 = player.sprint_motion.normalized()
	var side := heading.orthogonal()
	var pulse := sin(walk_distance/16.0*PI)*1.5
	for lane in [-1,0,1]:
		var tip: Vector2 = Vector2(0,4) - heading*(10.0+abs(lane)*3.0) + side*lane*9.0
		var length := 8.0+pulse+(3.0 if lane == 0 else 0.0)
		draw_line(tip-heading*length,tip,Color(0.55,0.92,0.92,0.55),1.2,true)

func draw_ellipse_web(color: Color) -> void:
	for offset in [0.0,5.0]:
		var ring := PackedVector2Array()
		for i in range(17):
			var angle := float(i)/16.0*TAU
			ring.append(Vector2(cos(angle)*17.0, sin(angle)*5.0+offset))
		draw_polyline(ring,color,1.0,true)
	for x in [-9.0,0.0,9.0]:
		draw_line(Vector2(x-3,-6),Vector2(x+3,5),color,1.0,true)

func _uses_rig() -> bool:
	# The same walk cycles also work before story acquisition, using ordinary arms.
	return true
