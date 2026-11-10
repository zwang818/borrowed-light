extends CanvasLayer
## Root overlay survives the intro until the first gameplay frames are ready.
signal cancelled
var minimum_seconds := 3.0
var elapsed := 0.0
var target_path := ""
var packed: PackedScene
var previous_pause := false
var switching := false
var failed := false
var fill: ColorRect
var caption: Label
var back: Button
var robot: TextureRect
var robot_animation
var robot_clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	var cover := ColorRect.new()
	cover.color = Color("10191c")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.theme = preload("res://scenes/gameplay/gameplay_ui_theme.tres")
	center.add_child(column)
	var robot_slot := Control.new()
	robot_slot.custom_minimum_size = Vector2(120, 148)
	robot_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(robot_slot)
	var anchor := Control.new()
	anchor.position.x = 12
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	robot_slot.add_child(anchor)
	robot = TextureRect.new()
	robot.name = "LoadingXiaoyi"
	robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	robot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	robot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(robot)
	robot_animation = preload("res://scenes/ui/intro_cutscene/loading_robot_animation.gd").new()
	robot_animation.update(robot, robot_clock, true)
	caption = Label.new()
	caption.text = "LOADING"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var track := ColorRect.new()
	track.color = Color("dddddd")
	track.custom_minimum_size = Vector2(120, 20)
	column.add_child(track)
	fill = ColorRect.new()
	fill.color = Color.BLACK
	fill.size = Vector2(0, 20)
	track.add_child(fill)
	back = Button.new()
	back.text = "RETURN"
	back.hide()
	back.pressed.connect(_cancel)
	column.add_child(back)

func begin(path: String, resource: PackedScene = null) -> void:
	target_path = path
	packed = resource
	previous_pause = get_tree().paused
	get_tree().paused = true
	if packed == null and ResourceLoader.load_threaded_request(target_path, "PackedScene") != OK:
		_fail()

func _input(_event: InputEvent) -> void:
	# Consume input across the handoff, including the click that opened this screen.
	if not failed:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Keep the greeting moving while gameplay is paused or the scene is switching.
	robot_clock += delta
	robot_animation.update(robot, robot_clock, true)
	if switching or failed or target_path.is_empty():
		return
	elapsed += delta
	# Reserve the last tenth for a ready gameplay scene; never wrap back to zero.
	fill.size.x = 108.0 * clampf(elapsed / maxf(minimum_seconds, 0.01), 0.0, 1.0)
	if packed == null:
		var status := ResourceLoader.load_threaded_get_status(target_path)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail()
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			packed = ResourceLoader.load_threaded_get(target_path) as PackedScene
			if packed == null:
				_fail()
	if packed != null and elapsed >= minimum_seconds:
		_switch_scene()

func _switch_scene() -> void:
	switching = true
	# Keep the bar below full during main-thread scene instantiation.
	await get_tree().process_frame
	if get_tree().change_scene_to_packed(packed) != OK:
		_fail()
		return
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	var completion := create_tween()
	completion.tween_property(fill, "size:x", 120.0, 0.25)
	await completion.finished
	get_tree().paused = previous_pause
	queue_free()

func _fail() -> void:
	failed = true
	caption.text = "LOAD FAILED"
	back.show()
	back.grab_focus()

func _cancel() -> void:
	get_tree().paused = previous_pause
	cancelled.emit()
	queue_free()
