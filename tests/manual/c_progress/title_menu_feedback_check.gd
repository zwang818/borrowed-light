extends SceneTree
var failures: Array[String] = []
var view: Viewport
func _initialize() -> void:
	root.size = Vector2i(1152,648)
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)
func move_to(button: Button) -> void:
	var event := InputEventMouseMotion.new()
	event.position = button.get_global_rect().get_center()
	view.push_input(event,true)
func mouse(button: Button, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = down
	view.push_input(event,true)
func click(button: Button) -> void:
	move_to(button)
	mouse(button,true)
	mouse(button,false)
func capture(label: String) -> void:
	var folder := OS.get_environment("UI_FEEDBACK_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("ui_feedback_"+label+".png"))
func run() -> void:
	view = root
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = "user://test_ui_feedback_empty.json"
	view.add_child(title)
	current_scene = title
	await create_timer(0.3,true).timeout
	var bounds: Rect2 = title.start_button.get_global_rect()
	move_to(title.start_button)
	await create_timer(0.2,true).timeout
	check(title.start_button.get_global_rect()==bounds,"Hover preserves actual hit rectangle and layout")
	check(title.start_button.get_node("ButtonFeedback").hover_mix > 0.85,"Pointer hover produces visible animated emphasis")
	await capture("title_hover")
	click(title.archive_button)
	await create_timer(0.3,true).timeout
	check(title.archive_overlay.visible and title.start_button.focus_mode==Control.FOCUS_NONE,"Archive modal blocks background keyboard focus")
	await capture("archive")
	click(title.start_button)
	check(not title._is_starting,"Animated overlay still blocks background clicks")
	var empty_before: bool = title._load_button.disabled
	click(title._load_button)
	check(empty_before and not title._is_starting,"Disabled load remains inactive")
	var close_bounds: Rect2 = title.archive_close.get_global_rect()
	mouse(title.archive_close,true)
	await create_timer(0.09,true).timeout
	check(title.archive_close.get_global_rect()==close_bounds,"Press feedback preserves actual hit rectangle")
	check(title.archive_close.get_node("ButtonFeedback").press_mix > 0.8,"Mouse down produces visible press feedback")
	await capture("title_down")
	mouse(title.archive_close,false)
	await process_frame
	check(not title.archive_overlay.visible,"Archive close works with animated buttons")
	title.queue_free()
	await process_frame
	print("TITLE FEEDBACK CHECK: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
