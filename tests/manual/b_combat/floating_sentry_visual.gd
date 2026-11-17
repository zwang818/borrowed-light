extends Node2D
const HEADS = preload("res://tests/manual/b_combat/art/sentry/head_16dir_a.png")
const BASE = preload("res://tests/manual/b_combat/art/sentry/pedestal_a.png")
# Normalized muzzle locations within the generated 4x4 cells, including rear occlusion.
const MUZZLES = [
	Vector2(0.91,0.68),Vector2(0.81,0.73),Vector2(0.70,0.78),Vector2(0.50,0.82),
	Vector2(0.50,0.82),Vector2(0.25,0.78),Vector2(0.15,0.75),Vector2(0.11,0.68),
	Vector2(0.09,0.64),Vector2(0.16,0.44),Vector2(0.24,0.35),Vector2(0.36,0.30),
	Vector2(0.50,0.29),Vector2(0.65,0.30),Vector2(0.77,0.35),Vector2(0.91,0.60)
]
var sentry: Node2D
var head := Sprite2D.new()
var pedestal := Sprite2D.new()
var tray_shadow := Node2D.new()
var aim_angle := 0.0
var recoil := 0.0
var phase := 0.0
var sector := 0

func _ready() -> void:
	sentry = get_parent()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Layered warm shadows anchor the base without a hard black sticker outline.
	add_child(_shadow_ellipse(Vector2(1,1),Vector2(21,5.5),0.10))
	add_child(_shadow_ellipse(Vector2(0,1),Vector2(17,4),0.16))
	pedestal.texture = BASE
	pedestal.scale = Vector2.ONE*68.0/BASE.get_height()
	pedestal.position = Vector2(0,-30)
	add_child(pedestal)
	add_child(tray_shadow)
	tray_shadow.position = Vector2(0,-56)
	tray_shadow.add_child(_shadow_ellipse(Vector2.ZERO,Vector2(10,2.5),0.16))
	tray_shadow.add_child(_shadow_ellipse(Vector2.ZERO,Vector2(7,1.5),0.12))
	head.texture = HEADS
	head.hframes = 4
	head.vframes = 4
	head.scale = Vector2.ONE*44.0/(HEADS.get_width()/4.0)
	add_child(head)
	process_physics_priority = 11
	update_pose()

func _shadow_ellipse(center: Vector2, radii: Vector2, opacity: float) -> Polygon2D:
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		points.append(center+Vector2(cos(i*TAU/32.0),sin(i*TAU/32.0))*radii)
	shadow.polygon = points
	shadow.color = Color(0.13,0.10,0.09,opacity)
	return shadow

func head_origin() -> Vector2:
	return to_global(Vector2(0,-78+sin(phase)*1.2))

func muzzle_origin() -> Vector2:
	return head.to_global((MUZZLES[sector]-Vector2(0.5,0.5))*Vector2(HEADS.get_width()/4.0,HEADS.get_height()/4.0))

func _physics_process(delta: float) -> void:
	if sentry.state != sentry.State.DEAD:
		phase += delta*2.6
		if sentry.can_detect() and sentry.state != sentry.State.BURST:
			var desired: float = (sentry.target.global_position-head_origin()).angle()
			aim_angle = rotate_toward(aim_angle,desired,delta*5.0)
		elif sentry.state == sentry.State.BURST:
			aim_angle = sentry.locked_direction.angle()
	recoil = move_toward(recoil,0.0,delta*8.0)
	update_pose()

func update_pose() -> void:
	sector = posmod(roundi(aim_angle/(PI/8.0)),16)
	head.frame = sector
	head.position = to_local(head_origin())-Vector2.from_angle(aim_angle)*recoil*2.0
	# Higher orb: slightly wider, lighter shadow within the tray.
	tray_shadow.scale = Vector2.ONE*(1.0+sin(phase)*0.035)
	tray_shadow.modulate.a = 0.92-sin(phase)*0.08
	modulate = Color(0.32,0.32,0.32) if sentry.state == sentry.State.DEAD else (Color(1.8,1.8,1.8) if sentry.hurt_flash>0 else Color.WHITE)
	queue_redraw()

func _draw() -> void:
	if sentry == null or sentry.state == sentry.State.DEAD:
		return
	var muzzle := to_local(muzzle_origin())
	var direction := Vector2.from_angle(aim_angle)
	if sentry.state == sentry.State.WARNING:
		var progress: float = 1.0-sentry.remaining/sentry.PARAMETERS.SENTRY_WARNING
		if sentry.alternating_attacks:
			var half_angle := deg_to_rad(12.0 if sentry.attack_mode == 0 else 30.0)
			var fan := PackedVector2Array([muzzle])
			for i in range(17):
				fan.append(muzzle+direction.rotated(lerpf(-half_angle,half_angle,i/16.0))*100)
			draw_colored_polygon(fan,Color(1,0.6,0.12,0.07+progress*0.12))
			draw_polyline(fan,Color(1,0.6,0.12,0.55),1.0)
			var count := 3 if sentry.attack_mode == 0 else 6
			for i in range(count):
				var ray := direction.rotated(lerpf(-half_angle,half_angle,float(i)/(count-1)))
				draw_dashed_line(muzzle,muzzle+ray*100,Color(1,0.75,0.25,0.55),1.0,4.0)
		else:
			draw_line(muzzle,muzzle+direction*70,Color(1,0.24,0.08,0.3+progress*0.4),1.0)
		draw_circle(muzzle,2.0+progress*2.0,Color(1,0.45,0.12,0.6))
	if recoil>0.2:
		draw_line(muzzle,muzzle+direction*9*recoil,Color(1,0.76,0.28,recoil),3.0)
		draw_circle(muzzle,2*recoil,Color(1,0.95,0.7,recoil))
