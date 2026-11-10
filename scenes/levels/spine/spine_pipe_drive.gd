extends Node2D
## Moving hardware on a fixed pipe. All surfaces are drawn in pipe-local coordinates.

enum Part { ROTOR, WINDOW }

const INK := Color("20151a")
const IRON := Color("53343a")
const EDGE := Color("946354")
const BRONZE := Color("b47b57")
const PUMP_CYCLE := 4.0

var part := Part.ROTOR
var pipe_width := 100.0
var direction := 1.0
var phase := 0.0
var clock := 0.0
var probe: VisibleOnScreenNotifier2D

func _ready() -> void:
	if part == Part.ROTOR:
		var bearing := Node2D.new()
		bearing.name = "BearingHousing"
		bearing.show_behind_parent = true
		bearing.use_parent_material = true
		bearing.draw.connect(_draw_bearings.bind(bearing))
		add_child(bearing)
	var reach := Vector2(_window_length() * 0.5 + 24.0, pipe_width * 0.65 + 9.0)
	probe = VisibleOnScreenNotifier2D.new()
	probe.rect = Rect2(-reach, reach * 2.0)
	probe.screen_entered.connect(queue_redraw)
	add_child(probe)

func update_motion(seconds: float) -> void:
	clock = seconds
	if is_visible_in_tree() and probe.is_on_screen():
		queue_redraw()

func _draw() -> void:
	if part == Part.ROTOR:
		_draw_rotor()
	else:
		_draw_window()

func _draw_bearings(bearing: Node2D) -> void:
	var radius := _rotor_radius()
	var half := _rotor_half_width()
	var rim := clampf(pipe_width * 0.065, 4.0, 9.0)
	# Bearings embrace a drum. Curved front surfaces leave the underlying tube in place.
	for side: float in [-1.0, 1.0]:
		_rotor_band(bearing, side * (half + rim), rim + 2.0, radius + 3.0, IRON)
		_rotor_band(bearing, side * (half + rim * 1.67), 2.1, radius + 4.0, Color("302026"))
		_rotor_band(bearing, side * (half + rim * 1.48), 1.2, radius + 4.2, EDGE)
		for index in range(5):
			var bolt := _project(side * (half + rim * 0.91), radius + 3.0, (index - 2) * 0.48).round()
			bearing.draw_rect(Rect2(bolt - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), INK)
			bearing.draw_rect(Rect2(bolt - Vector2(2.0, 2.0), Vector2(3.0, 1.0)), BRONZE)
	_rotor_band(bearing, 0.0, half + rim * 0.2, radius, Color("70413b"))
	_rotor_band(bearing, 0.0, half * 0.63, radius + 1.0, Color("38242a"))
	for side: float in [-1.0, 1.0]:
		_rotor_band(bearing, side * (half - 2.0), 1.2, radius + 1.0, BRONZE)

func _draw_rotor() -> void:
	var radius := _rotor_radius()
	var half := _rotor_half_width()
	var rise := clampf(pipe_width * 0.105, 6.0, 15.0)
	var beat := TAU * clock / PUMP_CYCLE + phase
	var angle := direction * (TAU * clock / 5.8 + 0.16 * sin(beat)) + phase
	# Only the near half is visible. The teeth shorten at the silhouette and roll out of sight.
	for tooth in range(8):
		var center := wrapf(angle + TAU * tooth / 8.0, -PI, PI)
		var from := maxf(-PI * 0.5, center - 0.17)
		var to := minf(PI * 0.5, center + 0.17)
		if from >= to:
			continue
		var root := radius - 1.0
		var tip := radius + rise
		var foot := half * 0.73
		var crown := half * 0.57
		var a := _project(-foot, root, from)
		var b := _project(foot, root, from)
		var c := _project(foot, root, to)
		var d := _project(-crown, tip, from)
		var e := _project(crown, tip, from)
		var f := _project(crown, tip, to)
		var g := _project(-crown, tip, to)
		var light := maxf(0.0, cos(center + 0.48))
		var glint := pow(light, 19.0)
		var metal := Color("a0714b") if tooth == 0 else Color("875347")
		if absf(a.y - d.y) > 0.15:
			_face(self, a, b, e, d, metal.darkened(0.62))
		_face(self, b, c, f, e, metal.darkened(0.46))
		_face(self, d, e, f, g, metal.darkened(0.38 * (1.0 - light)))
		var bevel := metal.lerp(Color("e4aa73"), 0.19 + glint * 0.47)
		draw_line(d.lerp(g, 0.16), e.lerp(f, 0.16), bevel, 2.0)
		draw_line(e.lerp(f, 0.19), f, metal.darkened(0.22), 1.5)
		var contact := _project(0.0, tip, (from + to) * 0.5)
		var wear := Vector2(crown * (0.37 + 0.04 * (tooth % 3)), 0.0)
		draw_line(contact - wear, contact + wear, metal.darkened(0.40), 1.4)
		if to - from > 0.16:
			var nick := d.lerp(e, 0.28 + 0.12 * (tooth % 4)).lerp(contact, 0.27).round()
			draw_rect(Rect2(nick, Vector2(3.0, 1.0)), bevel)
	if pipe_width >= 68.0:
		_draw_bearing_sparks(angle, half, radius + rise)

func _draw_bearing_sparks(angle: float, half: float, tip: float) -> void:
	# Every other tooth can shed a short burst at the same bearing edge.
	var contact_angle := -0.52
	var spacing := TAU / 4.0
	var advance := direction * (angle - contact_angle)
	var seconds := fposmod(advance, spacing) * 5.8 / TAU
	if seconds >= 0.33:
		return
	var origin := _project(half * 0.59, tip - 2.0, contact_angle).round()
	for index in range(4):
		var age := (seconds - index * 0.021) / (0.19 + index * 0.025)
		if age < 0.0 or age >= 1.0:
			continue
		var path := Vector2(9.0 + index * 4.0, direction * (19.0 - index * 4.0))
		var at := (origin + path * age + Vector2(0.0, 8.0 * age * age)).round()
		var heat := Color("ffd496").lerp(Color("cc683a"), age)
		heat.a = pow(1.0 - age, 0.67) * 0.94
		draw_line(at, (at - path * 0.18).round(), Color(0.91, 0.38, 0.17, heat.a * 0.56), 1.2)
		var size := 2.5 if index % 2 == 0 else 1.5
		draw_rect(Rect2(at, Vector2.ONE * size), heat)
	var reflection := Color(0.89, 0.35, 0.16, 0.19 * (1.0 - seconds / 0.33))
	draw_rect(Rect2(origin - Vector2(3.0, 3.0), Vector2(7.0, 6.0)), reflection)

func _rotor_band(bearing: Node2D, center: float, half: float, radius: float, paint: Color) -> void:
	for index in range(10):
		var a := -PI * 0.5 + PI * index / 10.0
		var b := a + PI / 10.0
		var light := maxf(0.0, cos((a + b) * 0.5 + 0.46))
		_face(bearing, _project(center - half, radius, a), _project(center + half, radius, a),
			_project(center + half, radius, b), _project(center - half, radius, b),
			paint.darkened(0.56 * (1.0 - light)))

func _project(axial: float, radius: float, angle: float) -> Vector2:
	return Vector2(axial - cos(angle) * radius * 0.20, sin(angle) * radius)

func _face(target: Node2D, a: Vector2, b: Vector2, c: Vector2, d: Vector2, paint: Color) -> void:
	target.draw_colored_polygon(PackedVector2Array([a, b, c, d]), paint)

func _rotor_radius() -> float:
	return pipe_width * 0.5 + 4.0

func _rotor_half_width() -> float:
	return clampf(pipe_width * 0.22, 13.0, 33.0)

func _window_length() -> float:
	return clampf(pipe_width * 1.10, 55.0, 162.0)

func _draw_window() -> void:
	var half := Vector2(_window_length() * 0.5, clampf(pipe_width * 0.15, 10.0, 24.0))
	var box := Rect2(-half, half * 2.0)
	_panel(box.grow(3.0), Color("2b191f"))
	_panel(box, Color("885b4e"))
	_panel(box.grow(-2.0), IRON)
	var aperture := box.grow_individual(-9.0, -5.0, -9.0, -5.0)
	draw_rect(aperture, Color("24171e"))
	draw_rect(aperture.grow_individual(0.0, -2.0, 0.0, -2.0), Color("411e27"))
	# Each carrier travels beyond the slot at either end. The frame masks its entry and exit.
	var length := roundf(aperture.size.x * 0.29)
	var travel := aperture.size.x + length
	var fraction := fposmod(clock / PUMP_CYCLE + phase / TAU + 0.5, 1.0)
	var stroke := fraction - 0.68 * sin(TAU * fraction) / TAU
	var center := roundf(direction * (stroke - 0.5) * travel)
	var core_height := aperture.size.y * 0.66
	var core := Rect2(center - length * 0.5, -core_height * 0.5, length, core_height)
	_draw_window_wake(aperture, center, length, fraction)
	_in_slot(aperture, core.grow_individual(-2.0, 1.0, -2.0, 1.0), Color("75312f"))
	_in_slot(aperture, core, Color("a94d37"))
	_in_slot(aperture, core.grow_individual(-3.0, -1.0, -3.0, -core_height * 0.52), Color("db8c54"))
	_in_slot(aperture, core.grow_individual(-4.0, -core_height * 0.52, -4.0, -1.0), Color("7c392e"))
	var shine := 1.0 - clampf(absf(center) / (aperture.size.x * 0.60), 0.0, 1.0)
	_in_slot(aperture, Rect2(core.position.x + 4.0, core.position.y + 1.0, length - 8.0, 1.3),
		Color(1.0, 0.74, 0.43, 0.24 + shine * 0.54))
	for cap: float in [core.position.x + 1.0, core.end.x - 5.0]:
		_in_slot(aperture, Rect2(cap, core.position.y, 4.0, core_height), Color("653334"))
		_in_slot(aperture, Rect2(cap + 1.0, core.position.y + 1.0, 1.0, core_height * 0.55), BRONZE)
	# Glass rails and retaining bridges remain stationary in front of the moving assembly.
	draw_rect(Rect2(aperture.position + Vector2(5.0, 3.0), Vector2(aperture.size.x - 10.0, 1.2)),
		Color(0.88, 0.58, 0.40, 0.20))
	draw_rect(Rect2(aperture.position, Vector2(aperture.size.x, 2.0)), EDGE)
	draw_rect(Rect2(aperture.position.x, aperture.end.y - 2.0, aperture.size.x, 2.0), INK)
	_in_slot(aperture, Rect2(center - length * 0.67, aperture.position.y, length * 1.34, 2.0),
		Color(0.92, 0.46, 0.24, 0.39))
	for brace: float in [-0.31, 0.31]:
		var x := roundf(aperture.size.x * brace)
		draw_rect(Rect2(x - 2.0, -half.y + 2.0, 4.0, box.size.y - 4.0), INK)
		draw_rect(Rect2(x - 2.0, -half.y + 2.0, 1.5, box.size.y - 4.0), EDGE)
	for x: float in [-half.x + 5.0, half.x - 5.0]:
		for y: float in [-half.y + 4.0, half.y - 4.0]:
			draw_rect(Rect2(x - 1.5, y - 1.5, 3.0, 3.0), INK)
			draw_rect(Rect2(x - 1.5, y - 1.5, 2.0, 1.0), BRONZE)

func _draw_window_wake(aperture: Rect2, center: float, length: float, fraction: float) -> void:
	var reach := aperture.size.y * 0.29
	for index in range(5):
		var age := fposmod(fraction * 4.0 + index * 0.21, 1.0)
		var gap := length * 0.55 + 3.0 + index * 4.0 + age * 8.0
		var at := Vector2(center - direction * gap, reach * sin(index * 2.4 + age * 1.8)).round()
		var color := Color(0.98, 0.56, 0.30, (1.0 - age) * (0.72 - index * 0.065))
		_in_slot(aperture, Rect2(at, Vector2(2.0 + float(index % 2), 1.5)), color)

func _panel(box: Rect2, paint: Color) -> void:
	var bevel := 5.0
	draw_colored_polygon(PackedVector2Array([box.position + Vector2(bevel, 0.0),
		Vector2(box.end.x - bevel, box.position.y), Vector2(box.end.x, box.position.y + bevel),
		box.end - Vector2(0.0, bevel), box.end - Vector2(bevel, 0.0),
		Vector2(box.position.x + bevel, box.end.y), Vector2(box.position.x, box.end.y - bevel),
		box.position + Vector2(0.0, bevel)]), paint)

func _in_slot(slot: Rect2, piece: Rect2, paint: Color) -> void:
	var visible_part := slot.intersection(piece)
	if visible_part.has_area():
		draw_rect(visible_part, paint)
