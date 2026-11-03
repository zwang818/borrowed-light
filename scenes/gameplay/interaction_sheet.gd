extends CanvasLayer
## Functional C fallback. D supplies dialogue and final presentation separately.
signal finished(token: int, completed: bool)
signal destination_selected(token: int, destination: StringName)
signal code_submitted(token: int, code: String)
const UI_THEME := preload("res://scenes/gameplay/gameplay_ui_theme.tres")
var token := 0
var overlay: Control
var panel: PanelContainer
var dialogue: Array = []
var line_index := 0
var _speaker: Label
var _body: RichTextLabel
var _confirm: Button
var _last_action := ""
var _code_input: LineEdit
var _code_status: Label

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	return style

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25

func present(request_token: int, payload: Dictionary) -> void:
	dismiss()
	token = request_token
	dialogue = payload.get("dialogue", []).duplicate(true)
	line_index = 0
	_last_action = payload.confirm
	overlay = Control.new()
	overlay.theme = UI_THEME
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.set_meta("disable_confirm", payload.get("disable_confirm", false))
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_right", 20)
	margins.add_theme_constant_override("margin_top", 20)
	margins.add_theme_constant_override("margin_bottom", 20)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(margins)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(column)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	panel = PanelContainer.new()
	panel.name = "InteractionCard"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14262e")
	style.border_color = Color("526e73")
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8 if payload.get("input_mode", "") == "terminal_code" else 14)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)
	var category := _label(payload.get("category", "交互"), 12, Color("dfbd81"))
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(category)
	header.add_child(_label(payload.get("badge", "已读" if payload.get("replay", false) else "首次查看"), 12, Color("a2b9ba")))
	var title := _label(payload.title, 23, Color("edf0e2"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var divider := HSeparator.new()
	divider.modulate = Color("44616b")
	content.add_child(divider)
	var body := RichTextLabel.new()
	_body = body
	_speaker = title
	body.text = payload.summary
	body.bbcode_enabled = false
	body.custom_minimum_size.y = 48
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_color_override("default_color", Color("c9d8d6"))
	content.add_child(body)
	for choice in payload.get("choices", []):
		var destination := Button.new()
		destination.text = choice.title
		destination.custom_minimum_size.y = 36
		destination.pressed.connect(_select_destination.bind(request_token, StringName(choice.id)))
		content.add_child(destination)
	if payload.get("input_mode", "") == "terminal_code":
		_build_keypad(content)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	var confirm := Button.new()
	_confirm = confirm
	confirm.text = "[E]  " + payload.confirm
	if is_instance_valid(_code_input):
		confirm.text = payload.confirm
	confirm.disabled = payload.get("disable_confirm", false)
	if confirm.disabled:
		confirm.text = payload.confirm
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size.y = 38
	confirm.add_theme_stylebox_override("normal", _button_style(Color("b6ccbd"), Color("d5e2cb")))
	confirm.add_theme_stylebox_override("hover", _button_style(Color("d0dfc8"), Color("f1edcd")))
	confirm.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), Color("efcc8e")))
	confirm.add_theme_stylebox_override("pressed", _button_style(Color("8da99f"), Color("cad7bc")))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		confirm.add_theme_color_override(state, Color("18343c"))
	confirm.pressed.connect(_advance_or_finish)
	actions.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Esc · 返回"
	cancel.custom_minimum_size = Vector2(100, 38)
	cancel.add_theme_stylebox_override("normal", _button_style(Color("1b3039"), Color("536e73")))
	cancel.add_theme_stylebox_override("hover", _button_style(Color("2b4650"), Color("a7bdb6")))
	cancel.pressed.connect(_finish.bind(false))
	actions.add_child(cancel)
	if not dialogue.is_empty():
		_show_line()
	overlay.resized.connect(_layout_panel)
	_layout_panel()
	if is_instance_valid(_code_input):
		_code_input.grab_focus()

func _build_keypad(content: VBoxContainer) -> void:
	_code_input = LineEdit.new()
	_code_input.name = "TerminalCode"
	_code_input.max_length = 4
	_code_input.placeholder_text = "输入四位口令"
	_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code_input.add_theme_font_size_override("font_size", 26)
	_code_input.custom_minimum_size.y = 44
	_code_input.text_changed.connect(_filter_code.bind(_code_input))
	_code_input.text_submitted.connect(func(_text: String): _advance_or_finish())
	content.add_child(_code_input)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "清空", "0", "退格"]:
		var button := Button.new()
		button.text = key
		button.custom_minimum_size.y = 32
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_type_code.bind(key))
		grid.add_child(button)
	_code_status = _label("", 12, Color("dfbd81"))
	content.add_child(_code_status)

func _filter_code(text: String, source: LineEdit) -> void:
	# LineEdit batches text_changed; a valid submission may already have closed it.
	if not is_instance_valid(overlay) or not is_instance_valid(source) or source != _code_input:
		return
	var digits := ""
	for character in text:
		if character >= "0" and character <= "9":
			digits += character
	if digits != text:
		var caret := _code_input.caret_column
		_code_input.text = digits
		_code_input.caret_column = mini(caret, digits.length())
	_code_status.text = ""

func _type_code(key: String) -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(_code_input):
		return
	get_viewport().set_input_as_handled()
	if key == "清空":
		_code_input.clear()
		_code_input.deselect()
	else:
		var had_selection := _code_input.has_selection()
		if had_selection:
			var start := _code_input.get_selection_from_column()
			_code_input.delete_text(start, _code_input.get_selection_to_column())
			_code_input.deselect()
			_code_input.caret_column = start
		if key == "退格":
			if not had_selection:
				_code_input.delete_char_at_caret()
		else:
			_code_input.insert_text_at_caret(key)
	_code_input.grab_focus()

func show_code_error(request_token: int) -> void:
	if request_token != token or not is_instance_valid(overlay) or not is_instance_valid(_code_input):
		return
	_code_status.text = "口令不匹配，请核对原始记录。"
	_code_input.grab_focus()
	_code_input.select_all()

func _layout_panel() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(overlay):
		return
	var width := minf(660, maxf(280, overlay.size.x - 40))
	panel.custom_minimum_size.x = width

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(overlay) and not overlay.get_meta("disable_confirm", false) and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_advance_or_finish()

func _show_line() -> void:
	_speaker.text = dialogue[line_index].speaker
	_body.text = dialogue[line_index].text
	_confirm.text = "[E]  " + ("继续" if line_index < dialogue.size() - 1 else _last_action)

func _advance_or_finish() -> void:
	if not is_instance_valid(overlay):
		return
	get_viewport().set_input_as_handled()
	if is_instance_valid(_code_input):
		if _code_input.text.length() != 4:
			_code_status.text = "请输入完整的四位口令。"
			return
		code_submitted.emit(token, _code_input.text)
		return
	if not dialogue.is_empty() and line_index < dialogue.size() - 1:
		line_index += 1
		_show_line()
		return
	_finish(true)

func _finish(completed: bool) -> void:
	if not is_instance_valid(overlay):
		return
	var completed_token := token
	get_viewport().set_input_as_handled()
	dismiss()
	finished.emit(completed_token, completed)

func _select_destination(request_token: int, destination: StringName) -> void:
	if not is_instance_valid(overlay) or request_token != token:
		return
	get_viewport().set_input_as_handled()
	destination_selected.emit(request_token, destination)

func dismiss() -> void:
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	overlay = null
	panel = null
	dialogue = []
	_code_input = null
	_code_status = null
