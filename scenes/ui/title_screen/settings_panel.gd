extends Control
## Compact title overlay; changes preview live, Return/Esc persist preferences.
signal closed
const PREFS := preload("res://scenes/ui/user_settings.gd")
const BINDINGS := preload("res://scenes/gameplay/input_bindings.gd")
const FEEDBACK := preload("res://scenes/ui/ui_button_feedback.gd")
const FONT := preload("res://assets/fonts/noto_sans_sc_settings.ttf")
const GOLD := Color("ddc18a")
var save_path := PREFS.DEFAULT_PATH
var values: Dictionary = {}
var panel: PanelContainer
var volume_sliders: Dictionary = {}
var volume_labels: Dictionary = {}
var mode_option: OptionButton
var size_option: OptionButton
var vsync_toggle: CheckButton
var reset_button: Button
var back_button: Button
var hint: Label
var focus_controls: Array[Control] = []
var refreshing := false
var active_tab := 0
var tab_buttons: Array[Button] = []
var audio_controls: Array[Control] = []
var key_controls: Array[Control] = []
var audio_content: VBoxContainer
var key_content: VBoxContainer
var scroll: ScrollContainer
var binding_buttons: Dictionary = {}
var waiting_action: StringName = &""
var waiting_slot := -1

func _ready() -> void:
	name = "SettingsOverlay"
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = preload("res://scenes/ui/title_screen/title_theme.tres").duplicate()
	theme.default_font = FONT
	theme.default_font_size = 18
	var dim := ColorRect.new()
	dim.color = Color(0.02,0.04,0.06,0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(320,56)
	panel.size = Vector2(640,608)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15252eee")
	style.border_color = Color(GOLD,0.32)
	style.set_border_width_all(1)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	panel.add_child(body)
	var heading := Label.new()
	heading.text = "设置"
	heading.add_theme_font_size_override("font_size",28)
	heading.add_theme_color_override("font_color",GOLD)
	body.add_child(heading)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",12)
	body.add_child(tabs)
	for tab_name in ["声音与画面","按键"]:
		var tab := Button.new()
		tab.text = tab_name
		tab.custom_minimum_size = Vector2(220,34)
		tabs.add_child(tab)
		tab.pressed.connect(_show_tab.bind(tab_buttons.size()))
		tab_buttons.append(tab)
		FEEDBACK.attach(tab,false,true)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 344
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	audio_content = VBoxContainer.new()
	audio_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_content.add_theme_constant_override("separation",14)
	pages.add_child(audio_content)
	key_content = VBoxContainer.new()
	key_content.add_theme_constant_override("separation",6)
	pages.add_child(key_content)
	key_content.hide()
	_add_slider(audio_content,"总音量","master")
	_add_slider(audio_content,"背景音乐","music")
	_add_slider(audio_content,"界面音效","ui")
	var separator := HSeparator.new()
	separator.modulate = Color(GOLD,0.35)
	audio_content.add_child(separator)
	mode_option = OptionButton.new()
	mode_option.add_item("窗口")
	mode_option.add_item("全屏")
	_add_choice(audio_content,"显示模式",mode_option)
	mode_option.item_selected.connect(func(index):
		if refreshing: return
		values.fullscreen = index == 1
		PREFS.apply_display(values,get_window())
		_refresh_display())
	size_option = OptionButton.new()
	for dimensions in PREFS.WINDOW_SIZES:
		size_option.add_item("%d × %d" % [dimensions.x,dimensions.y])
	_add_choice(audio_content,"窗口分辨率",size_option)
	size_option.item_selected.connect(func(index):
		if refreshing: return
		values["size"] = PREFS.WINDOW_SIZES[index]
		PREFS.apply_display(values,get_window()))
	vsync_toggle = CheckButton.new()
	vsync_toggle.text = "开启"
	_add_choice(audio_content,"垂直同步",vsync_toggle)
	vsync_toggle.toggled.connect(func(enabled):
		if refreshing: return
		values.vsync = enabled
		vsync_toggle.text = "开启" if enabled else "关闭"
		PREFS.apply_display(values,get_window()))
	audio_controls.assign(focus_controls)
	focus_controls.clear()
	_build_binding_rows()
	hint = Label.new()
	hint.custom_minimum_size.y = 42
	hint.text = "调整即时生效"
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color("95a3a7"))
	body.add_child(hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	body.add_child(actions)
	reset_button = Button.new()
	reset_button.text = "恢复默认"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.custom_minimum_size.y = 44
	reset_button.pressed.connect(_reset_defaults)
	actions.add_child(reset_button)
	back_button = Button.new()
	back_button.text = "保存并返回"
	back_button.custom_minimum_size = Vector2(250,44)
	back_button.pressed.connect(save_and_close)
	actions.add_child(back_button)
	for button in [reset_button,back_button]: FEEDBACK.attach(button)
	_show_tab(0)
	hide()

func _row(body: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	row.add_theme_constant_override("separation",16)
	body.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	row.add_child(label)
	return row

func _add_choice(body: VBoxContainer, label_text: String, control: Control) -> void:
	var row := _row(body,label_text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	focus_controls.append(control)

func _add_slider(body: VBoxContainer, label_text: String, key: String) -> void:
	var row := _row(body,label_text)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 28
	var track := StyleBoxFlat.new()
	track.bg_color = Color("41525a")
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	track.corner_radius_top_left = 2
	track.corner_radius_top_right = 2
	track.corner_radius_bottom_left = 2
	track.corner_radius_bottom_right = 2
	slider.add_theme_stylebox_override("slider",track)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = GOLD
	slider.add_theme_stylebox_override("grabber_area",fill)
	slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	row.add_child(slider)
	volume_sliders[key] = slider
	focus_controls.append(slider)
	var number := Label.new()
	number.custom_minimum_size.x = 46
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.add_theme_color_override("font_color",GOLD)
	row.add_child(number)
	volume_labels[key] = number
	slider.value_changed.connect(func(value):
		number.text = "%d%%" % roundi(value)
		if refreshing: return
		values[key] = value/100.0
		PREFS.apply_audio(values))

func open(data: Dictionary) -> void:
	values = data.duplicate(true)
	_refresh_controls()
	_show_tab(active_tab)
	show()
	FEEDBACK.reveal(panel,true)
	if active_tab == 0: volume_sliders.master.grab_focus()
	else: key_controls[0].grab_focus()

func _refresh_controls() -> void:
	refreshing = true
	for key in volume_sliders:
		volume_sliders[key].value = values[key]*100
		volume_labels[key].text = "%d%%" % roundi(values[key]*100)
	mode_option.select(1 if values.fullscreen else 0)
	size_option.select(PREFS.WINDOW_SIZES.find(values["size"]))
	vsync_toggle.set_pressed_no_signal(values.vsync)
	vsync_toggle.text = "开启" if values.vsync else "关闭"
	_refresh_display()
	_refresh_binding_labels()
	refreshing = false

func _refresh_display() -> void:
	size_option.disabled = values.fullscreen
	size_option.tooltip_text = "全屏使用显示器分辨率" if values.fullscreen else "仅影响窗口大小"

func _reset_defaults() -> void:
	if active_tab == 1:
		values.bindings = BINDINGS.defaults()
		BINDINGS.apply(values.bindings)
		_refresh_binding_labels()
		hint.text = "按键已恢复默认"
	else:
		var retained: Dictionary = values.bindings
		values = PREFS.defaults()
		values.bindings = retained
		PREFS.apply_audio(values)
		PREFS.apply_display(values,get_window())
		_refresh_controls()
		hint.text = "调整即时生效"

func popup_visible() -> bool:
	return mode_option.get_popup().visible or size_option.get_popup().visible

func save_and_close() -> void:
	if not visible: return
	if PREFS.save_preferences(values,save_path) != OK:
		hint.text = "保存失败，请重试"
		return
	hide()
	closed.emit()


func _build_binding_rows() -> void:
	var headers := HBoxContainer.new()
	headers.add_theme_constant_override("separation",16)
	key_content.add_child(headers)
	for text in ["操作","主按键","备用按键"]:
		var caption := Label.new()
		caption.text = text
		caption.custom_minimum_size.x = 150 if text == "操作" else 184
		caption.add_theme_font_size_override("font_size",14)
		caption.add_theme_color_override("font_color",Color("95a3a7"))
		headers.add_child(caption)
	for action in BINDINGS.ACTIONS:
		var row := _row(key_content,BINDINGS.LABELS[BINDINGS.ACTIONS.find(action)])
		var slots: Array[Button] = []
		for slot in 2:
			var button := Button.new()
			button.custom_minimum_size = Vector2(184,36)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size",16)
			for state in ["normal","hover","pressed","disabled"]:
				var style: StyleBox = button.get_theme_stylebox(state).duplicate()
				style.content_margin_top = 4
				style.content_margin_bottom = 4
				button.add_theme_stylebox_override(state,style)
			button.pressed.connect(_start_capture.bind(action,slot))
			row.add_child(button)
			slots.append(button)
			if action == &"pause" and slot == 1:
				button.disabled = true
				button.focus_mode = Control.FOCUS_NONE
			else:
				key_controls.append(button)
			FEEDBACK.attach(button)
		binding_buttons[String(action)] = slots

func _show_tab(index: int) -> void:
	if not waiting_action.is_empty(): _cancel_capture()
	active_tab = index
	audio_content.visible = index == 0
	key_content.visible = index == 1
	scroll.scroll_vertical = 0
	for i in tab_buttons.size():
		tab_buttons[i].modulate = GOLD if i == index else Color("9faeaf")
	focus_controls.assign(tab_buttons)
	focus_controls.append_array(audio_controls if index == 0 else key_controls)
	focus_controls.append_array([reset_button,back_button])
	for i in focus_controls.size():
		var control := focus_controls[i]
		control.focus_next = control.get_path_to(focus_controls[(i+1)%focus_controls.size()])
		control.focus_previous = control.get_path_to(focus_controls[(i-1+focus_controls.size())%focus_controls.size()])
	hint.text = "调整即时生效" if index == 0 else "点选按键后输入；Esc 取消，Backspace 清除。\nEsc 始终保留为暂停 / 返回。"

func _refresh_binding_labels() -> void:
	if values.is_empty(): return
	for action in BINDINGS.ACTIONS:
		var slots: Array = binding_buttons[String(action)]
		for i in 2:
			slots[i].text = "Esc（保留）" if action == &"pause" and i == 1 else BINDINGS.label(values.bindings[String(action)][i])

func _start_capture(action: StringName, slot: int) -> void:
	waiting_action = action
	waiting_slot = slot
	binding_buttons[String(action)][slot].text = "等待输入…"
	hint.text = "请按单个键或鼠标键；Esc 取消，Backspace 清除。"

func _cancel_capture(message: String = "已取消修改") -> void:
	var focus: Button = binding_buttons[String(waiting_action)][waiting_slot]
	waiting_action = &""
	waiting_slot = -1
	_refresh_binding_labels()
	hint.text = message
	focus.grab_focus()

func capture_event(event: InputEvent) -> bool:
	if waiting_action.is_empty(): return false
	if not event is InputEventKey and not event is InputEventMouseButton: return false
	if not event.is_pressed() or event.is_echo(): return true
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_ESCAPE:
			_cancel_capture()
			return true
		if code == KEY_BACKSPACE:
			var slots: Array = values.bindings[String(waiting_action)]
			if slots[1-waiting_slot] == null and waiting_action != &"pause":
				hint.text = "至少保留一个按键，请重新输入。"
				return true
			slots[waiting_slot] = null
			BINDINGS.apply(values.bindings)
			_cancel_capture("按键已清除")
			return true
		if (event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed) and code not in [KEY_SHIFT,KEY_CTRL,KEY_ALT]:
			hint.text = "请按单个键，不使用组合键。"
			return true
	var binding := BINDINGS.encode(event)
	if not BINDINGS.valid(binding,waiting_action):
		hint.text = "该按键已保留或不支持，请换一个。"
		return true
	var used := BINDINGS.conflict(values.bindings,waiting_action,waiting_slot,binding)
	if not used.is_empty():
		hint.text = "已用于“%s”，请换一个按键。" % used
		return true
	values.bindings[String(waiting_action)][waiting_slot] = binding
	BINDINGS.apply(values.bindings)
	_cancel_capture("按键已更新："+BINDINGS.label(binding))
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not waiting_action.is_empty(): _cancel_capture()
