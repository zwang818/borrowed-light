extends Node2D
## A-only solid-form preview. Door keys never implement C's authorization or unlock state.
const DOOR = preload("res://tests/manual/a_map/preview_door.gd")
const HAZARDS = preload("res://tests/manual/a_map/spine_hazard_preview.gd")
const PROTOCOL_PREVIEW = preload("res://tests/manual/a_map/spine_protocol_preview.gd")
var _font := SystemFont.new()
const METRICS = preload("res://scenes/levels/graybox/graybox_metrics.gd")
enum TestDoor { PROTOCOL, EXIT, ISOLATION }
const DOOR_NAMES := ["AuthorizedDoor", "Door", "IsolationGate"]
const DOOR_LABELS := ["协议门", "出口门", "隔离闸"]
const PASSAGE_LABELS := ["封板隐藏", "盖板亮起", "暗道已打开"]
@onready var map: Node2D = $Map
@onready var actor: CharacterBody2D = $Actor
var doors: Array[Node2D] = []
var door_skins: Array[Node2D] = []
var selected_door := 0
var _overview := false
var _dark := false
var follow_zoom := 0.55
var _guides: Node2D
var _status: Label
var _hazards: Node2D
var _protocol_preview: Node2D
var _hazard_hits := 0
var _last_hazard := ""
var _hit_flash := 0.0

func _ready() -> void:
	_font.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "WenQuanYi Zen Hei"])
	DisplayServer.window_set_title("借光 · 斜向脊柱 · 2D环境预览")
	RenderingServer.set_default_clear_color(Color("10191f"))
	actor.position = map.get_node("Markers/PlayerSpawn").position
	actor.get_node("Lamp").visible = false
	for name in DOOR_NAMES:
		var marker := map.get_node("Markers/" + name)
		var door := Node2D.new()
		door.set_script(DOOR)
		door.name = "Test" + name
		door.position = marker.position
		door.rotation = marker.rotation
		door.size = marker.footprint
		var body := StaticBody2D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape2D.new()
		collider.name = "Collision"
		body.add_child(collider)
		door.add_child(body)
		var shadow := LightOccluder2D.new()
		shadow.name = "Occluder"
		door.add_child(shadow)
		add_child(door)
		door.z_index = 4
		doors.append(door)
		var art := map.get_node("SpineArt")
		var fitting := art.get_node_or_null("EntranceFittings/" + name)
		if fitting != null:
			fitting.track_door(door)
			door_skins.append(fitting)
		else:
			door_skins.append(art.make_door_skin(door, name == "AuthorizedDoor"))
	var seam: Node2D = map.get_node("SpineArt/Fittings/ElectricSeam")
	seam.arc_preview = false
	seam.set_process(false)
	_hazards = HAZARDS.new()
	_hazards.name = "EntranceHazards"
	_hazards.configure(map, actor)
	_hazards.actor_hit.connect(_on_hazard_hit)
	add_child(_hazards)
	_protocol_preview = PROTOCOL_PREVIEW.new()
	_protocol_preview.name = "ProtocolSignalPreview"
	_protocol_preview.configure(map, actor)
	add_child(_protocol_preview)
	_build_guides()
	_set_guides_visible(false)
	_set_art_visible(true)
	_build_ui()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	_update_status()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_guides() -> void:
	_guides = Node2D.new()
	_guides.z_index = 20
	add_child(_guides)
	for group in map.get_node("RouteWaypoints").get_children():
		var line := Line2D.new()
		for point in group.get_children():
			line.add_point(map.to_global(point.position))
		line.width = 3
		line.default_color = Color(0.85, 0.74, 0.45, 0.65) if group.name == "MainRoute" else Color(0.64, 0.71, 0.85, 0.7)
		_guides.add_child(line)
	for anchor in map.get_node("GuideLabels").get_children():
		var label := _label(str(anchor.get_meta("text")), 22)
		label.position = anchor.position
		label.modulate = Color("d7e2e6")
		_guides.add_child(label)
	for marker in map.get_node("Markers").get_children():
		if marker.object_type in ["sentry", "cleaner"]:
			var label := _label("哨机" if marker.object_type == "sentry" else "清扫者", 16)
			label.position = marker.position + Vector2(-20, 18)
			label.modulate = Color("e3a394")
			_guides.add_child(label)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := ColorRect.new()
	ui.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 90
	top.color = Color("17232b")
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("第二关 · 脊柱输能区 · 环境预览", 23)
	title.position = Vector2(20, 10)
	ui.add_child(title)
	var detail := _label("左下进入 → 右上离开｜镜头缩放0.55｜角色占地与第一关一致", 15)
	detail.position = Vector2(20, 46)
	ui.add_child(detail)
	var bottom := ColorRect.new()
	ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -108
	bottom.color = Color("17232b")
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var controls := _label("WASD 移动 · Tab 全图 · G 标记 · L 遮光 · R 回入口\nF 美术／灰盒 · H 侧壁／管束 · V 碰撞 · 1–3 选门 · P 开关 · 滚轮缩放", 15)
	ui.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.position = Vector2(20, get_viewport_rect().size.y - 100)
	_status = _label("", 14)
	ui.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_left = 20
	_status.offset_top = -48
	var note := _label("K 模拟通讯揭示盖板 · 靠近亮缝按 E 打开暗道 · 1/2/3 协议门／出口门／隔离闸", 14)
	ui.add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	note.offset_left = 20
	note.offset_top = -25

func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var bounds: Rect2 = map.get_meta("map_bounds")
	if _overview:
		var fit := minf((view.x - 64) / bounds.size.x, (view.y - 230) / bounds.size.y)
		$Camera.zoom = Vector2.ONE * maxf(0.05, fit)
		$Camera.position = map.to_global(bounds.get_center())
	else:
		$Camera.zoom = Vector2.ONE * follow_zoom
		$Camera.position = actor.global_position + Vector2(120, -56)
	for child in _guides.get_children():
		if child is Label:
			child.scale = Vector2.ONE * (0.55 / $Camera.zoom.x) if _overview else Vector2.ONE
	$Camera.reset_smoothing()

func set_overview(value: bool) -> void:
	_overview = value
	_fit_camera()

func toggle_selected_door() -> bool:
	var door := doors[selected_door]
	if door.is_open and Rect2(-door.size * 0.5, door.size).grow(METRICS.BODY_RADIUS + 2).has_point(door.to_local(actor.global_position)):
		_status.text = "门洞有人，请离开后再关门"
		return false
	door.set_open(not door.is_open)
	_update_status()
	return true

func _update_status() -> void:
	var door_state := "已打开" if doors[selected_door].is_open else "关闭"
	_status.text = "%s（%s） · %s · 机关命中 %d %s" % [
		DOOR_LABELS[selected_door], door_state, PASSAGE_LABELS[map.service_passage_state],
		_hazard_hits, _last_hazard]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB:
			set_overview(not _overview)
		KEY_G:
			_set_guides_visible(not _guides.visible)
		KEY_F:
			_set_art_visible(not map.get_node("SpineArt").enabled)
		KEY_L:
			_dark = not _dark
			$Darkness.color = Color(0.25, 0.29, 0.33) if _dark else Color.WHITE
			actor.get_node("Lamp").visible = _dark
		KEY_R:
			actor.position = map.get_node("Markers/PlayerSpawn").position
			actor.velocity = Vector2.ZERO
			doors[TestDoor.ISOLATION].set_open(false)
			_hazards.reset_motion()
			_hazard_hits = 0
			_last_hazard = ""
			_hit_flash = 0.0
			actor.modulate = Color.WHITE
			map.set_service_passage_state(map.ServicePassage.CONCEALED)
			_fit_camera()
			_update_status()
		KEY_K:
			if map.service_passage_state == map.ServicePassage.CONCEALED:
				map.set_service_passage_state(map.ServicePassage.REVEALED)
				_update_status()
		KEY_E:
			var hatch: Node2D = map.get_node("Markers/MaintenanceHatch")
			if map.service_passage_state == map.ServicePassage.REVEALED and \
					actor.global_position.distance_to(hatch.global_position) <= float(hatch.get_meta("interaction_range")):
				map.set_service_passage_state(map.ServicePassage.OPEN)
				_update_status()
		KEY_1, KEY_2, KEY_3:
			selected_door = event.physical_keycode - KEY_1
			_update_status()
		KEY_P:
			toggle_selected_door()
		KEY_H:
			map.set_depth_enabled(not map.depth_enabled)
		KEY_V:
			map.get_node("BoundaryDebug").visible = not map.get_node("BoundaryDebug").visible
	get_viewport().set_input_as_handled()

func _set_guides_visible(value: bool) -> void:
	_guides.visible = value
	map.get_node("Reservations").visible = value
	for marker in map.get_node("Markers").get_children():
		marker.show_guide = value

func _set_art_visible(value: bool) -> void:
	map.get_node("SpineArt").set_art_enabled(value)
	_protocol_preview.visible = value
	for index in range(doors.size()):
		doors[index].self_modulate.a = 0.0 if value else 1.0
		door_skins[index].visible = value

func _on_hazard_hit(device: String) -> void:
	_hazard_hits += 1
	_last_hazard = device
	_hit_flash = 0.24
	actor.modulate = Color("ff9d8a")
	_update_status()

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		if _hit_flash == 0.0:
			actor.modulate = Color.WHITE
	if not _overview:
		$Camera.position = actor.global_position + Vector2(120, -56)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _overview:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: follow_zoom = minf(1.1, follow_zoom + 0.05)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: follow_zoom = maxf(0.4, follow_zoom - 0.05)
		_fit_camera()
