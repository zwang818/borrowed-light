extends Node2D
## Graybox-only eight-direction animation. Combat and collisions remain shared.

const FRAME_CLEANUP := preload("res://tests/manual/b_combat/sprite_frame_cleanup.gd")
const CORRECTED_ROWS := {1: [5], 3: [6, 7]}
const WALK_FRAMES := [1, 2, 3, 2]
const TURN_STEP_SECONDS := 0.035
const STRIDE_PIXELS := 16.0
# Measured transparent row gutters in the authored 887 x 1774 atlas.
const ROW_EDGES := [0, 213, 428, 644, 867, 1082, 1302, 1516, 1774]
@export var display_height: float = 64.0
var player: CharacterBody2D
var sprite: Sprite2D
var frames: Array[AtlasTexture] = []
var mode_frames: Dictionary = {}
var muzzle_points: Dictionary = {}
var nearest_enemy: Node2D
var arrow_direction := Vector2.ZERO
var facing_row: int = 0
var target_row: int = 0
var walk_distance: float = 0.0
var turn_elapsed: float = 0.0
var previous_position := Vector2.ZERO
var current_column: int = 0
var display_scale: float = 1.0


func _ready() -> void:
	player = get_parent().get_parent() as CharacterBody2D
	process_physics_priority = 1 # Run after the player has moved.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	add_child(sprite)
	muzzle_points = JSON.parse_string(FileAccess.get_file_as_string("res://tests/manual/b_combat/art/xiaoyi/muzzle_points.json"))
	_load_frames()
	player.get_node("Facing/Body").hide()
	player.get_node("Facing/DirectionIndicator").hide()
	player.get_node("Facing/PulseGun/Barrel").hide()
	previous_position = player.global_position
	_show_frame()


func _load_frames() -> void:
	var largest_height := 1.0
	var modes := {1: "laser", 2: "unarmed", 3: "scatter"}
	for mode in modes:
		var sheet: Texture2D = load("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_%s_8dir.png" % modes[mode])
		var pixels := sheet.get_image()
		var correction: Texture2D
		var corrected_pixels: Image
		if CORRECTED_ROWS.has(mode):
			correction = load("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_%s_handedness.png" % modes[mode])
			corrected_pixels = correction.get_image()
		var bank: Array[AtlasTexture] = []
		for row in range(8):
			var corrected: bool = CORRECTED_ROWS.has(mode) and row in CORRECTED_ROWS[mode]
			var frame_pixels: Image = corrected_pixels if corrected else pixels
			for column in range(4):
				var x0 := roundi(float(column) * sheet.get_width() / 4.0)
				var x1 := roundi(float(column + 1) * sheet.get_width() / 4.0)
				var y0: int = ROW_EDGES[row]
				var y1: int = ROW_EDGES[row + 1]
				var cell := Rect2i(x0, y0, x1 - x0, y1 - y0)
				var clean := FRAME_CLEANUP.clean_frame(frame_pixels.get_region(cell))
				var bounds := clean.get_used_rect()
				var atlas := AtlasTexture.new()
				atlas.atlas = ImageTexture.create_from_image(clean)
				atlas.set_meta("source_path", correction.resource_path if corrected else sheet.resource_path)
				atlas.region = Rect2(Vector2(bounds.position), Vector2(bounds.size))
				atlas.filter_clip = true
				bank.append(atlas)
				largest_height = maxf(largest_height, bounds.size.y)
		mode_frames[mode] = bank
	frames = mode_frames[player.attack_mode]
	display_scale = display_height / largest_height
	sprite.scale = Vector2.ONE * display_scale


func _process(_delta: float) -> void:
	# Render-only updates must never reset the stride between physics ticks.
	global_rotation = 0.0


func _physics_process(delta: float) -> void:
	global_rotation = 0.0
	var displacement := player.global_position - previous_position
	previous_position = player.global_position
	# Respawn / teleport must not advance the stride or turn the body.
	if displacement.length() > maxf(32.0, player.move_speed * delta * 2.0):
		displacement = Vector2.ZERO
		walk_distance = 0.0
	update_animation(delta, displacement, player.is_dead or not player.controls_enabled)
	update_nearest_enemy()
	if player.pulse_gun.has_method("refresh_muzzle_visuals"):
		player.pulse_gun.refresh_muzzle_visuals()
	queue_redraw()


func update_animation(delta: float, displacement: Vector2, stopped: bool) -> void:
	var moving := displacement.length_squared() > 0.0001 and not stopped
	if moving:
		# Rows proceed clockwise on screen: down, down-left, left ... down-right.
		target_row = posmod(roundi((displacement.angle() - PI / 2.0) / (PI / 4.0)), 8)
		walk_distance += displacement.length()
		current_column = WALK_FRAMES[int(walk_distance / STRIDE_PIXELS) % WALK_FRAMES.size()]
	else:
		walk_distance = 0.0
		current_column = 0
	if player.attack_mode != 2 and not stopped:
		target_row = posmod(roundi((player.mouse_facing.angle() - PI / 2.0) / (PI / 4.0)), 8)
	if stopped:
		target_row = facing_row
	turn_elapsed += delta
	while facing_row != target_row and turn_elapsed >= TURN_STEP_SECONDS:
		var difference := posmod(target_row - facing_row + 4, 8) - 4
		facing_row = posmod(facing_row + (1 if difference > 0 else -1), 8)
		turn_elapsed -= TURN_STEP_SECONDS
	if facing_row == target_row:
		turn_elapsed = 0.0
	_show_frame()


func _show_frame() -> void:
	if mode_frames.has(player.attack_mode):
		frames = mode_frames[player.attack_mode]
	if frames.is_empty():
		return
	sprite.texture = frames[facing_row * 4 + current_column]
	# Foot registration prevents generated frame padding from causing sliding.
	sprite.position = Vector2(0, 7.0 - sprite.texture.get_height() * display_scale / 2.0)
	sprite.rotation = 0.0
	sprite.flip_h = false


func _draw() -> void:
	if player == null:
		return
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle) * 12.0, sin(angle) * 4.0 + 6.0))
	draw_colored_polygon(points, Color(0, 0, 0, 0.28))
	if player.is_dead or arrow_direction.is_zero_approx():
		return
	var direction: Vector2 = arrow_direction
	var tip := direction * 26.0
	var side := direction.orthogonal() * 3.0
	draw_polyline(PackedVector2Array([tip - direction * 5.0 + side, tip, tip - direction * 5.0 - side]), Color(0.35, 0.95, 1.0, 0.85), 1.5)


func update_nearest_enemy() -> void:
	nearest_enemy = null
	arrow_direction = Vector2.ZERO
	if player.is_dead:
		return
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("combat_enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy is Node2D or not enemy.has_method("get_combat_state"):
			continue
		if not enemy.get_combat_state().alive:
			continue
		var distance: float = player.global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest_enemy = enemy
	if is_instance_valid(nearest_enemy):
		arrow_direction = player.global_position.direction_to(nearest_enemy.global_position)


func get_muzzle_world_position(mode: int) -> Vector2:
	var key := "laser" if mode == 1 else "scatter"
	var index := facing_row * 4 + current_column
	var point: Array = muzzle_points[key][index]
	var atlas: AtlasTexture = mode_frames[mode][index]
	var local_point := Vector2(float(point[0]), float(point[1])) - atlas.region.position
	local_point -= atlas.region.size / 2.0
	var foot_offset := Vector2(0, 7.0 - atlas.get_height() * display_scale / 2.0)
	# Parent Facing rotates for combat before this visual's next update; use an
	# explicit upright world offset so the muzzle never briefly orbits the body.
	return player.global_position + foot_offset + local_point * display_scale
