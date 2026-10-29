extends Node2D
## Presentation only: attack timings and hit rectangle belong to the shared cleaner.
@export var animation_sheet: Texture2D = preload("res://tests/manual/b_combat/art/cleaner/side_animation.png")
const P = preload("res://scenes/weapons/combat_parameters.gd")
var enemy: CharacterBody2D
var pieces: Array[AtlasTexture] = []
const WALK_CYCLE := [0, 1, 2, 3, 2, 1]
var eye_anchors: Array[Vector2] = []
var stride := 0.0
var walked_this_tick := false
var previous := Vector2.ZERO
var frame_scale := 1.0
var face_left := false

func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	process_physics_priority = 11
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	previous = enemy.position
	var source := animation_sheet.get_image()
	var cell := source.get_size() / 4
	for i in range(16):
		var section := source.get_region(Rect2i(Vector2i(i % 4, i / 4) * cell, cell))
		section = preload("res://tests/manual/b_combat/sprite_frame_cleanup.gd").clean_frame(section)
		var tex := AtlasTexture.new()
		tex.atlas = ImageTexture.create_from_image(section)
		tex.region = Rect2(section.get_used_rect())
		pieces.append(tex)
		# Register the body by its red eye, not the changing silhouette of stepping feet.
		var center := Vector2.ZERO
		var count := 0
		for y in range(section.get_height()):
			for x in range(section.get_width()):
				var color := section.get_pixel(x,y)
				if color.a > 0.5 and color.r > 0.6 and color.r > color.g * 2.0 and color.r > color.b * 2.0:
					center += Vector2(x,y)
					count += 1
		eye_anchors.append(center / count - tex.region.position if count > 0 else tex.region.size/2)

	var largest := 1.0
	for piece in pieces:
		largest = maxf(largest, piece.get_width())
	frame_scale = 60.0 / largest
	var height := 0.0
	for piece in pieces:
		height = maxf(height, piece.get_height()*frame_scale)
	var health := enemy.get_node("Health") as ProgressBar
	health.offset_top = 9.0-height-17.0
	health.offset_bottom = health.offset_top+6.0
	health.z_index = 10
	enemy.get_node("Facing/Body").hide()
	# Shared code can toggle visibility; transparent self modulation keeps its old fill hidden.
	enemy.get_node("Facing/AttackZone").self_modulate.a = 0.0

func _physics_process(_delta: float) -> void:
	var distance := enemy.position.distance_to(previous)
	previous = enemy.position
	walked_this_tick = distance > 0.01 and distance < 30.0
	if walked_this_tick:
		stride = fmod(stride + distance / 9.0, float(WALK_CYCLE.size()))
	else:
		stride = 0.0
	rotation = 0.0
	var direction := Vector2.from_angle(enemy.get_node("Facing").rotation)
	if absf(direction.x) > 0.3:
		face_left = direction.x < 0
	modulate = enemy.get_node("Facing").modulate
	queue_redraw()

func _draw() -> void:
	if pieces.is_empty():
		return
	var warning: bool = enemy.state == enemy.State.WARNING
	var attack: bool = enemy.state == enemy.State.ATTACK
	var recovery: bool = enemy.state == enemy.State.RECOVERY
	var dead: bool = enemy.state == enemy.State.DEAD
	var charge := clampf(1.0 - enemy.remaining / P.CLEANER_WARNING, 0, 1) if warning else 0.0
	var strike := sin(clampf(1.0-enemy.remaining/P.CLEANER_ACTIVE, 0, 1)*PI) if attack else 0.0
	# Telegraph matches the actual 44 x 44 hit rectangle at x=12..56.
	if warning or attack:
		draw_set_transform(Vector2.ZERO, enemy.get_node("Facing").rotation)
		var color := Color(1, 0.22, 0.12, 0.2 + charge*0.25)
		draw_rect(Rect2(12,-22,44,44), color)
		draw_rect(Rect2(12,-22,44,44), Color(1,0.35,0.18,0.85), false, 1.0)
		if warning:
			draw_line(Vector2(12+charge*44,-22),Vector2(12+charge*44,22),Color(1,0.65,0.3,0.9),2)
			for y in [-18.0, 18.0]:
				draw_line(Vector2(18,y),Vector2(24,y- signf(y)*4),Color(1,0.6,0.3),1)
		else:
			for y in [-14.0,0.0,14.0]:
				draw_line(Vector2(17,y),Vector2(35+strike*18,y*0.7),Color(1,0.8,0.55,0.9),2)
	var walking: bool = walked_this_tick and enemy.state in [enemy.State.PATROL, enemy.State.CHASE]
	var index := 15
	if walking:
		index = WALK_CYCLE[int(stride)]
	elif warning:
		index = 4 + mini(3, int(charge*4))
	elif attack:
		index = 8 + mini(3, int(clampf(1.0-enemy.remaining/P.CLEANER_ACTIVE,0,1)*4))
	elif recovery:
		index = 12 + mini(3, int(clampf(1.0-enemy.remaining/P.CLEANER_RECOVERY,0,1)*4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if face_left else 1, 0.75 if dead else 1.0))
	var size := pieces[index].get_size() * frame_scale
	var origin := Vector2(-size.x/2, 9-size.y)
	if walking:
		var base_size := pieces[15].get_size()*frame_scale
		var reference_eye := Vector2(-base_size.x/2,9-base_size.y)+eye_anchors[15]*frame_scale
		origin = reference_eye-eye_anchors[index]*frame_scale
		origin.y -= sin(stride*TAU/3.0)*0.5
	draw_texture_rect(pieces[index],Rect2(origin,size),false)
	draw_set_transform(Vector2.ZERO)
