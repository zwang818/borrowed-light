extends CanvasLayer
## Functional C fallback. D supplies dialogue and final presentation separately.
signal finished(token: int, completed: bool)
signal destination_selected(token: int, destination: StringName)
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
	content.add_theme_constant_override("separation", 14)
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
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	var confirm := Button.new()
	_confirm = confirm
	confirm.text = "[E]  " + payload.confirm
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
