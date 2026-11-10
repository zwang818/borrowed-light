extends CanvasLayer
## Functional C fallback. D supplies dialogue and final presentation separately.
signal finished(token: int, completed: bool)
signal destination_selected(token: int, destination: StringName)
signal code_submitted(token: int, code: String)
const UI_THEME := preload("res://scenes/gameplay/gameplay_ui_theme.tres")
const DUCT_SIGN_TEXTURE := preload("res://assets/sprites/ui/maintenance_duct_sign.svg")
const PULSE_XIAOYI_SHEET := preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_laser_8dir.png")
const FRAME_CLEANUP := preload("res://tests/manual/b_combat/sprite_frame_cleanup.gd")
const PULSE_ROW_EDGES := [0, 213, 428, 644, 867, 1082, 1302, 1516, 1774]
const PULSE_SPIN_DURATION := 3.0
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
var _duct_icon: TextureRect
var _duct_icon_tween: Tween
var _pulse_preview: TextureRect
var _pulse_spin_tween: Tween
var _pulse_preview_frames: Array[Texture2D] = []

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("071116", 0.95))
	label.add_theme_constant_override("outline_size", 1)
	return label

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = fill.lerp(border, 0.65).lightened(0.12)
	style.set_border_width_all(3)
	style.border_width_top = 4
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
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
	overlay.set_meta("card_width", payload.get("card_width", 660.0))
	overlay.set_meta("disable_confirm", payload.get("disable_confirm", false))
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, payload.get("backdrop_alpha", 0.65))
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
	if payload.get("center_card", false):
		column.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(spacer)
	if payload.get("category", "") == "维护管道":
		_duct_icon = TextureRect.new()
		_duct_icon.name = "TemporaryDuctMarker"
		_duct_icon.texture = DUCT_SIGN_TEXTURE
		_duct_icon.custom_minimum_size = Vector2(300, 150)
		_duct_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_duct_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_duct_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_duct_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(_duct_icon)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	panel = PanelContainer.new()
	panel.name = "InteractionCard"
	var terminal_mode: bool = payload.get("input_mode", "") == "terminal_code"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("081711") if terminal_mode else Color("101b21", 0.98)
	style.border_color = Color("528061") if terminal_mode else style.bg_color.lerp(Color("a9c6c0"), 0.62)
	style.set_border_width_all(5)
	style.border_width_top = 8
	style.set_corner_radius_all(4)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 15
	style.shadow_offset = Vector2(0, 7)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8 if payload.get("input_mode", "") == "terminal_code" else 14)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)
	var category := _label(payload.get("category", "交互"), 13, Color("e9b85e"))
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(category)
	var title := _label(payload.title, 25, Color("f2edda"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var divider := HSeparator.new()
	divider.modulate = Color("946c3e")
	content.add_child(divider)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 18)
	content.add_child(detail_row)
	var body := RichTextLabel.new()
	_body = body
	_speaker = title
	body.text = payload.summary
	body.bbcode_enabled = false
	body.custom_minimum_size.y = 48
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_color_override("default_color", Color("c9d8d6"))
	body.add_theme_color_override("font_outline_color", Color("071116", 0.95))
	body.add_theme_constant_override("outline_size", 1)
	detail_row.add_child(body)
	if payload.has("blueprint_preview"):
		var preview := TextureRect.new()
		preview.texture = payload["blueprint_preview"]
		preview.custom_minimum_size = Vector2(280, 174)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_row.add_child(preview)
	if payload.get("pulse_character_preview", false):
		_pulse_preview = TextureRect.new()
		_pulse_preview.name = "PulseEquippedXiaoyiPreview"
		_pulse_preview.custom_minimum_size = Vector2(136, 150)
		_pulse_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_pulse_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pulse_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_pulse_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pulse_preview_frames = _make_pulse_preview_frames()
		if not _pulse_preview_frames.is_empty():
			_pulse_preview.texture = _pulse_preview_frames[0]
		detail_row.add_child(_pulse_preview)
	for choice in payload.get("choices", []):
		var destination := Button.new()
		destination.text = choice.title
		destination.custom_minimum_size.y = 36
		destination.pressed.connect(_select_destination.bind(request_token, StringName(choice.id)))
		content.add_child(destination)
	if payload.get("input_mode", "") == "terminal_code":
		var console_font := UI_THEME.default_font
		for label in [category, title]:
			label.add_theme_font_override("font", console_font)
			label.add_theme_color_override("font_color", Color("a5e8ae"))
		body.add_theme_font_override("normal_font", console_font)
		body.add_theme_color_override("default_color", Color("a5e8ae"))
		body.custom_minimum_size.y = 84
		_build_console_input(content, console_font)
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
	if is_instance_valid(_pulse_preview) and _pulse_preview_frames.size() == 8:
		_start_pulse_spin()
	if is_instance_valid(_duct_icon):
		_duct_icon_tween = create_tween()
		_duct_icon_tween.tween_interval(1.5)
		_duct_icon_tween.tween_property(_duct_icon, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_duct_icon_tween.tween_callback(_duct_icon.hide)
	overlay.resized.connect(_layout_panel)
	_layout_panel()
	if is_instance_valid(_code_input):
		_code_input.grab_focus()

func _build_console_input(content: VBoxContainer, console_font: Font) -> void:
	var command := HBoxContainer.new()
	content.add_child(command)
	var prompt := _label("ACCESS >", 18, Color("a5e8ae"))
	prompt.add_theme_font_override("font", console_font)
	command.add_child(prompt)
	_code_input = LineEdit.new()
	_code_input.name = "TerminalCode"
	_code_input.max_length = 4
	_code_input.placeholder_text = "----"
	_code_input.caret_blink = true
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.add_theme_font_override("font", console_font)
	_code_input.add_theme_font_size_override("font_size", 22)
	_code_input.add_theme_color_override("font_color", Color("c4f4bd"))
	_code_input.custom_minimum_size.y = 38
	_code_input.text_changed.connect(_filter_code.bind(_code_input))
	_code_input.text_submitted.connect(func(_text: String): _advance_or_finish())
	command.add_child(_code_input)
	_code_status = _label("ENTER: SUBMIT   ESC: DISCONNECT", 17, Color("a5e8ae"))
	_code_status.add_theme_font_override("font", console_font)
	content.add_child(_code_status)

func _make_pulse_preview_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if not _pulse_preview_frames.is_empty():
		return _pulse_preview_frames
	var source := PULSE_XIAOYI_SHEET.get_image()
	for row in range(8):
		var x0 := roundi(float(source.get_width()) * 0.0 / 4.0)
		var x1 := roundi(float(source.get_width()) * 1.0 / 4.0)
		var cell := Rect2i(x0, PULSE_ROW_EDGES[row], x1 - x0, PULSE_ROW_EDGES[row + 1] - PULSE_ROW_EDGES[row])
		var cleaned: Image = FRAME_CLEANUP.clean_frame(source.get_region(cell))
		var bounds := cleaned.get_used_rect()
		if bounds.size.x <= 0 or bounds.size.y <= 0:
			continue
		frames.append(ImageTexture.create_from_image(cleaned.get_region(bounds)))
	return frames

func _start_pulse_spin() -> void:
	if _pulse_spin_tween and _pulse_spin_tween.is_running():
		_pulse_spin_tween.kill()
	_pulse_preview.texture = _pulse_preview_frames[0]
	_pulse_spin_tween = create_tween()
	for frame_index in range(1, 9):
		_pulse_spin_tween.tween_interval(PULSE_SPIN_DURATION / 8.0)
		_pulse_spin_tween.tween_callback(_set_pulse_preview_frame.bind(frame_index % 8))

func _set_pulse_preview_frame(frame_index: int) -> void:
	if is_instance_valid(_pulse_preview) and frame_index >= 0 and frame_index < _pulse_preview_frames.size():
		_pulse_preview.texture = _pulse_preview_frames[frame_index]

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

func show_code_error(request_token: int) -> void:
	if request_token != token or not is_instance_valid(overlay) or not is_instance_valid(_code_input):
		return
	_code_status.text = "ACCESS DENIED. CHECK THE CODE."
	_code_input.grab_focus()
	_code_input.select_all()

func show_code_success(request_token: int) -> void:
	if request_token != token or not is_instance_valid(_code_input):
		return
	_code_input.editable = false
	_confirm.disabled = true
	overlay.set_meta("disable_confirm", true)
	for control in _code_status.get_parent().get_children():
		control.visible = control == _code_status
	_code_status.text = "SUCCESSFULLY ENTERED！"
	_code_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_status.add_theme_font_override("font", UI_THEME.default_font)
	_code_status.add_theme_font_size_override("font_size", 30)
	_code_status.add_theme_color_override("font_color", Color("a5e8ae"))

func _layout_panel() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(overlay):
		return
	var width := minf(overlay.get_meta("card_width"), maxf(280, overlay.size.x - 40))
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
		if not _code_input.editable:
			return
		if _code_input.text.length() != 4:
			_code_status.text = "ENTER ALL FOUR DIGITS."
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
	if _duct_icon_tween and _duct_icon_tween.is_running():
		_duct_icon_tween.kill()
	_duct_icon_tween = null
	_duct_icon = null
	if _pulse_spin_tween and _pulse_spin_tween.is_running():
		_pulse_spin_tween.kill()
	_pulse_spin_tween = null
	_pulse_preview = null
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	overlay = null
	panel = null
	dialogue = []
	_code_input = null
	_code_status = null
