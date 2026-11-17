extends SceneTree
const PREFS := preload("res://scenes/ui/user_settings.gd")
const JOURNEY := preload("res://scenes/gameplay/journey_save.gd")
const PATH := "user://test_title_settings.cfg"
const JOURNEY_PATH := "user://test_title_settings_journey.json"
var failures: Array[String] = []
var original_preferences: PackedByteArray
var original_journey: PackedByteArray
var original_achievements: PackedByteArray
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
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = down
		root.push_input(event,true)
func key_action(action: String) -> void:
	for down in [true,false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		root.push_input(event,true)
func pick(option: OptionButton,index: int) -> void:
	var pos := option.get_global_rect().get_center()
	root.warp_mouse(pos)
	await process_frame
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.window_id = root.get_window_id()
	# Native Window input uses physical pixels; GUI rectangles use canvas coordinates.
	motion.position = root.get_final_transform()*pos
	Input.parse_input_event(motion)
	await process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.window_id = root.get_window_id()
		event.position = root.get_final_transform()*pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	var popup := option.get_popup()
	check(popup.visible,"Option opens through a real pointer click")
	popup.set_focused_item(index)
	# PopupMenu keyboard handling is in its native window input path.
	var accept := InputEventKey.new()
	accept.window_id = popup.get_window_id()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept = accept.duplicate()
	accept.pressed = false
	Input.parse_input_event(accept)
	await process_frame


func capture(label: String) -> void:
	var folder := OS.get_environment("SETTINGS_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("settings_"+label+".png"))
func run() -> void:
	original_preferences = bytes_at(PREFS.DEFAULT_PATH)
	original_journey = bytes_at(JOURNEY.DEFAULT_PATH)
	original_achievements = bytes_at("user://achievements.cfg")
	DirAccess.remove_absolute(PATH)
	JOURNEY.erase(JOURNEY_PATH)
	check(PREFS.read_preferences(PATH)==PREFS.defaults(),"Missing settings have usable defaults")
	var corrupt := ConfigFile.new()
	corrupt.set_value("audio","master",4.0)
	corrupt.set_value("audio","music","broken")
	corrupt.set_value("audio","ui",-2)
	corrupt.set_value("display","fullscreen","bad")
	corrupt.set_value("display","size",Vector2i(-1,-1))
	corrupt.save(PATH)
	var repaired := PREFS.read_preferences(PATH)
	check(repaired.master==1.0 and repaired.music==1.0 and repaired.ui==0.0 and not repaired.fullscreen and repaired["size"]==Vector2i(1152,648),"Corrupt types/ranges fall back or clamp safely")
	DirAccess.remove_absolute(PATH)
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = JOURNEY_PATH
	title.settings_path = PATH
	root.add_child(title)
	current_scene = title
	await create_timer(0.3,true).timeout
	check(title.settings_button.visible,"First visit exposes Settings")
	click(title.settings_button)
	await create_timer(0.3,true).timeout
	var panel = title._settings_panel
	check(panel.visible and title.start_button.focus_mode==Control.FOCUS_NONE,"Settings modal owns focus")
	click(title.start_button)
	check(not title._is_starting,"Settings shade blocks background Start")
	for i in 18:
		key_action("ui_focus_next")
		check(root.gui_get_focus_owner() in panel.focus_controls,"Tab stays inside settings")
	panel.mode_option.show_popup()
	await process_frame
	var popup: PopupMenu = panel.mode_option.get_popup()
	var escape := InputEventKey.new()
	escape.window_id = popup.get_window_id()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	escape = escape.duplicate()
	escape.pressed = false
	Input.parse_input_event(escape)
	await process_frame
	check(panel.visible and not popup.visible and not FileAccess.file_exists(PATH),"Esc first dismisses an open dropdown without saving/closing Settings")
	# Exercise the actual slider pointer interaction, not just its signal.
	click(panel.volume_sliders.master)
	check(panel.values.master>0.35 and panel.values.master<0.65,"Master slider responds to pointer input")
	panel.volume_sliders.music.grab_focus()
	key_action("ui_left")
	check(panel.values.music<1.0,"Keyboard adjusts music slider")
	panel.volume_sliders.master.value = 0
	check(AudioServer.is_bus_mute(0),"Zero master mutes all buses")
	panel.volume_sliders.master.value = 65
	panel.volume_sliders.music.value = 35
	panel.volume_sliders.ui.value = 0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(PREFS.UI_BUS)) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(PREFS.MUSIC_BUS)),linear_to_db(0.35)),"Music and UI channels preview independently")
	check(title._bgm_player.bus==PREFS.MUSIC_BUS,"Real title music uses the controlled channel")
	await capture("panel")
	await pick(panel.size_option,1)
	check(panel.values["size"]==Vector2i(1280,720),"Native resolution dropdown applies selection")
	await create_timer(0.2,true).timeout
	if DisplayServer.get_name()!="headless": check(root.size==Vector2i(1280,720),"Selected window resolution really changes the game window")
	await pick(panel.mode_option,1)
	await create_timer(0.2,true).timeout
	check(panel.values.fullscreen and panel.size_option.disabled,"Fullscreen disables window-only resolution")
	if DisplayServer.get_name()!="headless": check(root.mode==Window.MODE_FULLSCREEN,"Fullscreen changes the real window mode")
	click(panel.vsync_toggle)
	check(not panel.values.vsync,"VSync toggle updates preferences")
	if DisplayServer.get_name()!="headless": check(DisplayServer.window_get_vsync_mode(root.get_window_id())==DisplayServer.VSYNC_DISABLED,"VSync changes actual display presentation")
	await pick(panel.mode_option,0)
	await create_timer(0.2,true).timeout
	await capture("windowed")
	click(panel.back_button)
	check(not panel.visible and title.settings_button.has_focus(),"Save and Return restores menu focus")
	var saved := PREFS.read_preferences(PATH)
	check(saved.master==0.65 and saved.music==0.35 and saved.ui==0.0 and saved["size"]==Vector2i(1280,720) and not saved.fullscreen and not saved.vsync,"Audio and display preferences persist on disk")
	title.queue_free()
	await process_frame
	root.size = Vector2i(1152,648)
	remove_meta("display_preferences_initialized")
	title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = JOURNEY_PATH
	title.settings_path = PATH
	root.add_child(title)
	current_scene = title
	await create_timer(0.3,true).timeout
	click(title.settings_button)
	await create_timer(0.3,true).timeout
	panel = title._settings_panel
	check(panel.values==saved and panel.volume_sliders.master.value==65 and panel.volume_sliders.music.value==35,"Recreated title restores saved controls and audio")
	if DisplayServer.get_name()!="headless": check(root.size==Vector2i(1280,720),"Startup branch restores saved display preferences")
	for dimensions in [Vector2i(1152,648),Vector2i(960,720)]:
		root.size = dimensions
		await create_timer(0.2,true).timeout
		var bounds: Rect2 = panel.panel.get_global_rect()
		check(root.get_visible_rect().encloses(bounds),"Settings fits 16:9 and 4:3")
		await capture("layout_%dx%d" % [dimensions.x,dimensions.y])
	click(panel.reset_button)
	await create_timer(0.2,true).timeout
	check(panel.values==PREFS.defaults() and not AudioServer.is_bus_mute(0) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(PREFS.UI_BUS)),"Reset restores actual audio and display defaults")
	panel.save_path = "user://missing_settings_test_directory/settings.cfg"
	click(panel.back_button)
	check(panel.visible and panel.hint.text=="保存失败，请重试","Failed save stays open for retry")
	panel.save_path = PATH
	key_action("ui_cancel")
	check(not panel.visible and PREFS.read_preferences(PATH)==PREFS.defaults(),"Esc saves defaults and returns")
	var font := preload("res://assets/fonts/noto_sans_sc_settings.ttf")
	for label in panel.find_children("*","Label",true,false):
		for character in label.text: check(font.has_char(character.unicode_at(0)),"Settings label glyph: "+character)
	check(original_preferences==bytes_at(PREFS.DEFAULT_PATH) and original_journey==bytes_at(JOURNEY.DEFAULT_PATH) and original_achievements==bytes_at("user://achievements.cfg"),"Personal settings, journey and achievements stay byte-for-byte unchanged")
	title.queue_free()
	await create_timer(0.15,true).timeout
	DirAccess.remove_absolute(PATH)
	JOURNEY.erase(JOURNEY_PATH)
	print("SETTINGS CHECK: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
