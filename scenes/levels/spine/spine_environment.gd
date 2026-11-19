extends Node2D
## Dresses the saved 2D footprints. The source map still owns collision and anchors.
const PIXELS = preload("res://scenes/levels/abdomen/abdomen_art_scale.gd")
const METAL = preload("res://scenes/levels/spine/spine_metal.gdshader")
const PIPE = preload("res://scenes/levels/spine/spine_pipe.gdshader")
const MACHINERY = preload("res://scenes/levels/spine/spine_machinery.gd")
const INTERACTION_FIXTURE := preload("res://scenes/levels/spine/spine_interaction_fixture.gd")
const FIXTURE = preload("res://scenes/levels/spine/spine_fixture.gd")
const PIPE_DRIVE = preload("res://scenes/levels/spine/spine_pipe_drive.gd")
const FIXTURE_FINISH := preload("res://scenes/levels/spine/spine_fixture_finish.gdshader")
const DRIVE_FINISH = preload("res://scenes/levels/spine/spine_drive_finish.gdshader")
const ENTRY_TUNNEL = preload("res://scenes/levels/spine/spine_entry_tunnel.gd")
const FORWARD := Vector2(0.9063078, -0.4226183)
const DOWN := Vector2(0.4226183, 0.9063078)
const BRASS := Color("bd8e51")
const BLUE := Color("76aaba")
enum Tube { COPPER, VESSEL, HOSE, COUPLING }

@onready var map := get_parent()
var enabled := true
var arc_preview := true
var fittings: Array[Node2D] = []
var depth_fittings: Node2D
var painted_faces: Array[Polygon2D] = []
var original_colors: Array[Color] = []
var art_colors: Array[Color] = []
var finishes: Array[ShaderMaterial] = []
var blockout_lines: Array[Line2D] = []
var rim_fittings: Node2D
var service_open: Node2D
var service_covers: Node2D
var service_hint: Node2D
var service_rims: Node2D
var service_skirts: Node2D
var checkpoint_skin: INTERACTION_FIXTURE
var protocol_console: INTERACTION_FIXTURE
var demo_reader: INTERACTION_FIXTURE
var gate_reader: INTERACTION_FIXTURE
var fluid_station: INTERACTION_FIXTURE
var authorization_skin: INTERACTION_FIXTURE
var exit_gate_skin: INTERACTION_FIXTURE
var metal: Array[ShaderMaterial] = []
var pipe_uv: GradientTexture2D
var drive_finish: ShaderMaterial
var fixture_finish: ShaderMaterial
var cover_blockouts: Array[Node2D] = []
var pipe_drives: Array[Node2D] = []
var circulation_clock := 0.0
var circulation_frame := -1

func _ready() -> void:
	if not enabled:
		set_process(false)
		return
	for finish in range(4):
		var material := ShaderMaterial.new()
		material.shader = METAL
		material.set_shader_parameter("pixel_world", PIXELS.ART_PIXEL_WORLD)
		material.set_shader_parameter("finish", finish)
		metal.append(material)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	pipe_uv = GradientTexture2D.new()
	pipe_uv.gradient = gradient
	pipe_uv.width = 4
	pipe_uv.height = 4
	fixture_finish = ShaderMaterial.new()
	fixture_finish.shader = FIXTURE_FINISH
	drive_finish = ShaderMaterial.new()
	drive_finish.shader = DRIVE_FINISH
	drive_finish.set_shader_parameter("pixel_world", PIXELS.ART_PIXEL_WORLD)

	_build_background()
	var service := _group("ServicePassageArt", 0)
	service_open = _group("Open", 0, service)
	service_covers = _group("ArmorCovers", 2, service)
	service_hint = _group("HatchHint", 3, service)
	service_rims = _group("Rims", 1, service_open)
	service_skirts = _group("Skirts", -3, service_open)
	_build_shell()
	_build_fittings()
	update_service_passage()
	set_art_enabled(true)

func _process(delta: float) -> void:
	circulation_clock += delta
	var frame := floori(circulation_clock * 24.0)
	if frame == circulation_frame or not enabled:
		return
	circulation_frame = frame
	for drive in pipe_drives:
		drive.update_motion(float(frame) / 24.0)

func set_art_enabled(value: bool) -> void:
	enabled = value
	for index in range(painted_faces.size()):
		var face := painted_faces[index]
		face.material = finishes[index] if value else null
		face.color = art_colors[index] if value else original_colors[index]
	for line in blockout_lines:
		line.visible = not value
	for cover in cover_blockouts:
		cover.visible = not value
	for group in fittings:
		group.visible = value
	map.get_node("DeepStructure").visible = not value
	map.get_node("BackgroundMachines").visible = not value
	set_depth_enabled(map.depth_enabled)

func set_depth_enabled(value: bool) -> void:
	if is_instance_valid(depth_fittings):
		depth_fittings.visible = enabled and value
		rim_fittings.visible = enabled and value
		service_rims.visible = value
		service_skirts.visible = value

func update_service_passage() -> void:
	if not is_instance_valid(service_open):
		return
	var state: int = map.service_passage_state
	service_open.visible = state == map.ServicePassage.OPEN
	service_covers.visible = not service_open.visible
	service_hint.visible = state == map.ServicePassage.REVEALED

func _paint(face: Polygon2D, paint: Color, finish: int) -> void:
	painted_faces.append(face)
	original_colors.append(face.color)
	art_colors.append(paint)
	finishes.append(metal[finish])

func _group(label: String, layer: int, parent: Node2D = null) -> Node2D:
	var group := Node2D.new()
	group.name = label
	group.z_index = layer
	if parent == null:
		add_child(group)
		fittings.append(group)
	else:
		parent.add_child(group)
	return group

func _ribbon(parent: Node2D, label: String, points: PackedVector2Array, width: float, tint: Color, pitch: float, profile: Tube) -> Line2D:
	var run := 0.0
	for index in range(1, points.size()):
		run += points[index - 1].distance_to(points[index])
	var ribbon := Line2D.new()
	ribbon.name = label
	ribbon.points = points
	ribbon.width = width
	ribbon.default_color = tint
	ribbon.joint_mode = Line2D.LINE_JOINT_ROUND
	var cap := Line2D.LINE_CAP_NONE if profile == Tube.COUPLING else Line2D.LINE_CAP_ROUND
	ribbon.begin_cap_mode = cap
	ribbon.end_cap_mode = cap
	ribbon.texture = pipe_uv
	ribbon.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var material := ShaderMaterial.new()
	material.shader = PIPE
	material.set_shader_parameter("pixel_world", PIXELS.ART_PIXEL_WORLD)
	material.set_shader_parameter("run", run)
	material.set_shader_parameter("width", width)
	material.set_shader_parameter("pitch", pitch)
	material.set_shader_parameter("phase", float(label.hash() % 83))
	material.set_shader_parameter("profile", profile)
	ribbon.material = material
	parent.add_child(ribbon)
	return ribbon

func _build_background() -> void:
	var backdrop := _group("ChamberWall", -45)
	var bounds: Rect2 = map.get_meta("map_bounds")
	bounds = bounds.grow(1900.0)
	_shape(backdrop, _quad(bounds.get_center(), Vector2.RIGHT, bounds.size), Color("251019"), 2)
	var track: Vector2 = map.get_node("Markers/PlayerSpawn").position
	_build_circulation(track)
	_build_bundles(track)
	_shade_upper_background(track)

func _shade_upper_background(track: Vector2) -> void:
	var shade := _group("UpperBackgroundShade", -13)
	var stations := [8110.0, 8690.0, 10510.0, 10960.0]
	var density := [0.0, 0.31, 0.33, 0.0]
	for index in range(stations.size() - 1):
		var left := track + FORWARD * float(stations[index])
		var right := track + FORWARD * float(stations[index + 1])
		var extent := DOWN * 1850.0
		var tint_left := Color(0.07, 0.032, 0.046, density[index])
		var tint_right := Color(0.07, 0.032, 0.046, density[index + 1])
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([left - extent, right - extent, right + extent, left + extent])
		band.vertex_colors = PackedColorArray([tint_left, tint_right, tint_right, tint_left])
		shade.add_child(band)

func _build_circulation(track: Vector2) -> void:
	var deep := _group("RecessedVessels", -43)
	var returns := _group("ReturnVessels", -40)
	var crossing := _group("CrossVessels", -38)
	var branches := _group("BranchVessels", -35)
	var trunks := _group("TrunkVessels", -30)
	var fittings_layer := _group("VesselFittings", -29)
	var pumps := _group("CirculationPumps", -24)
	var stations := PackedFloat32Array([-900, -60, 780, 1640, 2560, 3570, 4510, 5520, 6470,
		7520, 8500, 9510, 10500, 11520, 12340])
	_build_cross_vessels(crossing, track, stations)
	for side: int in [-1, 1]:
		var outward := DOWN * side
		var near_offsets: PackedFloat32Array
		if side < 0:
			near_offsets = PackedFloat32Array([570, 470, 545, 391, 475, 556, 395, 500, 565,
				460, 375, 542, 438, 570, 516])
		else:
			near_offsets = PackedFloat32Array([440, 560, 432, 548, 412, 530, 570, 440, 510,
				412, 548, 397, 514, 432, 587])
		var near := PackedVector2Array()
		var distant := PackedVector2Array()
		var capillaries := PackedVector2Array()
		var underside := PackedVector2Array()
		for i in range(stations.size()):
			var axis := track + FORWARD * (stations[i] + side * 75.0)
			var bias := float((i * 83 + side * 39) % 151)
			near.append(axis + outward * near_offsets[i])
			distant.append(axis + outward * (750.0 + bias * 0.95))
			capillaries.append(axis + FORWARD * (90.0 if i % 2 else -95.0) + outward * (254.0 + bias * 0.43))
			underside.append(axis + outward * (1050.0 + bias * 1.8))
		var trunk_width := 122.0 if side < 0 else 145.0
		var wine := Color("722632") if side < 0 else Color("792733")
		_ribbon(deep, "DeepReturn%d" % side, _curved_path(underside), 91, Color("3d1521"), 169, Tube.VESSEL)
		var distant_curve := _path_curve(distant)
		var inner_curve := _path_curve(capillaries)
		var trunk_curve := _path_curve(near)
		_ribbon(returns, "FarReturn%d" % side, distant_curve.get_baked_points(), 68, Color("501b29"), 138, Tube.VESSEL)
		_ribbon(returns, "InnerReturn%d" % side, inner_curve.get_baked_points(), 33, Color("54202a"), 112, Tube.VESSEL)
		_ribbon(trunks, "ArterialTrunk%d" % side, trunk_curve.get_baked_points(), trunk_width, wine, 171, Tube.VESSEL)
		# Put the first drive and viewing port in the camera's entrance framing.
		var entrance := trunk_curve.get_closest_offset(near[1]) + (-96.0 if side < 0 else 505.0)
		_pipe_drive(fittings_layer, trunk_curve, entrance, trunk_width, 1.0, float(side))
		_pipe_drive(fittings_layer, trunk_curve, entrance + 150.0, trunk_width, 1.0, float(side), PIPE_DRIVE.Part.WINDOW)
		# Keep return fittings below the branching and arterial layers.
		var return_drives := Node2D.new()
		return_drives.name = "ReturnDrives%d" % side
		returns.add_child(return_drives)
		for i in range(1, stations.size() - 1):
			var root := near[i]
			var direction := (near[i + 1] - near[i - 1]).normalized()
			var sweep_sign := -1.0 if (i + side) % 3 == 0 else 1.0
			var flow := direction * sweep_sign
			var inner := (i + side) % 3 != 1
			var bank := capillaries if inner else distant
			var return_curve := inner_curve if inner else distant_curve
			var next := i + int(sweep_sign)
			var contact := return_curve.get_closest_offset(bank[i].lerp(bank[next], 0.65))
			var return_end := return_curve.sample_baked(contact)
			var approach := return_curve.sample_baked(contact - sweep_sign * 112.0)
			var turn := -outward if inner else outward
			var branch_curve := _path_curve(PackedVector2Array([root, root + flow * 112.0 + turn * 22.0,
				root + flow * 208.0 + turn * 130.0, approach - turn * 35.0, return_end]))
			var arc := branch_curve.get_baked_points()
			var branch_width := 77.0 if i % 3 == 0 else 56.0 + float(i % 2) * 8.0
			var fork := _ribbon(branches, "YBranch%d_%d" % [side, i], arc, branch_width,
				wine.darkened(0.11), 122, Tube.VESSEL)
			fork.end_cap_mode = Line2D.LINE_CAP_NONE
			var reducer := Curve.new()
			reducer.add_point(Vector2(0.0, 1.0))
			reducer.add_point(Vector2(0.68, 1.0))
			reducer.add_point(Vector2(1.0, minf(1.0, (29.0 if inner else 60.0) / branch_width)))
			fork.width_curve = reducer
			var socket := arc[mini(11, arc.size() - 1)]
			var tangent := arc[mini(13, arc.size() - 1)] - arc[mini(9, arc.size() - 1)]
			_vessel_collar(branches, "BranchFlange%d_%d" % [side, i], socket, tangent.normalized(), branch_width + 10.0)
			if i % 2 == 0:
				_vessel_collar(fittings_layer, "MainFlange%d_%d" % [side, i],
					root + direction * 23.0, direction, trunk_width + 12.0)
			var phase := i * 0.74 + side
			var axial := trunk_curve.get_closest_offset(root)
			if i > 1:
				_pipe_drive(fittings_layer, trunk_curve, axial + 132.0, trunk_width, 1.0, phase)
				# On the entrance bank, leave room for the larger port immediately upstream.
				var port_offset := 296.0 if side > 0 and i == 2 else -126.0
				_pipe_drive(fittings_layer, trunk_curve, axial + port_offset, trunk_width, 1.0, phase, PIPE_DRIVE.Part.WINDOW)
			if i % 2 == 1:
				var return_at := distant_curve.get_closest_offset(distant[i]) + 98.0
				_pipe_drive(return_drives, distant_curve, return_at + 94.0, 68.0, -1.0, phase - 0.65)
				_pipe_drive(return_drives, distant_curve, return_at, 68.0, -1.0, phase - 0.65, PIPE_DRIVE.Part.WINDOW)
			else:
				_pipe_drive(return_drives, inner_curve, inner_curve.get_closest_offset(capillaries[i]) - 76.0,
					33.0, -1.0, phase - 0.48, PIPE_DRIVE.Part.WINDOW)
			if i % 3 != 1:
				_pipe_drive(branches, branch_curve, branch_curve.get_baked_length() * 0.49,
					branch_width, 1.0, phase - 0.38, PIPE_DRIVE.Part.WINDOW)
			_build_deep_crosslink(deep, near, distant, underside, i, side, outward)
			if i % 3 == (0 if side < 0 else 2):
				_build_pump(pumps, returns, root, direction, outward, trunk_width, i, side)

func _build_cross_vessels(layer: Node2D, track: Vector2, stations: PackedFloat32Array) -> void:
	# Deeper vessels change heading across the cavity and pass beneath the diagonal spine.
	for index in range(stations.size()):
		var anchor := track + FORWARD * (stations[index] + 283.0)
		var flow := FORWARD * (-1.0 if index % 3 == 1 else 1.0)
		var cross_curve := _path_curve(PackedVector2Array([
			anchor - DOWN * 1590.0 - flow * 575.0,
			anchor - DOWN * 1070.0 - flow * 328.0,
			anchor - DOWN * 685.0 - flow * 225.0,
			anchor - DOWN * 350.0 + flow * 160.0,
			anchor + DOWN * 235.0 + flow * 220.0,
			anchor + DOWN * 582.0 + flow * 52.0,
			anchor + DOWN * 965.0 + flow * 150.0,
			anchor + DOWN * 1510.0 + flow * 528.0,
		]))
		var path := cross_curve.get_baked_points()
		var large := index % 3 == 1 or index % 3 == 2
		var width := 94.0 if large else 45.0
		var tint := Color("4f1a25") if large else Color("431720")
		# Anchor the far ends to the wall so the cutout view shows seated pipes.
		for end: int in [0, path.size() - 1]:
			var inner := 3 if end == 0 else end - 3
			var axis := path[inner].direction_to(path[end])
			var socket := _quad(path[end] + axis * 19.0, axis, Vector2(width * 0.64 + 29.0, width + 32.0))
			_shape(layer, socket, Color("351d26"), 1)
			socket.append(socket[0])
			_stroke(layer, socket, 3.0, Color("4e2d31"))
		_ribbon(layer, "CrossVessel%d" % index, path, width, tint, 131.0, Tube.VESSEL)
		for end: int in [0, path.size() - 1]:
			var inner := 3 if end == 0 else end - 3
			var axis := path[inner].direction_to(path[end])
			_vessel_collar(layer, "WallSocket%d_%d" % [index, end],
				path[end] - axis * 2.0, axis, width + 14.0)
		var first := floori(path.size() * 0.20)
		var second := floori(path.size() * 0.80)
		for socket_index: int in [first, second]:
			var joint := path[socket_index]
			var direction := path[socket_index - 2].direction_to(path[socket_index + 2])
			_vessel_collar(layer, "CrossFlange%d_%d" % [index, socket_index], joint, direction, width + 8.0)
		var run := cross_curve.get_baked_length()
		var transfer := -1.0 if index % 2 == 0 else 1.0
		var phase := index * 1.19
		for fraction: float in [0.29, 0.68]:
			_pipe_drive(layer, cross_curve, run * fraction, width, transfer, phase)
			if large:
				_pipe_drive(layer, cross_curve, run * fraction + 94.0, width, transfer, phase - 0.5, PIPE_DRIVE.Part.WINDOW)

func _build_deep_crosslink(layer: Node2D, near: PackedVector2Array, distant: PackedVector2Array,
		underside: PackedVector2Array, index: int, side: int, outward: Vector2) -> void:
	var start := near[index - 1].lerp(near[index], 0.24)
	var far_end := underside[index].lerp(underside[index + 1], 0.22)
	var elbow := distant[index] - FORWARD * (176.0 if index % 2 else 264.0)
	for channel in range(2):
		var gap := outward * channel * 27.0
		var line := _curved_path(PackedVector2Array([start + gap, start + outward * 95.0 + gap,
			elbow + gap, far_end - FORWARD * 90.0 + gap, far_end + gap]))
		_ribbon(layer, "Crosslink%d_%d_%d" % [side, index, channel], line, 24 - channel * 8,
			Color("4a1a26") if channel == 0 else Color("341722"), 111, Tube.VESSEL if channel == 0 else Tube.HOSE)

func _vessel_collar(layer: Node2D, label: String, at: Vector2, axis: Vector2, width: float) -> void:
	var path := PackedVector2Array([at - axis * 15.0, at + axis * 15.0])
	_ribbon(layer, label, path, width, Color("775046"), 30, Tube.COUPLING)

func _pipe_drive(layer: Node2D, curve: Curve2D, distance: float, width: float,
		direction: float, phase: float, part := PIPE_DRIVE.Part.ROTOR) -> void:
	var drive = PIPE_DRIVE.new()
	drive.name = ("TransportWindow" if part == PIPE_DRIVE.Part.WINDOW else "RotaryCoupling") + str(pipe_drives.size())
	drive.part = part
	drive.pipe_width = width
	drive.direction = direction
	drive.phase = phase
	drive.material = drive_finish
	drive.transform = curve.sample_baked_with_rotation(distance, true)
	layer.add_child(drive)
	pipe_drives.append(drive)

func _build_pump(pumps: Node2D, lines: Node2D, trunk: Vector2, axis: Vector2,
		outward: Vector2, width: float, index: int, side: int) -> void:
	var label := "Pump%d_%d" % [side, index]
	var center := trunk + outward * (width * 0.5 + 111.0) + axis * (130.0 if side < 0 else -125.0)
	for connection: int in [-1, 1]:
		var inlet := center + axis * (connection * 68.0) - outward * 33.0
		var bend := inlet + axis * (connection * 55.0) - outward * 38.0
		var end := trunk + axis * (connection * 145.0)
		var pipe := _curved_path(PackedVector2Array([inlet, bend, end]))
		_ribbon(lines, label + str(connection), pipe, 26, Color("6d2530"), 89, Tube.VESSEL)
	var pump = MACHINERY.new()
	pump.name = label
	pump.kind = "piston"
	pump.position = center
	pump.rotation = axis.angle() + (0.10 if side < 0 else -0.12)
	pump.phase = index * 0.74 + side
	pumps.add_child(pump)
	pump.art_enabled = true

func _build_bundles(track: Vector2) -> void:
	depth_fittings = _group("CopperBundle", -12)
	var feeds := Node2D.new()
	feeds.name = "BypassFeeds"
	feeds.z_index = -1
	depth_fittings.add_child(feeds)
	var lane := 0
	for line in map.get_node("CoreBundles").get_children():
		blockout_lines.append(line)
		var label := String(line.name)
		if not label.ends_with("Outer"):
			continue
		var copper := Color("b35d3e") if lane % 3 == 1 else Color("98482e")
		var width := 41.0 if lane % 2 == 0 else 44.0
		var lowered := DOWN * 45 + Vector2(0, 19)
		_ribbon(depth_fittings, label, _shape_tube(line.points, lowered, lane), width, copper, 82.0 + lane * 3, Tube.COPPER)
		if lane < 2:
			_ribbon(depth_fittings, label + "Rear", _shape_tube(line.points, -DOWN * 32, lane),
				width, copper.darkened(0.19), 103.0, Tube.COPPER)
		lane += 1
	for index in range(17):
		for side: int in [-1, 1]:
			var anchor := track + FORWARD * (250.0 + index * 630.0 + side * 75)
			var edge := DOWN * side
			# Both ends tuck into the primary bundle. The thinner return bends sit below it.
			var root := anchor + edge * (187.0 if side < 0 else 211.0)
			var spread := edge * (43.0 if index % 2 == 0 else 57.0)
			var end := root + FORWARD * (265.0 + index % 3 * 28.0)
			for channel in range(2):
				var gap := edge * channel * 14.0
				var points := _curved_path(PackedVector2Array([root + gap,
					root + FORWARD * 65.0 + spread + gap,
					end - FORWARD * 68.0 + spread + gap, end + gap]))
				_ribbon(feeds, "Feed%d_%d_%d" % [index, side, channel], points, 12.0 - channel * 2.0,
					Color("512027") if channel == 0 else Color("3c1b23"), 93.0, Tube.HOSE)

func _shape_tube(source: PackedVector2Array, offset: Vector2, lane: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var travel := 0.0
	for index in range(1, source.size()):
		var from := source[index - 1]
		var to := source[index]
		var length := from.distance_to(to)
		var steps := maxi(1, ceili(length / 39.0))
		for step in range(steps):
			var t := float(step) / steps
			var along := travel + length * t
			var contour := sin(along / 143.0) * 9.0 + sin(along / 51.0 + lane * 0.64) * 2.2
			points.append(from.lerp(to, t) + offset + DOWN * contour)
		travel += length
	points.append(source[-1] + offset + DOWN * (sin(travel / 143.0) * 9.0 + sin(travel / 51.0 + lane * 0.64) * 2.2))
	return points

func _curved_path(anchors: PackedVector2Array) -> PackedVector2Array:
	return _path_curve(anchors).get_baked_points()

func _path_curve(anchors: PackedVector2Array) -> Curve2D:
	var path := Curve2D.new()
	path.bake_interval = 12.0
	for index in range(anchors.size()):
		var before := anchors[maxi(0, index - 1)]
		var after := anchors[mini(anchors.size() - 1, index + 1)]
		var handle := (after - before) * 0.17
		path.add_point(anchors[index], -handle, handle)
	return path

func _build_shell() -> void:
	for part in map.get_node("Floors").get_children():
		var top: Polygon2D = part.get_node("Top")
		var branch := not String(part.name).begins_with("SpineSegment")
		var coat := Color("94736c")
		if part.name == &"BlueprintWing":
			coat = Color("806b69")
		elif part.name == &"DefenseSafeBay":
			coat = Color("78605a")
		elif part.name == &"ServiceCatwalk":
			coat = Color("50464b")
		elif part.name == &"ProtocolObservationBay":
			coat = Color("79696a")
		elif branch:
			coat = Color("695a61")
		var grated := part.name in [&"RecordBranch", &"ServiceCatwalk"]
		_paint(top, coat, 3 if grated else 0)
		_paint(part.get_node("Volume/Underside"), Color("422930"), 1)
		blockout_lines.append(top.get_node("Rim"))
		for seam in top.get_node("Ribs").get_children():
			blockout_lines.append(seam)
	rim_fittings = _group("RolledRims", 1)
	var cladding := Node2D.new()
	cladding.name = "ShellSkirts"
	cladding.z_index = 9
	depth_fittings.add_child(cladding)
	for boundary in map.get_node("Boundaries").get_children():
		_build_rim(boundary.get_node("Collision").polygon, cladding)
	for cover in map.get_node("Covers").get_children():
		_paint(cover.get_node("Volume/Side"), Color("4a2d2c"), 1)
		var coat := Color("70514b") if cover.name == &"DefenseBayShield" else Color("80625a")
		_paint(cover.get_node("Volume/Top"), coat, 0)
		blockout_lines.append(cover.get_node("Volume/Edge"))

func _build_rim(perimeter: PackedVector2Array, cladding: Node2D) -> void:
	var service_top: Polygon2D = map.get_node("Floors/ServiceCatwalk/Top")
	for i in range(perimeter.size()):
		var from := perimeter[i]
		var to := perimeter[(i + 1) % perimeter.size()]
		var length := from.distance_to(to)
		if length < 3.0:
			continue
		var edge := from.direction_to(to)
		var inside := Vector2(-edge.y, edge.x)
		var midpoint := (from + to) * 0.5
		if not map.is_walkable_point(midpoint + inside * 3.0):
			inside = -inside
		var beside_service := Geometry2D.is_point_in_polygon(
			service_top.to_local(map.to_global(midpoint + inside * 3.0)), service_top.polygon)
		var rims := service_rims if beside_service else rim_fittings
		var skirts := service_skirts if beside_service else cladding
		var count := maxi(1, roundi(length / 124.0))
		for section in range(count):
			var a := from.lerp(to, float(section) / count)
			var b := from.lerp(to, float(section + 1) / count)
			var bent := (i + section) % 5 == 1 or (i + section) % 5 == 2
			var lip := inside * (9.0 if bent else 5.0)
			# Front skirts project into the foreground, below the walking surface.
			if inside.y < -0.15 and a.distance_to(b) > 28.0:
				var drop := Vector2(5.0, 52.0 if bent else 18.0)
				var lower_a := a.lerp(b, 0.09) + drop
				var lower_b := b.lerp(a, 0.12) + drop * 0.75
				var shoulder := a.lerp(lower_a, 0.49)
				var heel := b.lerp(lower_b, 0.52)
				_shape(skirts, PackedVector2Array([a, b, heel, shoulder]), Color("74514c"), 1)
				_shape(skirts, PackedVector2Array([shoulder, heel, lower_b, lower_a]), Color("503337"), 1)
				_stroke(skirts, PackedVector2Array([shoulder, heel]), 1.0, Color("8e5b50"))
				_stroke(skirts, PackedVector2Array([lower_a, lower_b]), 3.0, Color("2f2028"))
				_stroke(skirts, PackedVector2Array([a.lerp(lower_a, 0.89), b.lerp(lower_b, 0.89)]), 2.0, Color("996b59"))
			_shape(rims, PackedVector2Array([a, b, b + lip, a + lip]), Color("957064"), 1)
			_stroke(rims, PackedVector2Array([a + inside, b + inside]), 2.0, Color("c59b7d"))
			if length > 24.0:
				for along in [0.17, 0.81]:
					var center := a.lerp(b, along) + inside * 3.0
					_shape(rims, _quad(center, edge, Vector2(4, 3)), Color("332e2b"))


func _build_fittings() -> void:
	var fixtures := _group("Fittings", 2)
	var paint := _group("RoutePaint", 1)
	var marks := map.get_node("Markers")
	for item in [["OptionalRecord", &"record"], ["ScatterEvolution", &"blueprint"],
			["BlueprintDuct", &"return_duct"], ["ExitTerminal", &"exit_console"]]:
		var mark: Node2D = marks.get_node(item[0])
		_interaction_fixture(fixtures, item[1], mark.position, FORWARD.angle()).name = mark.name
	var seam: Node2D = map.get_node("Reservations/ElectricFloor")
	_fixture(fixtures, "seam", seam.position, seam.rotation, seam.size).name = "ElectricSeam"
	for cover in map.get_node("Covers").get_children():
		if cover.name in [&"DefenseBayShield", &"ProtocolBayScreen", &"SpinalFluidPlinth"]:
			continue
		var top: Polygon2D = cover.get_node("Volume/Top")
		var center := (top.polygon[0] + top.polygon[2]) * 0.5
		if cover.name == &"BlockedRecordEnd":
			_fixture(fixtures, "barrier", center, FORWARD.angle(), Vector2(32, 144))
		else:
			var body: CollisionPolygon2D = cover.get_node("Body/Collision")
			var footprint := body.polygon
			var axis := footprint[0].direction_to(footprint[1])
			var size := Vector2(footprint[0].distance_to(footprint[1]),
				footprint[1].distance_to(footprint[2]))
			var foot := body.to_global((footprint[0] + footprint[2]) * 0.5)
			var kind := &"gate_cover" if cover.name == &"ProtocolGateCover" else &"valve"
			_interaction_fixture(fixtures, kind, fixtures.to_local(foot), axis.angle(), size).name = cover.name
			cover_blockouts.append(cover.get_node("Volume"))

	var spawn: Vector2 = marks.get_node("PlayerSpawn").position
	var exit: Vector2 = marks.get_node("ToThorax").position
	_build_entry_tunnel(spawn)
	_build_entry_defense(spawn)
	_build_protocol_dressing(marks)
	_build_spinal_fluid_tap(marks)
	_build_upper_lane_edges(spawn)
	_build_thorax_receiver(marks)
	_build_collars(spawn, exit)
	_build_route_paint(paint, "MainRoute", BRASS)
	_build_record_fork_paint()
	_build_route_paint(paint, "RecordRoute", BLUE)
	_build_route_paint(paint, "DuctRoute", BRASS)

func _build_spinal_fluid_tap(marks: Node) -> void:
	var dressing := _group("SpinalFluidStation", 2)
	var tap: Node2D = marks.get_node("SpinalFluidTap")
	var at := tap.position
	var pump_line: Line2D = get_node("ReturnVessels/Pump-1_9-1")
	var inlet := pump_line.points[0]
	var deck_edge := at - DOWN * 53.0
	var junction := inlet + FORWARD * 82.0 + DOWN * 38.0
	var pipe := _group("SpinalFluidFeed", -23)
	var path := PackedVector2Array([inlet, junction, junction + DOWN * 98.0,
		deck_edge - DOWN * 67.0 - FORWARD * 112.0, deck_edge - DOWN * 26.0, deck_edge])
	_ribbon(pipe, "PumpBranch", _curved_path(path), 22.0, Color("a15841"), 78.0, Tube.COPPER)
	var intake := at - FORWARD * 21.0 - DOWN * 30.0
	_ribbon(dressing, "TapInlet", _curved_path(PackedVector2Array([deck_edge,
		intake - DOWN * 18.0 + FORWARD * 3.0, intake])),
		13.0, Color("ae694a"), 38.0, Tube.COPPER)
	fluid_station = _interaction_fixture(dressing, &"fluid", at, tap.rotation, tap.footprint)
	fluid_station.name = "SpinalFluidTap"
	var operator: Vector2 = marks.get_node("SpinalFluidTapUse").position
	for side: float in [-1.0, 1.0]:
		var stripe := operator + FORWARD * side * 21.0
		_stroke(dressing, PackedVector2Array([stripe - DOWN * 8.0, stripe + DOWN * 8.0]),
			2.0, Color("b19779"))

func _build_upper_lane_edges(spawn: Vector2) -> void:
	var paint := _group("UpperLaneEdges", 1)
	for side: float in [-1.0, 1.0]:
		for distance: float in [8860.0, 9170.0, 9450.0, 9750.0, 10020.0, 10310.0]:
			var at := spawn + FORWARD * (distance - 96.0) + DOWN * side * 166.0
			_stroke(paint, PackedVector2Array([at, at + FORWARD * 150.0]), 3, Color("594344"))
			_stroke(paint, PackedVector2Array([at, at + FORWARD * 112.0]), 1.5, Color("a4866f"))

func _build_thorax_receiver(marks: Node) -> void:
	var body := _group("ThoraxReceiver", -8)
	var trim := _group("ThoraxThreshold", 1)
	var exit: Vector2 = marks.get_node("ToThorax").position
	var along := func(x: float, y: float) -> Vector2:
		return exit + FORWARD * x + DOWN * y
	_shape(body, PackedVector2Array([along.call(-32, -184), along.call(78, -247),
		along.call(243, -247), along.call(311, -189), along.call(311, 189),
		along.call(243, 247), along.call(78, 247), along.call(-32, 184)]), Color("38262e"), 1)
	_shape(body, _quad(exit + FORWARD * 137.0, FORWARD, Vector2(260, 291)), Color("1d151d"))
	_shape(body, _quad(exit + FORWARD * 153.0, FORWARD, Vector2(204, 236)), Color("2a1f28"))
	# These bevels sit below the playable landing edge and lead into the end wall.
	for side: float in [-1.0, 1.0]:
		var bevel := PackedVector2Array([along.call(40, side * 136), along.call(205, side * 136),
			along.call(236, side * 113), along.call(50, side * 113)])
		_shape(body, bevel, Color("4e323b"), 1)
		_stroke(body, PackedVector2Array([bevel[0], bevel[1], bevel[2]]), 2.0, Color("99705b"))
	for y: float in [-92.0, -46.0, 0.0, 46.0, 92.0]:
		var channel: Vector2 = along.call(153, y)
		_shape(body, _quad(channel, FORWARD, Vector2(188, 24)), Color("1c141c"))
		_stroke(body, PackedVector2Array([channel - FORWARD * 85.0 - DOWN * 12.0,
			channel + FORWARD * 91.0 - DOWN * 12.0]), 2, Color("4b323a"))
	for side: float in [-1.0, 1.0]:
		var shoulder := PackedVector2Array([along.call(-30, side * 141), along.call(72, side * 154),
			along.call(246, side * 154), along.call(279, side * 183),
			along.call(242, side * 222), along.call(79, side * 222)])
		_shape(body, shoulder, Color("694950"), 1)
		_stroke(body, PackedVector2Array([shoulder[0], shoulder[1], shoulder[2], shoulder[3]]),
			5, Color("b4846c"))
		for offset in [75.0, 138.0, 204.0]:
			var band: Vector2 = along.call(offset, side * 191)
			_shape(body, _quad(band, FORWARD, Vector2(18, 56)), Color("4e343d"), 1)
			_stroke(body, PackedVector2Array([band - DOWN * 23.0, band + DOWN * 23.0]), 2, BRASS)
		for lane: int in range(2):
			var lateral := side * (153.0 + lane * 35.0)
			var lead := PackedVector2Array([along.call(-118, lateral), along.call(-14, lateral),
				along.call(63, lateral + side * 17), along.call(194, lateral + side * 17),
				along.call(227, lateral)])
			_ribbon(body, "ReceiverFeed%d_%d" % [int(side), lane], _curved_path(lead),
				23.0, Color("a36046").darkened(float(lane) * 0.16), 58.0, Tube.COPPER)
		_fixture(body, "dock_flange", along.call(27, side * 165), FORWARD.angle(), Vector2(26, 80))
		for x in [9.0, 70.0, 149.0]:
			var lamp: Vector2 = along.call(x, side * 130)
			_shape(trim, _quad(lamp, FORWARD, Vector2(19, 9)), Color("382e33"))
			_shape(trim, _quad(lamp, FORWARD, Vector2(12, 4)), Color("dfa975"))
	var back: Vector2 = along.call(237, 0)
	_interaction_fixture(body, &"receiver_bulkhead", back, FORWARD.angle(), Vector2(61, 420))
	var landing_edge: Vector2 = along.call(37, 0)
	var lip := PackedVector2Array([landing_edge - DOWN * 125.0, landing_edge + DOWN * 125.0])
	var lower := Vector2(6, 24)
	_shape(trim, PackedVector2Array([lip[0], lip[1], lip[1] + lower, lip[0] + lower]), Color("32242d"))
	_stroke(trim, lip, 3, Color("a58170"))
	for side: float in [-1.0, 1.0]:
		_interaction_fixture(trim, &"receiver_latch", along.call(-6, side * 116), FORWARD.angle())
	var shutter: Node2D = marks.get_node("Door")
	exit_gate_skin = _interaction_fixture(trim, &"exit_gate", shutter.position,
		shutter.rotation, shutter.footprint)
	exit_gate_skin.name = "ExitGate"
	for distance in [-44.0, -20.0]:
		var point: Vector2 = along.call(distance, 0)
		_stroke(trim, PackedVector2Array([point - FORWARD * 10.0 - DOWN * 16.0,
			point, point - FORWARD * 10.0 + DOWN * 16.0]), 3.0, BRASS)

func _build_protocol_dressing(marks: Node) -> void:
	var hardware := _group("ProtocolFittings", 2)
	var terminal: Node2D = marks.get_node("ProtocolTerminal")
	protocol_console = _interaction_fixture(hardware, &"protocol_console", terminal.position, FORWARD.angle())
	protocol_console.name = terminal.name
	var demo: Node2D = marks.get_node("ProtocolDemoReader")
	demo_reader = _interaction_fixture(hardware, &"demo_reader", demo.position, FORWARD.angle())
	demo_reader.name = demo.name
	var reader: Node2D = marks.get_node("ProtocolGateReader")
	gate_reader = _interaction_fixture(hardware, &"gate_reader", reader.position, FORWARD.angle())
	gate_reader.name = reader.name
	var gate: Node2D = marks.get_node("AuthorizedDoor")
	authorization_skin = _interaction_fixture(hardware, &"authorization_gate", gate.position,
		gate.rotation, gate.footprint)
	authorization_skin.name = gate.name

	var screen: Polygon2D = map.get_node("Covers/ProtocolBayScreen/Volume/Top")
	var rail_start := (screen.polygon[0] + screen.polygon[5]) * 0.5
	var rail_end := (screen.polygon[1] + screen.polygon[4]) * 0.5
	var glass := _interaction_fixture(hardware, &"observation", rail_start.lerp(rail_end, 0.57),
		FORWARD.angle(), Vector2(192, 20))
	glass.name = "ObservationWindow"
	_stroke(hardware, screen.polygon, 2, Color("94766b"))

	var paint := _group("ProtocolFloorMarks", 1)
	for label in ["ProtocolYieldRear", "ProtocolYieldFront"]:
		var stop: Vector2 = marks.get_node(label).position
		var boundary := _quad(stop, FORWARD, Vector2(32, 26))
		_stroke(paint, PackedVector2Array([boundary[0], boundary[1], boundary[2]]), 2, Color("8d7560"))
		_stroke(paint, PackedVector2Array([boundary[2], boundary[3], boundary[0]]), 2, Color("8d7560"))
	var shelter: Vector2 = marks.get_node("ProtocolExit").position
	for side: float in [-1.0, 1.0]:
		var edge := shelter + DOWN * side * 26.0
		_stroke(paint, PackedVector2Array([edge - FORWARD * 46.0, edge - FORWARD * 18.0]),
			2.5, Color("b19874"))

func _build_entry_defense(spawn: Vector2) -> void:
	var fixtures := _group("EntranceFittings", 2)
	var feeds := _group("DefenseFeeds", -8)
	var shield: Polygon2D = map.get_node("Covers/DefenseBayShield/Volume/Top")
	var shield_edge := shield.polygon.duplicate()
	shield_edge.append(shield_edge[0])
	_stroke(fixtures, shield_edge, 2, Color("ae8069"))
	var marks := map.get_node("Markers")
	# The new service deck and its anchors use the same 25-degree axis as the spine.
	var at := func(distance: float, offset: float) -> Vector2:
		return spawn + FORWARD * (distance - 96.0) + DOWN * offset
	for side: int in [-1, 1]:
		var feed := PackedVector2Array([at.call(1160, side * 170), at.call(1250, side * 205),
			at.call(1530, side * 204), at.call(1790, side * 178), at.call(2020, side * 204),
			at.call(2130, side * 223), at.call(2220, side * 180)])
		_ribbon(feeds, "DefenseSupply%d" % side, _curved_path(feed), 23, Color("a35639"), 60, Tube.COPPER)

	for marker in marks.get_children():
		var role: String = marker.get_meta("role", "")
		if role == "wall_emitter":
			var muzzle := Vector2.from_angle(marker.rotation)
			var base: Vector2 = marker.position - muzzle * 25.0
			var relative: Vector2 = marker.position - spawn
			var distance := relative.dot(FORWARD) + 96.0
			var side := signf(relative.dot(DOWN))
			var supply: Vector2 = at.call(distance + 28, side * 196)
			var exposed := base + DOWN * side * 25.0
			_ribbon(feeds, marker.name + "Supply", _curved_path(PackedVector2Array([supply,
				supply - FORWARD * 20, exposed, base])), 15, Color("9e513a"), 42, Tube.COPPER)
			_ribbon(fixtures, marker.name + "Inlet", PackedVector2Array([exposed, base]),
				9, Color("8c553e"), 35, Tube.COPPER)
			_fixture(fixtures, "wall_emitter", marker.position, marker.rotation).name = marker.name
		elif role == "recessed_electrode":
			_fixture(fixtures, "ground_electrode", marker.position, marker.rotation, marker.footprint).name = marker.name
			var local_offset: Vector2 = marker.position - spawn
			var distance := local_offset.dot(FORWARD) + 96.0
			var lateral := local_offset.dot(DOWN)
			var side := -1.0 if lateral < 0.0 else 1.0
			var edge := 124.0 if distance < 1852.0 else 156.0
			var inlet: Vector2 = at.call(distance, side * edge)
			var conduit := PackedVector2Array([at.call(distance + 34, side * 192),
				at.call(distance + 9, side * (edge + 7.0)), inlet])
			_ribbon(feeds, marker.name + "Feed", _curved_path(conduit),
				11, Color("ad6947"), 43, Tube.COPPER)
			var lead := PackedVector2Array([inlet, marker.position + DOWN * side * marker.footprint.x * 0.46])
			_stroke(fixtures, lead, 9, Color("3c2c31"))
			_stroke(fixtures, lead, 3, Color("b77854"))

	var shutter: Node2D = marks.get_node("IsolationGate")
	_fixture(fixtures, "isolation_gate", shutter.position, shutter.rotation, shutter.footprint).name = shutter.name
	_build_service_passage(at, fixtures)

	var warnings := _group("DefenseWarningPaint", 1)
	for side: int in [-1, 1]:
		var rail := PackedVector2Array([at.call(1545, side * 117), at.call(1848, side * 117)])
		_stroke(warnings, rail, 9, Color("342830"))
		_stroke(warnings, rail, 3, Color("c19056"))
		for distance in range(1552, 1848, 28):
			_shape(warnings, _quad(at.call(distance, side * 118), FORWARD.rotated(PI * 0.25), Vector2(12, 5)), Color("d8a665"))
	var threshold := PackedVector2Array([at.call(1264, -96), at.call(1264, 96)])
	_stroke(warnings, threshold, 7, Color("4d3332"))
	for lateral in range(-92, 94, 16):
		_shape(warnings, _quad(at.call(1264, lateral), FORWARD.rotated(PI * 0.3), Vector2(10, 4)), Color("bf8d55"))

func _build_service_passage(at: Callable, bay_fixtures: Node2D) -> void:
	var fixtures := _group("Interior", 2, service_open)
	var feeds := _group("Pipes", -8, service_open)
	var marks := map.get_node("Markers")
	# The maintenance run follows a separate, darker low-pressure return line.
	var return_pipe := PackedVector2Array([at.call(1110, -473), at.call(1270, -465),
		at.call(1390, -455), at.call(1920, -455), at.call(2140, -455),
		at.call(2270, -418), at.call(2460, -368)])
	_ribbon(feeds, "ServiceReturn", _curved_path(return_pipe), 26, Color("73303a"), 78, Tube.VESSEL)
	for wall: Polygon2D in map.get_node("EntranceDefense/ServiceWalls").get_children():
		_paint(wall, Color("5b3d43"), 1)
		_stroke(fixtures, PackedVector2Array([wall.polygon[0], wall.polygon[1]]), 2, Color("8e615b"))
	# A partial roof reads as an enclosed service passage while leaving the walking line visible.
	var canopy := _group("Canopy", 1, service_open)
	for section in range(8):
		var length := 86.0 if section == 7 else 90.0
		var center: Vector2 = at.call(1422.0 + section * 92.0, -421)
		_shape(canopy, _quad(center + DOWN * 9.0, FORWARD, Vector2(length, 35)), Color("34252d"))
		var panel := _quad(center, FORWARD, Vector2(length, 27))
		_shape(canopy, panel, Color("634148"), 0)
		_stroke(canopy, PackedVector2Array([panel[2], panel[3]]), 2, Color("98685d"))
	var lamp_glow := GradientTexture2D.new()
	lamp_glow.gradient = Gradient.new()
	lamp_glow.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	lamp_glow.fill = GradientTexture2D.FILL_RADIAL
	lamp_glow.fill_from = Vector2(0.5, 0.5)
	lamp_glow.fill_to = Vector2(1.0, 0.5)
	lamp_glow.width = 64
	lamp_glow.height = 64
	for distance in [1438, 1534, 1630, 1818, 1914, 2010, 2106]:
		_service_lamp(fixtures, at.call(distance, -408), FORWARD.angle(), lamp_glow)
	_service_lamp(bay_fixtures, at.call(1305, -158), FORWARD.angle() + PI, lamp_glow)
	_service_lamp(fixtures, at.call(1310, -244), FORWARD.angle(), lamp_glow)
	_service_lamp(fixtures, at.call(2322, -269), FORWARD.angle() + PI * 0.5, lamp_glow)
	for key in ["MaintenanceHatch", "MaintenanceExit"]:
		var mark: Node2D = marks.get_node(key)
		_interaction_fixture(fixtures, &"service_threshold", mark.position,
			mark.rotation, mark.footprint).name = mark.name
		_interaction_fixture(service_covers, &"service_cover", mark.position,
			mark.rotation, mark.footprint).name = mark.name
	var hatch: Node2D = marks.get_node("MaintenanceHatch")
	_interaction_fixture(service_hint, &"service_hint", hatch.position, hatch.rotation, hatch.footprint)
	var checkpoint: Node2D = map.get_node("Checkpoints/ServiceExit")
	checkpoint_skin = _interaction_fixture(fixtures, &"checkpoint", checkpoint.position, FORWARD.angle())
	checkpoint_skin.name = "ServiceCheckpoint"

	var window: Node2D = marks.get_node("MaintenanceWindow")
	_fixture(fixtures, "inspection_window", window.position + DOWN * 30.0, FORWARD.angle(), window.footprint)


func _service_lamp(group: Node2D, position: Vector2, angle: float, texture: Texture2D) -> void:
	var mount := _fixture(group, "service_lamp", position, angle)
	var light := PointLight2D.new()
	light.position = Vector2(0, 16)
	light.texture = texture
	light.color = Color("edb682")
	light.energy = 0.44
	mount.add_child(light)

func _build_entry_tunnel(spawn: Vector2) -> void:
	var top: Polygon2D = map.get_node("Floors/SpineSegment00/Top")
	var near_edge := INF
	var left := INF
	var right := -INF
	for vertex in top.polygon:
		var point: Vector2 = map.to_local(top.to_global(vertex)) - spawn
		near_edge = minf(near_edge, point.dot(FORWARD))
		left = minf(left, point.dot(DOWN))
		right = maxf(right, point.dot(DOWN))
	var tunnel = ENTRY_TUNNEL.new()
	tunnel.position = spawn + FORWARD * near_edge + DOWN * ((left + right) * 0.5)
	tunnel.rotation = FORWARD.angle()
	_group("EntranceTunnel", 1).add_child(tunnel)
	tunnel.build((right - left) * 0.5)

func _build_collars(start: Vector2, end: Vector2) -> void:
	var shell := _group("CollarTops", 1)
	for index in range(1, 25):
		var center := start.lerp(end, float(index) / 25.0)
		var span := Vector2.ZERO
		for side: int in [-1, 1]:
			for distance in range(8, 209, 8):
				if not map.is_walkable_point(center + DOWN * side * distance):
					break
				if side < 0:
					span.x = distance
				else:
					span.y = distance
		if minf(span.x, span.y) < 82.0 or maxf(span.x, span.y) > 154.0:
			continue
		var rear := center - DOWN * span.x
		var front := center + DOWN * span.y
		var width := 37.0 if index % 3 else 52.0
		var front_foot := front + DOWN * 61.0 + Vector2(6, 21)
		var rear_foot := rear - DOWN * 26.0
		var outline := PackedVector2Array([rear_foot - FORWARD * width * 0.45, rear - FORWARD * width * 0.5,
			front - FORWARD * width * 0.5, front_foot - FORWARD * width * 0.38,
			front_foot + FORWARD * width * 0.34, front + FORWARD * width * 0.5,
			rear + FORWARD * width * 0.5, rear_foot + FORWARD * width * 0.40])
		_shape(depth_fittings, outline, Color("64424a"), 1)
		_stroke(depth_fittings, outline, 3.0, Color("33222a"))
		_stroke(depth_fittings, PackedVector2Array([front + FORWARD * width * 0.45,
			front_foot + FORWARD * width * 0.30, front_foot - FORWARD * width * 0.30]), 2.0, Color("ac806a"))
		var band := _quad(center + DOWN * (span.y - span.x) * 0.5, FORWARD,
			Vector2(width, span.x + span.y - 12))
		_shape(shell, band, Color("8b6a5d"), 1)
		_stroke(shell, PackedVector2Array([band[0], band[3]]), 2.0, Color("ad826f"))
		_stroke(shell, PackedVector2Array([band[1], band[2]]), 2.0, Color("583943"))
		for side: int in [-1, 1]:
			var shoulder := rear + DOWN * 13.0 if side < 0 else front - DOWN * 13.0
			_shape(shell, _quad(shoulder, FORWARD, Vector2(width - 11, 5)), Color("322e32"))
			_shape(shell, _quad(shoulder, FORWARD, Vector2(width - 18, 2)), Color("a48059"))

func make_door_skin(door: Node2D, authorized: bool) -> Node2D:
	var skin := authorization_skin if authorized else exit_gate_skin
	skin.track_door(door)
	return skin

func _interaction_fixture(group: Node2D, kind: StringName, at: Vector2,
		angle: float, span := Vector2.ZERO) -> INTERACTION_FIXTURE:
	var fixture := INTERACTION_FIXTURE.new()
	fixture.material = fixture_finish
	fixture.kind = kind
	fixture.position = at
	fixture.rotation = angle
	fixture.span = span
	group.add_child(fixture)
	return fixture

func _build_record_fork_paint() -> void:
	var group := _group("RecordForkPaint", 1)
	var fork := map.get_node("RouteWaypoints/RecordRoute")
	var junction: Vector2 = fork.get_node("Point00").position
	var into_branch := junction.direction_to(fork.get_node("Point01").position)
	var across := Vector2(-into_branch.y, into_branch.x)
	for distance: float in [45.0, 78.0]:
		var tip := junction + into_branch * distance
		var back := tip - into_branch * 13.0
		var arrow := PackedVector2Array([back + across * 15.0, tip, back - across * 15.0])
		_stroke(group, arrow, 9.0, Color("394650"))
		_stroke(group, arrow, 4.0, BLUE.lightened(0.19))
	# Carry the deck markings across the throat of the exposed grate.
	for side: float in [-1.0, 1.0]:
		var edge := across * (31.0 * side)
		var stripe := PackedVector2Array([junction + into_branch * 145.0 + edge,
			junction + into_branch * 187.0 + edge])
		_stroke(group, stripe, 7.0, Color("3f4c56"))
		_stroke(group, stripe, 2.5, BLUE)

func _build_route_paint(group: Node2D, route: String, color: Color) -> void:
	var waypoints := map.get_node("RouteWaypoints/" + route).get_children()
	for i in range(1, waypoints.size()):
		var from: Vector2 = waypoints[i - 1].position
		var to: Vector2 = waypoints[i].position
		var direction := from.direction_to(to)
		var count := maxi(1, roundi(from.distance_to(to) / 225.0))
		for j in range(count):
			var center := from.lerp(to, (j + 0.5) / count)
			var advance := (center - Vector2(waypoints[0].position)).dot(FORWARD)
			var near_fixture := center.distance_squared_to(map.get_node("Reservations/ElectricFloor").position) < 150.0 * 150.0
			for marker in map.get_node("Markers").get_children():
				if marker.position.distance_squared_to(center) < 72.0 * 72.0:
					near_fixture = true
					break
			if near_fixture or not map.is_walkable_point(center):
				continue
			for offset in [-6.0, 6.0]:
				var tip: Vector2 = center + direction * offset
				var lateral := Vector2(-direction.y, direction.x)
				_stroke(group, PackedVector2Array([tip - direction * 8 + lateral * 10, tip,
					tip - direction * 8 - lateral * 10]), 3.0, color)
			if route == "RecordRoute":
				var reverse := center - direction * 16.0
				var lateral := Vector2(-direction.y, direction.x)
				_stroke(group, PackedVector2Array([reverse + direction * 7.0 + lateral * 8.0, reverse,
					reverse + direction * 7.0 - lateral * 8.0]), 2.0, color.darkened(0.17))
				continue
			if route == "MainRoute" and advance >= 8550.0 and advance < 10480.0:
				continue
			for side: int in [-1, 1]:
				var grate_center: Vector2 = center + DOWN * side * 55
				var grate := _quad(grate_center, direction, Vector2(46, 17))
				var fits := true
				for corner in grate:
					if not map.is_walkable_point(corner):
						fits = false
				if fits:
					_shape(group, grate, Color("4b4d51"), 3)
					_stroke(group, PackedVector2Array([grate[0], grate[1]]), 2.0, Color("888078"))

func _fixture(group: Node2D, kind: String, at: Vector2, angle := 0.0, span := Vector2.ZERO) -> Node2D:
	var fixture = FIXTURE.new()
	fixture.kind = kind
	fixture.position = at
	fixture.rotation = angle
	fixture.span = span
	fixture.arc_preview = kind == "seam" and arc_preview
	group.add_child(fixture)
	return fixture

func _quad(center: Vector2, axis: Vector2, size: Vector2) -> PackedVector2Array:
	var x := axis * size.x * 0.5
	var y := Vector2(-axis.y, axis.x) * size.y * 0.5
	return PackedVector2Array([center - x - y, center + x - y, center + x + y, center - x + y])

func _shape(group: Node2D, polygon: PackedVector2Array, paint: Color, finish := -1) -> void:
	var face := Polygon2D.new()
	face.polygon = polygon
	face.color = paint
	if finish >= 0:
		face.material = metal[finish]
	group.add_child(face)

func _stroke(group: Node2D, points: PackedVector2Array, width: float, paint: Color) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = paint
	line.joint_mode = Line2D.LINE_JOINT_BEVEL
	group.add_child(line)
