extends Node2D
## A-only map inspection. No enemy AI, pickups, terminal business or progress logic.
const Metrics = preload("res://scenes/levels/graybox/graybox_metrics.gd")
const PreviewFont = preload("res://tests/manual/a_map/assets/graybox_labels.ttf")
const TYPE_LABELS := {"spawn": "出生", "weapon": "脉冲枪", "sentry": "哨机", "cleaner": "清扫者", "log": "接口图纸", "terminal": "出口终端", "door": "测试门", "light": "固定灯", "exit": "往返入口"}
@onready var map: Node2D = $Map
@onready var actor: CharacterBody2D = $Actor
@onready var door: Node2D = $TestDoor
var _door_status: Label
var _mode_status: Label
var _region_status: Label
var _guides: Node2D
var _dark := false
var _show_guides := true
var _overview := false

func _ready() -> void:
	DisplayServer.window_set_title("借光 · 腹腔纵向灰盒预览")
	RenderingServer.set_default_clear_color(Color("10191f"))
	actor.position = map.get_node("Markers/PlayerSpawn").position
	actor.get_node("Lamp").visible = false
	door.position = map.get_node("Markers/Door").position
	door.size = map.get_node("Markers/Door").footprint
	_build_guides()
	_build_ui()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	_update_status()
	print("A_MAP_PREVIEW_V2: approved vertical layout; three cleaner MARKERS, no combat; Tab overview")

func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var bounds: Rect2 = map.get_meta("map_bounds")
	if _overview:
		var fit := maxf(0.08, minf((view.x - 64) / bounds.size.x, (view.y - 284) / bounds.size.y))
		$Camera.zoom = Vector2.ONE * fit
		$Camera.position = map.to_global(bounds.get_center()) + Vector2(0, 12.0 / fit)
	else:
		$Camera.zoom = Vector2.ONE * 1.1
		$Camera.position = actor.global_position + Vector2(0, 12.0 / 1.1)
	$Camera.reset_smoothing()

func set_overview(value: bool) -> void:
	_overview = value
	_fit_camera()
	_update_status()

func _label(text: String, font_size: int = 18) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", PreviewFont)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color("cbd4d8"))
	result.add_theme_color_override("font_shadow_color", Color("111a20"))
	result.add_theme_constant_override("shadow_offset_x", 1)
	result.add_theme_constant_override("shadow_offset_y", 1)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _build_guides() -> void:
	_guides = Node2D.new()
	_guides.z_index = 20
	add_child(_guides)
	for path in map.get_node("RouteWaypoints").get_children():
		var route := Line2D.new()
		for point in path.get_children():
			route.add_point(map.to_global(point.position))
		route.width = 2
		route.default_color = Color(0.72, 0.66, 0.44, 0.34)
		_guides.add_child(route)
	for anchor in map.get_node("GuideLabels").get_children():
		var label := _label(str(anchor.get_meta("text")), 22)
		label.position = map.to_global(anchor.position)
		label.modulate = Color("a2b2b8")
		_guides.add_child(label)
	for marker in map.get_node("Markers").get_children():
		if marker.object_type in ["exit", "light"] or marker.name in ["ReturnEntry", "LandingEntry", "WorkshopReturnEntry", "WorkshopEntry"]:
			continue
		var label := _label(TYPE_LABELS[marker.object_type], 15)
		label.position = map.to_global(marker.position) + Vector2(-18, 20)
		_guides.add_child(label)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	var root := Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := ColorRect.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 108
	top.color = Color("17232b")
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("借光 · 腹腔／制造区 · 概念版灰盒", 24)
	title.position = Vector2(24, 12)
	root.add_child(title)
	var subtitle := _label("由下向上：安全教学 → 取枪 → 首战 → 安全制造室 → 出口双敌", 15)
	subtitle.position = Vector2(24, 48)
	root.add_child(subtitle)
	var scale_label := _label("A 地图测试｜清扫者与图纸均为标记｜临时 1T = %d，角色占地直径 %d" % [Metrics.UNIT, Metrics.BODY_RADIUS * 2], 14)
	scale_label.position = Vector2(24, 78)
	root.add_child(scale_label)
	var bottom := ColorRect.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -140
	bottom.color = Color("17232b")
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	root.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	stack.offset_top = -132
	stack.offset_left = 24
	stack.offset_right = -20
	stack.add_theme_constant_override("separation", 0)
	stack.add_child(_label("WASD / 方向键：移动   Tab：全图／跟随   P：测门   L：明暗   G：标记   R：回入口", 15))
	_door_status = _label("", 14)
	stack.add_child(_door_status)
	_region_status = _label("", 14)
	stack.add_child(_region_status)
	_mode_status = _label("", 14)
	stack.add_child(_mode_status)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB:
			set_overview(not _overview)
		KEY_P:
			if door.is_open and Rect2(door.position - door.size * 0.5, door.size).grow(Metrics.BODY_RADIUS + 2).has_point(actor.position):
				_door_status.text = "门洞有人，暂不关闭；请先离开门洞"
				return
			door.set_open(not door.is_open)
		KEY_L:
			_dark = not _dark
			actor.get_node("Lamp").visible = _dark
			$Darkness.color = Color(0.25, 0.29, 0.33) if _dark else Color.WHITE
		KEY_G:
			_show_guides = not _show_guides
			_guides.visible = _show_guides
			for marker in map.get_node("Markers").get_children():
				marker.show_guide = _show_guides
		KEY_R:
			actor.position = map.get_node("Markers/PlayerSpawn").position
			actor.velocity = Vector2.ZERO
			_fit_camera()
	_update_status()
	get_viewport().set_input_as_handled()

func _update_status() -> void:
	_door_status.text = "出口门：打开，可到脊柱落点后返回" if door.is_open else "出口门：关闭；P 仅切换测试门，未接终端或击杀条件"
	var mode := "全图查看" if _overview else "角色跟随"
	var light_mode := "阴影检查" if _dark else "明亮检查"
	_mode_status.text = mode + " · " + light_mode + "｜战斗、真实可见性、安全区与进度待 B/C 接入"

func _process(_delta: float) -> void:
	if not _overview:
		$Camera.position = actor.global_position + Vector2(0, 12.0 / 1.1)
	var actor_local := map.to_local(actor.global_position)
	var region := "通路"
	if actor_local.y < 192:
		region = "脊柱入口落点"
	elif map.get_node("Rooms/Workshop").polygon.size() > 0 and Geometry2D.is_point_in_polygon(actor_local, map.get_node("Rooms/Workshop").polygon):
		region = "安全制造室（无敌人摆放；正式安全规则待接入）"
	elif actor_local.y >= 2016:
		region = "安全教学区"
	elif actor_local.y >= 1728:
		region = "取枪区"
	elif actor_local.y >= 1440:
		region = "首战区（清扫者标记 ×1）"
	elif actor_local.y >= 640:
		region = "机械肋骨转折通路"
	else:
		region = "出口区（清扫者标记 ×2）"
	_region_status.text = "当前区域：" + region
