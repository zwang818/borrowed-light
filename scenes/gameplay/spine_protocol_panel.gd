extends CanvasLayer
signal submitted(correct: bool)
signal closed
var contacts := [false, false, false]
var cells: Array[Button] = []
var status: Label
var root_control: Control
var playback := -1.0
var replay := false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.theme = preload("res://scenes/gameplay/spine_flow_theme.tres")
	add_child(root_control)
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.04,0.05,0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520,320)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",18)
	margin.add_child(box)
	var title := Label.new()
	title.text = "维护回执 · 三格拨片"
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	box.add_child(row)
	for i in range(3):
		var button := Button.new()
		button.text = "短  ·"
		button.custom_minimum_size = Vector2(142,56)
		button.pressed.connect(_toggle.bind(i))
		row.add_child(button)
		cells.append(button)
	status = Label.new()
	status.text = "观察背灯与读头，拨动触点后发送。"
	box.add_child(status)
	var send := Button.new()
	send.text = "发送测试信号"
	send.pressed.connect(_send)
	box.add_child(send)
	var again := Button.new()
	again.text = "重听示范 / 看灯语"
	again.pressed.connect(func():
		if playback < 0:
			replay = true
			playback = 0)
	box.add_child(again)
	var back := Button.new()
	back.text = "Esc · 返回"
	back.pressed.connect(_close)
	box.add_child(back)
	cells[0].grab_focus()

func _toggle(index: int) -> void:
	if playback >= 0: return
	contacts[index] = not contacts[index]
	cells[index].text = "长  ━" if contacts[index] else "短  ·"

func _send() -> void:
	if playback >= 0: return
	replay = false
	playback = 0
	status.text = "读头正在回放输入……"

func _process(delta: float) -> void:
	if playback < 0: return
	playback += delta
	var pattern := [false,true,false] if replay else contacts
	for i in range(3):
		var time := playback - i * 0.85
		cells[i].modulate = Color("a8e2d9") if time >= 0 and time < (0.55 if pattern[i] else 0.18) else Color.WHITE
	if playback < 2.7: return
	playback = -1
	if replay:
		status.text = "示范已结束，拨片保持原来的位置。"
		return
	var mismatch := -1
	for i in range(3):
		if contacts[i] != [false,true,false][i]:
			mismatch = i
			break
	if mismatch >= 0:
		status.text = "第 %d 格未匹配，保留输入，可原地修正。" % (mismatch+1)
		cells[mismatch].grab_focus()
		submitted.emit(false)
	else:
		submitted.emit(true)
		_close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
