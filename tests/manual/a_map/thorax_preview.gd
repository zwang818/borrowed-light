extends Node2D
## F6 inspection for the map art and local lighting.
const LABEL_FONT = preload("res://assets/fonts/lxgw_wenkai.ttf")
const FOLLOW_ZOOM := 1.5
const CAMERA_MARGIN := 64
const ROUTE_LEFT := Color("8bbbd7")
const ROUTE_RIGHT := Color("b5a9db")
const ROUTE_CENTER := Color("e9c887")

@onready var map: Node2D = $Map
@onready var actor: CharacterBody2D = $Actor
@onready var lighting: Node2D = $Map/Lighting
@onready var camera: Camera2D = $Camera
@onready var status: Label = %Status
@onready var spawn: Marker2D = $Map/Markers/PlayerSpawn

var _overview := false
var _inspection := false
var _nearby_switch: Marker2D
var _guide_labels: Array[Label] = []

func _ready() -> void:
	DisplayServer.window_set_title("借光 · 胸腔场景")
	RenderingServer.set_default_clear_color(Color("090c19"))
	$Overlay/Panel/Margin/Rows/Controls.add_theme_font_override("font", LABEL_FONT)
	status.add_theme_font_override("font", LABEL_FONT)
	_build_guides()
	var bounds: Rect2 = map.get_meta("map_bounds")
	camera.limit_left = int(bounds.position.x) - CAMERA_MARGIN
	camera.limit_top = int(bounds.position.y) - CAMERA_MARGIN
	camera.limit_right = int(bounds.end.x) + CAMERA_MARGIN
	camera.limit_bottom = int(bounds.end.y) + CAMERA_MARGIN
	get_viewport().size_changed.connect(_update_camera)
	_reset()

func _build_guides() -> void:
	for route in map.get_node("RouteWaypoints").get_children():
		var path := PackedVector2Array()
		for point in route.get_children():
			path.append(point.position)
		var route_name := String(route.name)
		var color := ROUTE_CENTER
		if route_name.begins_with("Left"):
			color = ROUTE_LEFT
		elif route_name.begins_with("Right"):
			color = ROUTE_RIGHT
		_add_guide_line(path, color, 4.0)
	var deck: Polygon2D = map.get_node("Floors/Deck")
	_add_collision_guide(deck)
	for body in map.get_node("Facilities").get_children():
		_add_collision_guide(body)
	for marker in map.get_node("Markers").get_children():
		if marker.get_meta("role", "") == "light_switch":
			_add_guide_label("电闸", marker.position + Vector2(14, 16))
	_set_guides(false)

func _add_collision_guide(body: Polygon2D) -> void:
	var boundary := body.polygon.duplicate()
	boundary.append(boundary[0])
	_add_guide_line(boundary, Color(0.55, 0.7, 0.85, 0.65), 2.5)

func _add_guide_line(points: PackedVector2Array, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	$Guides.add_child(line)

func _add_guide_label(caption: String, position_in_map: Vector2) -> void:
	var label := Label.new()
	label.text = caption
	label.position = position_in_map
	label.add_theme_font_override("font", LABEL_FONT)
	label.add_theme_color_override("font_shadow_color", Color("141b30"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	$Guides.add_child(label)
	_guide_labels.append(label)

func _set_guides(value: bool) -> void:
	$Guides.visible = value
	map.get_node("Reservations").visible = value
	for marker in map.get_node("Markers").get_children():
		marker.show_guide = value

func _update_camera() -> void:
	var focus := actor.global_position
	var target_zoom := FOLLOW_ZOOM
	if _overview:
		var bounds: Rect2 = map.get_meta("map_bounds")
		var view := (get_viewport_rect().size - Vector2(24, 84)).max(Vector2.ONE)
		target_zoom = minf(view.x / bounds.size.x, view.y / bounds.size.y)
		focus = map.to_global(bounds.get_center()) + Vector2(0, 32.0 / target_zoom)
	camera.limit_enabled = not _overview
	camera.position_smoothing_enabled = not _overview
	camera.zoom = Vector2.ONE * target_zoom
	camera.global_position = focus
	camera.reset_smoothing()
	for label in _guide_labels:
		label.scale = Vector2.ONE / camera.zoom.x

func _physics_process(_delta: float) -> void:
	if not _overview:
		camera.global_position = actor.global_position
	var nearby: Marker2D = lighting.switch_near(actor.global_position)
	if _nearby_switch != nearby:
		_nearby_switch = nearby
		_update_status()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB:
			_overview = not _overview
			_update_camera()
		KEY_L:
			_inspection = not _inspection
			lighting.set_inspection_mode(_inspection)
		KEY_E:
			lighting.pull_switch(actor.global_position)
		KEY_G:
			_set_guides(not $Guides.visible)
		KEY_R:
			_reset()
		_:
			return
	_update_status()
	get_viewport().set_input_as_handled()

func _reset() -> void:
	actor.position = spawn.position
	actor.velocity = Vector2.ZERO
	_overview = false
	_nearby_switch = null
	lighting.reset_lighting()
	_update_camera()
	_update_status()

func _update_status() -> void:
	var view := "全图" if _overview else "跟随"
	var mode := "明亮检查" if _inspection else "玩家暗场"
	var message := mode + " · " + view
	if is_instance_valid(_nearby_switch):
		message += "    区域灯已亮" if lighting.is_switch_on(_nearby_switch.object_id) else "    E 拉下照明电闸"
	status.text = message
