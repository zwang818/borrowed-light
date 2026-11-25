extends SceneTree
const PREFS := preload("res://scenes/ui/user_settings.gd")
const BINDINGS := preload("res://scenes/gameplay/input_bindings.gd")
const JOURNEY := preload("res://scenes/gameplay/journey_save.gd")
const PATH := "user://test_key_bindings.cfg"
const JOURNEY_PATH := "user://test_key_bindings_journey.json"
var failures: Array[String] = []
func _initialize() -> void:
	root.size = Vector2i(1152,648)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ",message)
func bytes_at(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
func click(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.pressed = down
		root.push_input(event,true)
func send_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.window_id = root.get_window_id()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	if code == KEY_CTRL: event.ctrl_pressed = down
	Input.parse_input_event(event)
func press(code: Key) -> void:
	send_key(code,true)
	await process_frame
	send_key(code,false)
	await process_frame
func mouse(button: MouseButton) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.window_id = root.get_window_id()
		event.position = root.get_final_transform()*(root.get_visible_rect().size/2)
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
func capture(label: String) -> void:
	var folder := OS.get_environment("BINDINGS_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("bindings_"+label+".png"))
func begin(panel: Control, action: String, slot: int) -> void:
	var button: Button = panel.binding_buttons[action][slot]
	panel.scroll.ensure_control_visible(button)
	await process_frame
	await process_frame
	click(button)
	check(panel.waiting_action==action and panel.waiting_slot==slot,"Binding click enters input capture: "+action)
func bind_key(panel: Control, action: String, slot: int, code: Key) -> void:
	await begin(panel,action,slot)
	await press(code)
	check(panel.waiting_action.is_empty() and panel.values.bindings[action][slot]==BINDINGS.key(code),"Captured key replaces real action: "+action)
func run() -> void:
	var personal := [bytes_at(PREFS.DEFAULT_PATH),bytes_at(JOURNEY.DEFAULT_PATH),bytes_at("user://achievements.cfg")]
	DirAccess.remove_absolute(PATH)
	JOURNEY.erase(JOURNEY_PATH)
	var defaults := BINDINGS.defaults()
	var corrupt := defaults.duplicate(true)
	corrupt.move_left[0] = BINDINGS.key(KEY_W)
	check(BINDINGS.sanitize(corrupt)==defaults,"Conflicting saved controls safely revert to defaults")
	corrupt = defaults.duplicate(true)
	corrupt.shoot = [null,null]
	check(BINDINGS.sanitize(corrupt)==defaults,"Corrupt save cannot erase the last shooting input")
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = JOURNEY_PATH
	title.settings_path = PATH
	root.add_child(title)
	current_scene = title
	await create_timer(0.3,true).timeout
	click(title.settings_button)
	await create_timer(0.3,true).timeout
	var panel = title._settings_panel
	click(panel.tab_buttons[1])
	await create_timer(0.2,true).timeout
	check(panel.active_tab==1 and panel.key_content.visible and not panel.audio_content.visible,"Key configuration is a separate compact tab")
	await capture("default")
	await bind_key(panel,"move_right",0,KEY_L)
	await begin(panel,"move_left",0)
	await press(KEY_W)
	check(panel.waiting_action==&"move_left" and panel.values.bindings.move_left[0]==BINDINGS.key(KEY_A) and panel.hint.text.contains("向上移动"),"Conflict is explained without replacing either action")
	await capture("conflict")
	await press(KEY_F5)
	check(panel.waiting_action==&"move_left" and panel.hint.text.contains("保留"),"Reserved function keys cannot silently activate development shortcuts")
	await press(KEY_K)
	await begin(panel,"move_left",0)
	await press(KEY_BACKSPACE)
	check(panel.values.bindings.move_left[0]==null and panel.values.bindings.move_left[1]==BINDINGS.key(KEY_LEFT),"One slot can be cleared while the alternate remains")
	await begin(panel,"move_left",1)
	await press(KEY_BACKSPACE)
	check(panel.waiting_action==&"move_left" and panel.hint.text.contains("至少保留"),"Cannot remove the last movement key")
	await press(KEY_ESCAPE)
	check(panel.visible and panel.waiting_action.is_empty() and panel.values.bindings.move_left[1]==BINDINGS.key(KEY_LEFT),"Capture Escape cancels without closing Settings or saving")
	await bind_key(panel,"move_left",0,KEY_K)
	await begin(panel,"shoot",0)
	await mouse(MOUSE_BUTTON_WHEEL_UP)
	check(not panel.waiting_action.is_empty(),"Wheel input cannot become a held gameplay action")
	await mouse(MOUSE_BUTTON_RIGHT)
	check(panel.waiting_action.is_empty() and panel.values.bindings.shoot[0]=={"type":"mouse","code":MOUSE_BUTTON_RIGHT},"Mouse button can replace shooting without clicking underlying UI")
	await bind_key(panel,"interact",0,KEY_F)
	await bind_key(panel,"interact",1,KEY_ENTER)
	check(panel.visible and panel.waiting_action.is_empty(),"Binding Enter does not also activate a focused menu button")
	await bind_key(panel,"b_sprint",0,KEY_CTRL)
	await bind_key(panel,"arm_pulse",0,KEY_V)
	await bind_key(panel,"arm_scatter",0,KEY_B)
	await bind_key(panel,"pause",0,KEY_P)
	check(InputMap.action_has_event(&"pause",BINDINGS.decode(BINDINGS.key(KEY_ESCAPE))),"Escape always remains a working pause fallback")
	var gamepad := InputEventJoypadButton.new()
	gamepad.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"shoot",gamepad)
	BINDINGS.apply(panel.values.bindings)
	check(InputMap.action_has_event(&"shoot",gamepad),"Applying keyboard/mouse bindings preserves existing gamepad input")
	var saved_bindings: Dictionary = panel.values.bindings.duplicate(true)
	click(panel.back_button)
	check(not panel.visible and PREFS.read_preferences(PATH).bindings==saved_bindings,"Save persists key and mouse bindings separately from journey progress")
	title.queue_free()
	await process_frame
	title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = JOURNEY_PATH
	title.settings_path = PATH
	root.add_child(title)
	current_scene = title
	await create_timer(0.3,true).timeout
	check(title._preferences.bindings==saved_bindings and BINDINGS.action_label(&"interact")=="F","Fresh title reads and applies the persisted controls")
	click(title.settings_button)
	await create_timer(0.3,true).timeout
	panel = title._settings_panel
	click(panel.tab_buttons[1])
	for dimensions in [Vector2i(1152,648),Vector2i(960,720)]:
		root.size = dimensions
		await create_timer(0.2,true).timeout
		panel.scroll.scroll_vertical = 0
		await process_frame
		check(root.get_visible_rect().encloses(panel.panel.get_global_rect()),"Keys tab fits 16:9 and 4:3")
		await capture("layout_%dx%d" % [dimensions.x,dimensions.y])
	var font := preload("res://assets/fonts/noto_sans_sc_settings.ttf")
	for control in panel.find_children("*","Control",true,false):
		if control is Label or control is Button:
			for character in control.text:
				if character.unicode_at(0)>32: check(font.has_char(character.unicode_at(0)),"Key page glyph: "+character)
	click(panel.back_button)
	title.queue_free()
	await process_frame
	var intro = load("res://scenes/ui/intro_cutscene/intro_cutscene.tscn").instantiate()
	root.add_child(intro)
	current_scene = intro
	var click_index := -1
	for i in intro.frames.size():
		if intro.frames[i].get("mode","")=="click" and not intro.frames[i].get("show_hud",false):
			click_index = i
			break
	check(click_index>=0,"Opening has an interactive dialogue frame")
	intro._frame_index = click_index
	intro._frame_timer = 0
	await press(KEY_F)
	check(intro._frame_index==click_index+1,"Rebound interaction key also advances opening dialogue")
	intro.queue_free()
	await process_frame
	set_meta("journey_session",{"path":JOURNEY_PATH})
	var level = load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	while not level.entry_ready: await process_frame
	var player = level.player
	player.global_position = level._find_spawn_position()
	await physics_frame
	var before: Vector2 = player.global_position
	send_key(KEY_D,true)
	await create_timer(0.12,true).timeout
	send_key(KEY_D,false)
	check(player.global_position.distance_to(before)<1,"Old D primary no longer moves the real player")
	send_key(KEY_L,true)
	await create_timer(0.18,true).timeout
	send_key(KEY_L,false)
	check(player.global_position.x>before.x+8,"Rebound L moves the real player")
	send_key(KEY_L,true)
	send_key(KEY_CTRL,true)
	await physics_frame
	await physics_frame
	check(player.sprint_active,"Rebound Ctrl activates real sprint")
	send_key(KEY_CTRL,false)
	send_key(KEY_L,false)
	player.learn_pulse()
	player.scatter_unlocked = true
	player.inspection_remaining = 0
	await press(KEY_B)
	check(player.selected_mode==player.AttackMode.SCATTER,"Rebound B switches to the unlocked scatter arm")
	await press(KEY_V)
	check(player.selected_mode==player.AttackMode.LASER,"Rebound V selects the pulse arm")
	await mouse(MOUSE_BUTTON_LEFT)
	check(player.pulse_gun.state==player.pulse_gun.State.IDLE,"Old left mouse no longer fires")
	await mouse(MOUSE_BUTTON_RIGHT)
	check(player.pulse_gun.state==player.pulse_gun.State.CHARGING,"Rebound right mouse charges the real pulse gun")
	player.pulse_gun.cancel()
	await press(KEY_P)
	check(paused and level.game_menus.page==level.game_menus.Page.PAUSE,"Rebound P opens the real pause menu")
	await press(KEY_P)
	check(not paused,"Rebound P resumes the real game")
	await press(KEY_ESCAPE)
	check(paused,"Reserved Escape still pauses")
	await press(KEY_ESCAPE)
	check(not paused,"Reserved Escape still resumes")
	player.global_position = level.interaction_points[&"workshop_origin"].global_position+Vector2(0,20)
	await physics_frame
	await physics_frame
	check(level._point_prompt(&"workshop_origin").begins_with("[F]"),"World interaction prompt follows the rebound key")
	await capture("world_prompt")
	await press(KEY_F)
	check(paused and level.pending_interaction==&"workshop_origin" and level.interaction_sheet._confirm.text.begins_with("[F]"),"Rebound F opens real story interaction and its confirm prompt updates")
	level.interaction_sheet._finish(false)
	await process_frame
	BINDINGS.apply(defaults)
	player.scatter_unlocked = false
	await press(KEY_2)
	check(player.selected_mode==player.AttackMode.LASER,"Default 2 cannot bypass scatter acquisition")
	player.scatter_unlocked = true
	await press(KEY_2)
	check(player.selected_mode==player.AttackMode.SCATTER,"Default 2 still selects learned scatter")
	await press(KEY_1)
	check(player.selected_mode==player.AttackMode.LASER,"Default 1 still selects learned pulse")
	player.pulse_gun.request_fire(Vector2.RIGHT)
	await press(KEY_2)
	check(player.selected_mode==player.AttackMode.LASER,"Rebindable arm actions preserve the charge switch restriction")
	player.pulse_gun.cancel()
	level.queue_free()
	await process_frame
	paused = false
	# Reset controls must not reset the user's sound choices.
	title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = JOURNEY_PATH
	title.settings_path = PATH
	root.add_child(title)
	current_scene = title
	await create_timer(0.3,true).timeout
	click(title.settings_button)
	await create_timer(0.3,true).timeout
	panel = title._settings_panel
	panel.volume_sliders.master.value = 37
	click(panel.tab_buttons[1])
	click(panel.reset_button)
	check(panel.values.bindings==defaults and panel.values.master==0.37 and BINDINGS.action_label(&"interact")=="E","Keys reset restores InputMap while preserving audio preferences")
	click(panel.back_button)
	check(personal==[bytes_at(PREFS.DEFAULT_PATH),bytes_at(JOURNEY.DEFAULT_PATH),bytes_at("user://achievements.cfg")],"Personal settings, journey and achievements remain byte-for-byte unchanged")
	title.queue_free()
	await create_timer(0.15,true).timeout
	DirAccess.remove_absolute(PATH)
	JOURNEY.erase(JOURNEY_PATH)
	print("BINDINGS CHECK: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
