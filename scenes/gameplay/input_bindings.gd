extends RefCounted
## Keyboard/mouse preferences only; UI navigation and gamepad events remain intact.
const ACTIONS := [&"move_up",&"move_down",&"move_left",&"move_right",&"shoot",&"interact",&"b_sprint",&"arm_pulse",&"arm_scatter",&"protocol_exit",&"pause"]
const LABELS := ["向上移动","向下移动","向左移动","向右移动","射击","交互 / 对话","加速移动","左臂脉冲","右臂散射","退出维护协议","暂停游戏"]
const EXTRA_KEYS := {&"b_sprint":KEY_SHIFT,&"arm_pulse":KEY_1,&"arm_scatter":KEY_2,&"protocol_exit":KEY_Q}

static func key(code: int) -> Dictionary:
	return {"type":"key","code":code}

static func encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return key(code)
	if event is InputEventMouseButton: return {"type":"mouse","code":int(event.button_index)}
	return {}

static func decode(binding: Dictionary) -> InputEvent:
	if binding.type == "mouse":
		var event := InputEventMouseButton.new()
		event.button_index = binding.code
		return event
	var event := InputEventKey.new()
	event.physical_keycode = binding.code
	return event

static func defaults() -> Dictionary:
	var data := {}
	for action in ACTIONS:
		var slots: Array = [null,null]
		if EXTRA_KEYS.has(action):
			slots[0] = key(EXTRA_KEYS[action])
		else:
			var setting: Dictionary = ProjectSettings.get_setting("input/"+String(action),{})
			var index := 0
			for event in setting.get("events",[]):
				if index == 2: break
				var binding := encode(event)
				if not binding.is_empty():
					slots[index] = binding
					index += 1
		data[String(action)] = slots
	return data

static func ensure_actions() -> void:
	for action in EXTRA_KEYS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		InputMap.action_add_event(action,decode(key(EXTRA_KEYS[action])))

static func valid(binding: Variant, action: StringName) -> bool:
	if binding == null: return true
	if not binding is Dictionary or not binding.get("code") is int: return false
	var code: int = binding.code
	if binding.get("type") == "mouse": return code in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_XBUTTON1,MOUSE_BUTTON_XBUTTON2]
	var character_key := code >= 32 and code <= 255
	var special_key := code >= KEY_ESCAPE and code < KEY_SPECIAL+256
	if binding.get("type") != "key" or not (character_key or special_key) or OS.get_keycode_string(code).is_empty(): return false
	if code == KEY_ESCAPE: return action == &"pause"
	return code not in [KEY_BACKSPACE,KEY_META] and not (code >= KEY_F1 and code <= KEY_F12)

static func conflict(data: Dictionary, action: StringName, slot: int, binding: Dictionary) -> String:
	for other in ACTIONS:
		var slots: Array = data[String(other)]
		for i in slots.size():
			if other == action and i == slot: continue
			if slots[i] == binding: return LABELS[ACTIONS.find(other)]
	return ""

static func sanitize(raw: Variant) -> Dictionary:
	var data := defaults()
	if not raw is Dictionary: return data
	for action in ACTIONS:
		var slots = raw.get(String(action),data[String(action)])
		if not slots is Array or slots.size()!=2: return defaults()
		if action == &"pause" and slots[1] != null: return defaults()
		for binding in slots:
			if not valid(binding,action): return defaults()
		if slots[0] == null and slots[1] == null and action != &"pause": return defaults()
		data[String(action)] = slots.duplicate(true)
	for action in ACTIONS:
		for slot in 2:
			var binding = data[String(action)][slot]
			if binding != null and not conflict(data,action,slot,binding).is_empty(): return defaults()
	return data

static func apply(data: Dictionary) -> void:
	ensure_actions()
	for action in ACTIONS:
		# A held key must not leave a latched movement/action after replacement.
		Input.action_release(action)
		var preserved: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			if not event is InputEventKey and not event is InputEventMouseButton: preserved.append(event)
		InputMap.action_erase_events(action)
		for binding in data[String(action)]:
			if binding != null: InputMap.action_add_event(action,decode(binding))
		for event in preserved: InputMap.action_add_event(action,event)
		if action == &"pause":
			var escape := decode(key(KEY_ESCAPE))
			if not InputMap.action_has_event(action,escape): InputMap.action_add_event(action,escape)

static func label(binding: Variant, compact: bool = false) -> String:
	if binding == null: return "未设置"
	if binding.type == "key": return OS.get_keycode_string(binding.code)
	var names := {MOUSE_BUTTON_LEFT:"鼠标左键",MOUSE_BUTTON_RIGHT:"鼠标右键",MOUSE_BUTTON_MIDDLE:"鼠标中键",MOUSE_BUTTON_XBUTTON1:"鼠标侧键 1",MOUSE_BUTTON_XBUTTON2:"鼠标侧键 2"}
	var short_names := {MOUSE_BUTTON_LEFT:"LMB",MOUSE_BUTTON_RIGHT:"RMB",MOUSE_BUTTON_MIDDLE:"MMB",MOUSE_BUTTON_XBUTTON1:"M4",MOUSE_BUTTON_XBUTTON2:"M5"}
	return short_names.get(binding.code,"Mouse") if compact else names.get(binding.code,"Mouse")

static func action_label(action: StringName, compact: bool = false) -> String:
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			var binding := encode(event)
			if not binding.is_empty(): return label(binding,compact)
	return "Esc" if action == &"pause" else "?"
