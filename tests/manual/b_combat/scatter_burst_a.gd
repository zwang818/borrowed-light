extends "res://tests/manual/b_combat/scatter_burst.gd"
## A / metal ignition: one simultaneous fan; parent owns swept hits.

var embers: Array[Dictionary] = []
var fading_trails: Array[Dictionary] = []
var ember_distance: Array[float] = []
var max_trail_length := 26.0

func _ready() -> void:
	super._ready()
	ember_distance.resize(pellet_count)
	for i in range(pellet_count): ember_distance[i] = fmod(i*3.7,10.0)

func _physics_process(delta: float) -> void:
	var previous_points := points.duplicate()
	var previous_spent := spent.duplicate()
	super._physics_process(delta)
	if is_queued_for_deletion(): return
	for i in range(pellet_count):
		if previous_spent[i]: continue
		var travel: float = previous_points[i].distance_to(points[i])
		var remaining: float = 10.0-ember_distance[i]
		while remaining <= travel:
			var origin: Vector2 = previous_points[i]+directions[i]*remaining
			var side := -1.0 if (i+int(origin.length()/10.0))%2 == 0 else 1.0
			embers.append({"point":origin,"born":age-(travel-remaining)/SPEED,"velocity":-directions[i]*12.0+directions[i].orthogonal()*side*9.0,"size":1.0 if i%2 == 0 else 0.75})
			remaining += 10.0
		ember_distance[i] = fmod(ember_distance[i]+travel,10.0)
		if spent[i]:
			fading_trails.append({"point":points[i],"axis":directions[i],"born":age,"length":minf(points[i].length(),max_trail_length)})
	for i in range(embers.size()-1,-1,-1):
		if age-embers[i].born >= 0.16: embers.remove_at(i)
	for i in range(fading_trails.size()-1,-1,-1):
		if age-fading_trails[i].born >= 0.10: fading_trails.remove_at(i)

func _init() -> void:
	launch_spacing = 0.0
	pellet_count = 9

func _draw() -> void:
	_draw_smoke()
	_draw_ignition()
	for trail in fading_trails:
		_draw_pellet_trail(trail.point,trail.axis,trail.length,(1.0-(age-trail.born)/0.10)*0.45)
	for ember in embers:
		var life: float = age-ember.born
		var fade := pow(1.0-life/0.16,2.0)
		var at: Vector2 = ember.point+ember.velocity*life
		draw_circle(at,ember.size+0.6,Color(1.0,0.35,0.04,fade*0.16))
		draw_rect(Rect2(at-Vector2.ONE*ember.size*0.5,Vector2.ONE*ember.size),Color(1.0,0.68,0.22,fade))
	for i in range(pellet_count):
		if spent[i] or distances[i] <= 0.0: continue
		var fade := clampf((RANGE-distances[i])/25.0,0.0,1.0)
		_draw_live_pellet(points[i], directions[i], minf(distances[i], max_trail_length), fade)

	for impact in impacts:
		_draw_impact(impact, age - impact.born)

func _draw_live_pellet(tip: Vector2, axis: Vector2, length: float, fade: float) -> void:
	var lateral := axis.orthogonal()
	_draw_pellet_trail(tip,axis,length,fade)
	# Faceted gold head with a white-hot centre, one head per real pellet.
	var head := PackedVector2Array([tip,tip-axis*2.0+lateral*1.9,
		tip-axis*5.0+lateral,tip-axis*7.0,tip-axis*5.0-lateral,
		tip-axis*2.0-lateral*1.9])
	draw_colored_polygon(head,Color(1.0,0.74,0.22,fade))
	draw_line(tip-axis*4.5,tip-axis*0.8,Color(1.0,0.98,0.82,fade),1.5)

func _draw_impact(impact: Dictionary, life: float) -> void:
	if life > 0.16: return
	var fade := 1.0-life/0.16
	var center: Vector2 = impact.point
	for i in range(5):
		var axis := Vector2(impact.normal).rotated(lerpf(-1.3,1.3,i/4.0))
		draw_line(center+axis*life*25.0,center+axis*(2.0+life*55.0),Color(1.0,0.62,0.14,fade),1.2)
	draw_circle(center,2.6*fade,Color(1.0,0.93,0.62,fade))

func _draw_pellet_trail(tip: Vector2, axis: Vector2, length: float, fade: float) -> void:
	# A bright inner filament, amber taper and faint outer glow; rear segments
	# fade independently so nine pellets stay distinct rather than forming a wall.
	for segment in range(7):
		var near := float(segment)/7.0
		var far := float(segment+1)/7.0
		var start := tip-axis*length*near
		var end := tip-axis*length*far
		var opacity := (1.0-near)*(1.0-near)*fade
		draw_line(start,end,Color(1.0,0.35,0.035,opacity*0.20),5.0*(1.0-near))
		draw_line(start,end,Color(1.0,0.68-0.30*near,0.12,opacity*0.85),2.4*(1.0-near)+0.3)
		if segment < 3:
			draw_line(start,end,Color(1.0,0.92,0.58,opacity*0.7),0.8)

func _draw_ignition() -> void:
	if age < 0.10:
		var time := age/0.10
		var fade := 1.0-time
		var stretch := 0.8+sin(time*PI)*0.35
		var outline := PackedVector2Array([
			Vector2(-1,-3),Vector2(6,-5),Vector2(19,-10),Vector2(14,-4),
			Vector2(27,-5),Vector2(19,-1),Vector2(32,0),Vector2(18,3),
			Vector2(24,8),Vector2(12,5),Vector2(14,10),Vector2(5,5),Vector2(-1,3)])
		for i in range(outline.size()): outline[i] *= stretch
		var glow := PackedVector2Array()
		for point in outline: glow.append(point*1.18)
		draw_colored_polygon(glow,Color(1.0,0.30,0.03,fade*0.22))
		draw_colored_polygon(outline,Color(1.0,0.55,0.08,fade))
		var core := PackedVector2Array([Vector2(-1,-2),Vector2(8,-3),Vector2(18,0),Vector2(8,3),Vector2(-1,2)])
		for i in range(core.size()): core[i] *= stretch
		draw_colored_polygon(core,Color(1.0,0.96,0.73,fade))
	if age < 0.16:
		var fade := 1.0-age/0.16
		for i in range(9):
			var axis := Vector2.RIGHT.rotated(lerpf(-0.65,0.65,i/8.0))
			var travel := age*(90.0+(i%3)*24.0)
			draw_line(axis*(4.0+travel),axis*(6.0+travel),Color(1.0,0.67,0.20,fade),1.0)

func _draw_smoke() -> void:
	if age >= 0.32: return
	var time := age/0.32
	var fade := sin(time*PI)*(1.0-time)*0.32
	var up := Vector2.UP.rotated(-global_rotation)
	for i in range(4):
		var center := Vector2(7.0+i*2.5,(i%2)*2.0-1.0)+up*time*(10.0+i*3.0)
		var radius := 2.0+time*(3.0+i*0.4)
		# Small pixel-edged wisps drift upward in world space in all aim directions.
		var cloud := PackedVector2Array()
		for corner in range(8):
			cloud.append((center+Vector2.from_angle(corner*TAU/8.0)*radius).round())
		draw_colored_polygon(cloud,Color(0.49,0.48,0.44,fade))
