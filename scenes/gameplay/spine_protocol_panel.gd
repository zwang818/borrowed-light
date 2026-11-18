extends CanvasLayer
signal submitted
signal closed

const DIRECTIONS := preload("res://scenes/gameplay/spine_protocol_rail.gd").DIRECTIONS
const CELL := 78.0
const CYAN := Color("9aebd9")
const AMBER := Color("d6ac6e")

var calibrated := false
var expected: Array[int] = []
var expected_stop := 0
var initial_stop := 0
var board_angle := 0.0
var directions: Array[int] = []
var cells: Array[Button] = []
var stop_picker: OptionButton
var status: Label
var rejected := -1
var closing := false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	if calibrated:
		directions.assign(expected)
	elif directions.size() != expected.size():
		directions.resize(expected.size())

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = preload("res://scenes/gameplay/spine_flow_theme.tres")
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color("080d11d9")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.add_theme_stylebox_override("panel", _style(Color("1b282d"), Color("536f70")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "清扫者的路线"
	title.add_theme_color_override("font_color", CYAN)
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var instructions := Label.new()
	instructions.text = "从起点开始，记录 %d 段方向和中间的停靠点。" % expected.size()
	box.add_child(instructions)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	box.add_child(slots)
	for index in range(expected.size()):
		var tile := Button.new()
		tile.custom_minimum_size = Vector2.ONE * CELL
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("normal", _style(Color("283938"), Color("43615e")))
		tile.add_theme_stylebox_override("hover", _style(Color("38504b"), Color("7faba1")))
		tile.add_theme_stylebox_override("pressed", _style(Color("435b50"), AMBER))
		tile.pressed.connect(_rotate.bind(index))
		tile.draw.connect(_draw_tile.bind(index))
		tile.tooltip_text = "切换第 %d 段方向" % (index + 1)
		slots.add_child(tile)
		cells.append(tile)

	var stop_row := HBoxContainer.new()
	stop_row.add_theme_constant_override("separation", 12)
	box.add_child(stop_row)
	var stop_label := Label.new()
	stop_label.text = "中间停靠"
	stop_row.add_child(stop_label)
	stop_picker = OptionButton.new()
	stop_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_picker.add_item("选择停靠点", 0)
	for segment in range(1, expected.size()):
		stop_picker.add_item("第 %d 段后" % segment, segment)
	stop_picker.select(expected_stop if calibrated else initial_stop)
	stop_row.add_child(stop_picker)

	status = Label.new()
	status.text = "按下方向格可切换箭头。"
	box.add_child(status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_button(actions, "检测路线", _send)
	_button(actions, "返回观察", _close)
	cells[0].grab_focus()

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)

func _rotate(index: int) -> void:
	directions[index] = (directions[index] + 1) % DIRECTIONS.size()
	if rejected >= 0:
		cells[rejected].queue_redraw()
		rejected = -1
		status.text = "已更新方向，重新检测。"
		status.modulate = Color.WHITE
	cells[index].queue_redraw()

func _draw_tile(index: int) -> void:
	var tile := cells[index]
	var center := tile.size * 0.5 + Vector2(0, 7)
	var axis: Vector2 = DIRECTIONS[directions[index]].rotated(board_angle)
	var tip := center + axis * 16.0
	var wing := axis.orthogonal() * 7.0
	var color := AMBER if rejected == index else CYAN
	tile.draw_string(tile.get_theme_default_font(), Vector2(9, 19), str(index + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("afc2bc"))
	tile.draw_line(center - axis * 17.0, tip, color, 4.0)
	tile.draw_polyline(PackedVector2Array([tip - axis * 10.0 + wing, tip, tip - axis * 10.0 - wing]), color, 4.0)

func _send() -> void:
	for index in range(expected.size()):
		if directions[index] != expected[index]:
			rejected = index
			status.text = "第 %d 段与清扫者的方向不匹配。" % (index + 1)
			status.modulate = AMBER
			cells[index].queue_redraw()
			cells[index].grab_focus()
			return
	if stop_picker.get_selected_id() != expected_stop:
		status.text = "方向已通过，请重新选择停靠点。"
		status.modulate = AMBER
		stop_picker.grab_focus()
		return
	submitted.emit()
	_close()

func _input(event: InputEvent) -> void:
	if not closing and not stop_picker.get_popup().visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if closing:
		return
	closing = true
	closed.emit()
	queue_free()
