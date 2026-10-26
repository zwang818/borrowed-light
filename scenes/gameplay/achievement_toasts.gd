extends CanvasLayer
## This root-level UI survives room and title scene changes.

const UI_THEME := preload("res://scenes/gameplay/gameplay_ui_theme.tres")

var display_seconds := 3.0
var _queue: Array[Dictionary] = []
var _seen: Dictionary = {}
var _active_id := ""
var _host: Control
var _card: PanelContainer
var _title: Label
var _description: Label
var _progress: Label
var _slide := 0.0
var _animation: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_host = Control.new()
	_host.theme = UI_THEME
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	_host.resized.connect(_place_card)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(380, 116)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.98)
	style.border_color = Color(0.35, 0.65, 0.65)
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_card.add_theme_stylebox_override("panel", style)
	_host.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card.add_child(row)
	var icon := Label.new()
	icon.text = "◆"
	icon.custom_minimum_size.x = 42
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 34)
	icon.add_theme_color_override("font_color", Color(0.96, 0.83, 0.49))
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	var caption := _label("成就已解锁", 12, Color(0.53, 0.83, 0.79))
	details.add_child(caption)
	_title = _label("", 19, Color(1, 0.91, 0.7))
	details.add_child(_title)
	_description = _label("", 13, Color(0.81, 0.86, 0.86))
	details.add_child(_description)
	_progress = _label("", 12, Color(0.55, 0.66, 0.68))
	details.add_child(_progress)
	_ignore_mouse(_host)
	_card.hide()
	_show_next()


func show_achievement(id: String, definition: Dictionary, completed: int, total: int) -> void:
	if _seen.has(id):
		return
	_seen[id] = true
	_queue.append({"id": id, "title": definition.title, "description": definition.description, "completed": completed, "total": total})
	if is_node_ready() and _active_id.is_empty():
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_active_id = ""
		_card.hide()
		return
	var entry: Dictionary = _queue.pop_front()
	_active_id = entry.id
	_title.text = entry.title
	_description.text = entry.description
	_progress.text = "%d / %d 项成就完成" % [entry.completed, entry.total]
	_card.show()
	_card.modulate.a = 0.0
	_slide = 16.0
	_place_card()
	_animation = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animation.set_parallel(true)
	_animation.tween_property(_card, "modulate:a", 1.0, 0.22)
	_animation.tween_method(_set_slide, 16.0, 0.0, 0.22)
	_animation.chain().tween_interval(display_seconds)
	_animation.chain().tween_property(_card, "modulate:a", 0.0, 0.22)
	_animation.chain().tween_callback(_show_next)


func _set_slide(value: float) -> void:
	_slide = value
	_place_card()


func _place_card() -> void:
	if not is_instance_valid(_card):
		return
	_card.size = _card.get_combined_minimum_size()
	_card.position = _host.size - _card.size - Vector2(20, 20) + Vector2(0, _slide)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
