extends Node2D
## Short-lived floor contact sparks, not flames; particles stay in world space.
var player: CharacterBody2D
var spark_length_scale := 1.0
var sparks_enabled := true
var dust_color := Color(0.46,0.48,0.37,0.65)
var particles: Array[Dictionary] = []
var previous := Vector2.ZERO
var countdown := 0.0
var foot := 1.0
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	process_physics_priority = 25
	previous = player.global_position
	rng.randomize()
func clear() -> void:
	particles.clear()
	countdown = 0.0
	previous = player.global_position
	queue_redraw()
func _physics_process(delta: float) -> void:
	var motion := player.global_position-previous
	previous = player.global_position
	if player.is_dead or not player.controls_enabled or not player.sprint_window_focused or motion.length()>32.0:
		clear()
		return
	for i in range(particles.size()-1,-1,-1):
		var p := particles[i]
		p.age += delta
		if p.age >= p.life:
			particles.remove_at(i)
			continue
		p.pos += p.velocity*delta
		p.velocity *= exp(-5.0*delta)
	countdown -= delta
	if player.sprint_active and motion.length_squared()>0.01:
		if countdown <= 0.0:
			_emit_step(motion.normalized())
			countdown = 0.075
	else:
		countdown = 0.0
	queue_redraw()
func _emit_step(heading: Vector2) -> void:
	foot *= -1.0
	var origin := player.global_position+Vector2(0,5)-heading*3.0+heading.orthogonal()*foot*4.0
	# Narrow floor streaks, with a few lifted sparks fanning from the contact.
	for i in range(5 if sparks_enabled else 0):
		var direction := -heading.rotated(rng.randf_range(-0.22,0.22))
		if i == 1 or i == 2:
			direction = (-heading+Vector2(0,-rng.randf_range(0.35,0.9))).normalized()
		particles.append({"pos":origin,"velocity":direction*rng.randf_range(18,44),"age":0.0,"life":rng.randf_range(0.16,0.28),"dust":false,"size":rng.randf_range(7,15)*spark_length_scale if i<3 else 1.0,"direction":direction})
	var lobes: Array[Vector3] = []
	for i in range(7):
		lobes.append(Vector3(rng.randf_range(-0.8,0.8),rng.randf_range(-0.65,0.15),rng.randf_range(0.4,0.65)))
	particles.append({"pos":origin-heading*7.0,"velocity":-heading*16.0+Vector2(0,-5),"age":0.0,"life":0.48,"dust":true,"size":rng.randf_range(5,7),"lobes":lobes})
	while particles.size()>64:
		particles.pop_front()

func _draw_dust_lobe(center: Vector2, radius: float, color: Color) -> void:
	# Stepped silhouette keeps the cloud soft in shape but pixel-like at its edge.
	var outline := PackedVector2Array()
	for point in [Vector2(-1,-0.4),Vector2(-0.7,-0.4),Vector2(-0.7,-0.8),Vector2(-0.3,-0.8),Vector2(-0.3,-1),Vector2(0.3,-1),Vector2(0.3,-0.8),Vector2(0.7,-0.8),Vector2(0.7,-0.4),Vector2(1,-0.4),Vector2(1,0.4),Vector2(0.6,0.4),Vector2(0.6,0.7),Vector2(-0.6,0.7),Vector2(-0.6,0.4),Vector2(-1,0.4)]:
		outline.append((center+point*radius).round())
	draw_colored_polygon(outline,color)

func _draw() -> void:
	for p in particles:
		if not p.dust:
			continue
		var progress: float = p.age/p.life
		var fade: float = pow(1.0-progress,0.7)
		var size: float = p.size*(0.65+progress*0.9)
		var pos: Vector2 = p.pos
		for i in range(p.lobes.size()):
			var lobe: Vector3 = p.lobes[i]
			var center := pos+Vector2(lobe.x,lobe.y)*size
			var shade: float = 0.9+float(i%3)*0.09
			_draw_dust_lobe(center,size*lobe.z,Color(dust_color.r*shade,dust_color.g*shade,dust_color.b*shade,dust_color.a*fade))
	for p in particles:
		if p.dust:
			continue
		var fade: float = pow(1.0-p.age/p.life,0.65)
		var pos: Vector2 = p.pos.round()
		var tip: Vector2 = pos+p.direction*p.size*(0.5+0.5*fade)
		draw_line(pos,tip,Color(1.0,0.42,0.04,0.16*fade),3.0)
		draw_line(pos,tip,Color(1.0,0.65,0.12,fade),1.0)
		draw_line(pos,pos.lerp(tip,0.45),Color(1.0,0.94,0.64,fade),1.0)
		draw_rect(Rect2(pos-Vector2.ONE*0.5,Vector2.ONE),Color(1.0,0.96,0.72,fade))
