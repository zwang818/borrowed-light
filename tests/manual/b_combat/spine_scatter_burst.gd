extends "res://tests/manual/b_combat/scatter_burst.gd"
## Flight and damage stay in the parent. Light and loose particles are visual only.
const FLAME := preload("res://tests/manual/b_combat/art/vfx/kenney_particle_pack/muzzle_03.png")
const STAR := preload("res://tests/manual/b_combat/art/vfx/kenney_particle_pack/star_06.png")
const TRACE := preload("res://tests/manual/b_combat/art/vfx/kenney_particle_pack/trace_01.png")
const FLARE := preload("res://tests/manual/b_combat/art/vfx/kenney_particle_pack/flare_01.png")
const SMOKE := preload("res://tests/manual/b_combat/art/vfx/kenney_particle_pack/smoke_07.png")
const HOT := Color("fff6cf")
const GOLD := Color("ffbe44")
const ORANGE := Color("ff681b")
const RED := Color("b22618")
const HEAD_LENGTH := 18.0
const PARTICLE_LIMIT := 164

class Ember:
	var origin: Vector2
	var velocity: Vector2
	var born: float
	var lifetime: float
	var size: float

var light_layer: Node2D
var random := RandomNumberGenerator.new()
var embers: Array[Ember] = []
var next_spark := PackedFloat32Array()
var spent_at := PackedFloat32Array()
var impact_glows: Array[Dictionary] = []

func _init() -> void:
	launch_spacing = 0.0
	pellet_count = 9

func _ready() -> void:
	super._ready()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light_layer = Node2D.new()
	light_layer.material = additive
	light_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(light_layer)
	light_layer.draw.connect(_draw_emission)
	for i in range(pellet_count):
		next_spark.append(random.randf_range(9.0, 24.0))
		spent_at.append(-1.0)
	_emit(Vector2(4, 0), Vector2.RIGHT, 33, 1.35, 95.0, 245.0)

func _physics_process(delta: float) -> void:
	var previous_hits := impacts.size()
	super._physics_process(delta)
	if is_queued_for_deletion():
		return
	for i in range(pellet_count):
		if spent_at[i] >= 0.0:
			continue
		var distance := points[i].length()
		while next_spark[i] <= distance:
			var axis := directions[i]
			var origin := axis * next_spark[i]
			var drift := (axis * 0.35 + axis.orthogonal() * random.randf_range(-1.0, 1.0)).normalized()
			_emit(origin, drift, 1, 0.25, 16.0, 48.0, age - (distance - next_spark[i]) / SPEED)
			next_spark[i] += random.randf_range(12.0, 22.0)
		if spent[i]:
			spent_at[i] = age
	for i in range(previous_hits, impacts.size()):
		_burst_at_surface(impacts[i])
	for i in range(embers.size() - 1, -1, -1):
		if age - embers[i].born >= embers[i].lifetime:
			embers.remove_at(i)
	light_layer.queue_redraw()

func _burst_at_surface(hit: Dictionary) -> void:
	var normal: Vector2 = hit.normal
	if normal.is_zero_approx():
		normal = -Vector2(hit.axis)
	var at: Vector2 = hit.point + normal
	# Merge neighboring hits into one readable flash. Damage still resolves per pellet.
	for flash in impact_glows:
		if flash.wall == hit.wall and age - flash.born < 0.048 and at.distance_squared_to(flash.point) < 100.0:
			_emit(at, normal, 2, 0.78, 58.0, 130.0)
			return
	impact_glows.append({ "point": at, "normal": normal, "born": age, "wall": hit.wall })
	_emit(at, normal, 16 if hit.wall else 22, 1.22 if hit.wall else 1.46, 60.0, 195.0)

func _emit(origin: Vector2, axis: Vector2, count: int, spread: float, slow: float, fast: float, birth := -1.0) -> void:
	for i in range(mini(count, PARTICLE_LIMIT - embers.size())):
		var ember := Ember.new()
		ember.origin = origin
		ember.velocity = axis.rotated(random.randf_range(-spread, spread)) * random.randf_range(slow, fast)
		ember.born = age if birth < 0.0 else birth
		ember.lifetime = random.randf_range(0.15, 0.31)
		ember.size = random.randf_range(0.7, 2.05)
		embers.append(ember)

func _draw() -> void:
	for i in range(pellet_count):
		_draw_flame_tail(i)
	for i in range(pellet_count):
		if spent_at[i] >= 0.0 or distances[i] <= 0.0:
			continue
		var axis := directions[i]
		var side := axis.orthogonal()
		var tip := points[i]
		var head := minf(distances[i], HEAD_LENGTH)
		var fade := clampf((RANGE - distances[i]) / 15.0, 0.0, 1.0)
		var shell := PackedVector2Array([
			tip + side, tip - axis * head * 0.16 + side * 3.3,
			tip - axis * head * 0.36 + side * 3.8, tip - axis * head * 0.72 + side * 2.7,
			tip - axis * head, tip - axis * head * 0.77 - side * 2.3,
			tip - axis * head * 0.34 - side * 3.8, tip - axis * head * 0.15 - side * 3.1,
			tip - side,
		])
		draw_colored_polygon(shell, Color(ORANGE, fade))
		draw_line(tip - axis * head * 0.70, tip - axis * head * 0.12, Color(GOLD, fade), 4.3)
		var core := PackedVector2Array([
			tip - axis * head * 0.04, tip - axis * head * 0.23 + side * 1.7,
			tip - axis * head * 0.47 + side * 1.5, tip - axis * head * 0.78,
			tip - axis * head * 0.49 - side * 1.4, tip - axis * head * 0.23 - side * 1.7,
		])
		draw_colored_polygon(core, Color(HOT, fade))
	for hit in impact_glows:
		var time: float = age - hit.born
		if time >= 0.25:
			continue
		var outward: Vector2 = hit.normal
		var tangent := outward.orthogonal()
		var center: Vector2 = hit.point
		if hit.wall:
			draw_colored_polygon(PackedVector2Array([
				center + tangent * 5.0, center + outward * 1.8,
				center - tangent * 5.0, center - outward * 0.65,
			]), Color(0.18, 0.075, 0.055, 0.56 * (1.0 - time / 0.25)))
		else:
			_draw_chips(center, outward, time)

func _draw_flame_tail(index: int) -> void:
	var tip := points[index]
	var travel := tip.length()
	var length := minf(travel, 38.0 + (index % 3) * 6.0)
	var fade := _trail_heat(index)
	if length < 2.0 or is_zero_approx(fade):
		return
	var axis := directions[index]
	var side := axis.orthogonal()
	# A dense, uneven flame tongue near the bolt, then short cooling fragments.
	var flicker := sin(age * 38.0 + float(index) * 1.9)
	var front := tip - axis * minf(travel * 0.27, 7.0)
	length = minf(length, front.length())
	var outline := PackedVector2Array([
		front + side * 3.2, front - axis * length * 0.27 + side * (4.1 + flicker * 0.7),
		front - axis * length * 0.56 + side * 1.6, front - axis * length * 0.74 + side * 2.1,
		front - axis * length + side * flicker, front - axis * length * 0.65 - side * 1.0,
		front - axis * length * 0.42 - side * (2.4 - flicker * 0.55), front - side * 2.9,
	])
	var front_heat := Color(ORANGE, fade * 0.83)
	var edge_heat := Color(RED, fade * 0.72)
	draw_polygon(outline, PackedColorArray([
		front_heat, edge_heat, Color(RED, fade * 0.58), Color(RED, fade * 0.38),
		Color(RED, 0.0), Color(RED, fade * 0.59), edge_heat, front_heat,
	]))
	var tongue := PackedVector2Array([
		front + side * 1.5, front - axis * length * 0.23 + side * (1.7 + flicker * 0.4),
		front - axis * length * 0.73 + side * flicker, front - axis * length * 0.25 - side * 0.9,
		front - side * 1.2,
	])
	draw_polygon(tongue, PackedColorArray([
		Color(GOLD, fade * 0.93), Color(ORANGE, fade * 0.88), Color(ORANGE, 0.0),
		Color(ORANGE, fade * 0.69), Color(GOLD, fade * 0.85),
	]))

func _draw_chips(center: Vector2, normal: Vector2, time: float) -> void:
	var phase := time / 0.25
	for i in range(3):
		var drift := normal.rotated(lerpf(-0.95, 1.10, i / 2.0))
		var up := Vector2.DOWN.rotated(-global_rotation)
		var at := center + drift * (3.0 + phase * (11.0 + i * 3.0)) + up * (7.0 * phase * phase)
		var edge := drift.rotated(phase * (3.0 + i))
		var chip := PackedVector2Array([at + edge * 2.7, at + edge.orthogonal(), at - edge * 1.75, at - edge.orthogonal() * 1.4])
		draw_colored_polygon(chip, Color(0.26, 0.22, 0.19, 1.0 - phase))
		draw_line(chip[0], chip[1], Color(GOLD, 1.0 - phase), 0.85)

func _draw_emission() -> void:
	for i in range(pellet_count):
		_draw_wake(i)
	_draw_embers()
	_draw_muzzle()
	for hit in impact_glows:
		_draw_impact_glow(hit, age - hit.born)

func _draw_wake(index: int) -> void:
	var point := points[index]
	var available := point.length()
	if available < 1.0:
		return
	var cooling := _trail_heat(index)
	if is_zero_approx(cooling):
		return
	var axis := directions[index]
	var length := minf(available, 54.0 + (index % 3) * 7.0)
	for i in range(3):
		var front := length * (0.16 + i * 0.30)
		var stamp_length := minf(available - front, length * (0.35 - i * 0.07))
		if stamp_length < 1.0:
			continue
		var width := lerpf(17.0, 6.0, i / 2.0)
		var color := ORANGE.lerp(RED, i / 2.0)
		var intensity := cooling * lerpf(0.92, 0.52, i / 2.0)
		_stamp(TRACE, point - axis * (front + stamp_length * 0.32),
			Vector2(width, stamp_length * 1.65), axis.angle() + PI / 2.0, Color(color, intensity))
	if spent_at[index] < 0.0:
		_stamp(FLARE, point - axis * minf(5.0, available * 0.5), Vector2(29, 19), axis.angle(), Color(ORANGE, 0.87 * cooling))

func _trail_heat(index: int) -> float:
	if spent_at[index] < 0.0:
		return clampf((RANGE - distances[index]) / 18.0, 0.0, 1.0)
	return clampf(1.0 - (age - spent_at[index]) / 0.11, 0.0, 1.0) * 0.74

func _draw_embers() -> void:
	var gravity := Vector2.DOWN.rotated(-global_rotation) * 170.0
	for ember in embers:
		var time := maxf(0.0, age - ember.born)
		var phase := clampf(time / ember.lifetime, 0.0, 1.0)
		var travel := (1.0 - exp(-5.0 * time)) / 5.0
		var at := ember.origin + ember.velocity * travel + gravity * (0.5 * time * time)
		var velocity := ember.velocity * exp(-5.0 * time) + gravity * time
		var hot := 1.0 - phase
		var color := RED.lerp(GOLD, hot)
		var stretch := clampf(velocity.length() * 0.065, 3.5, 14.0)
		_stamp(TRACE, at, Vector2(ember.size * 4.0, stretch), velocity.angle() + PI / 2.0, Color(color, hot))
		if ember.size > 1.25:
			var pixel := Vector2.ONE * maxf(0.6, ember.size * hot)
			light_layer.draw_rect(Rect2(at.round() - pixel * 0.5, pixel), Color(ORANGE.lerp(HOT, hot), hot))

func _draw_muzzle() -> void:
	var phase := age / 0.15
	if phase < 1.0:
		var heat := pow(1.0 - phase, 1.7)
		_stamp(FLARE, Vector2(8, 0), Vector2(108, 88), 0.0, Color(ORANGE, 0.97 * heat))
		_stamp(FLAME, Vector2(14 + phase * 10.0, 0), Vector2(70, 80), PI / 2.0, Color(GOLD, heat))
		_stamp(STAR, Vector2(3, 0), Vector2(51, 48) * (0.76 + 0.34 * heat), PI * 0.25, Color(HOT, heat))
		_draw_ring(Vector2(5 + phase * 24.0, 0), Vector2.RIGHT, 9.0 + phase * 23.0, heat)
	if age > 0.025 and age < 0.37:
		var cooling := (age - 0.025) / 0.345
		_stamp(SMOKE, Vector2(11 + cooling * 11.0, 0) + Vector2.UP.rotated(-global_rotation) * cooling * 9.0,
			Vector2.ONE * (17.0 + cooling * 18.0), cooling * 0.5, Color("c69970", 0.23 * sin(cooling * PI)))

func _draw_impact_glow(hit: Dictionary, time: float) -> void:
	if time >= 0.15:
		return
	var normal: Vector2 = hit.normal
	var center: Vector2 = hit.point
	var phase := time / 0.15
	var heat := pow(1.0 - phase, 1.75)
	_stamp(FLARE, center + normal * 4.0, Vector2(79, 69), normal.angle(), Color(ORANGE, heat))
	var size := Vector2(47, 23) if hit.wall else Vector2(41, 36)
	_stamp(STAR, center, size * (0.76 + heat * 0.32), normal.orthogonal().angle(), Color(HOT, heat))
	_draw_ring(center, normal, 7.0 + 21.0 * phase, heat * 0.77)

func _draw_ring(center: Vector2, axis: Vector2, radius: float, heat: float) -> void:
	var side := axis.orthogonal()
	for i in range(14):
		if i in [3, 10]:
			continue
		var a := lerpf(-1.32, 1.32, float(i) / 14.0)
		var b := lerpf(-1.32, 1.32, float(i + 1) / 14.0)
		var start := center + (cos(a) * axis * 0.50 + sin(a) * side) * radius
		var end := center + (cos(b) * axis * 0.50 + sin(b) * side) * radius
		light_layer.draw_line(start, end, Color(ORANGE, 0.40 * heat), 3.3)
		light_layer.draw_line(start, end, Color(GOLD, 0.64 * heat), 1.1)

func _stamp(texture: Texture2D, at: Vector2, size: Vector2, rotation: float, color: Color) -> void:
	light_layer.draw_set_transform(at, rotation)
	light_layer.draw_texture_rect(texture, Rect2(-size * 0.5, size), false, color)
	light_layer.draw_set_transform(Vector2.ZERO)
