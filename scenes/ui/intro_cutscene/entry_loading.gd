extends CanvasLayer
## Shared loading presentation; resource, warm-up and readiness work drive progress.
signal cancelled
signal card_selected(index: int, path: String)
signal progress_changed(value: float)
const CARD_BAG := preload("res://scenes/ui/intro_cutscene/loading_card_bag.gd")
const FRAME_CACHE := preload("res://scenes/gameplay/prepared_sprite_frames.gd")
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
var sources_ready := false
var preparing_sources := false
var selected_card := -1
var background: TextureRect
var cover: ColorRect
var status_group: Control
var progress_target := 0.0
var display_progress := 0.0
var ready_to_finish := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	# Choose the finished card before attaching/drawing any presentation nodes.
	selected_card = CARD_BAG.take()
	background = TextureRect.new()
	background.texture = CARD_BAG.CARDS[selected_card]
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover = ColorRect.new()
	cover.color = Color("141617")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.theme = preload("res://scenes/gameplay/gameplay_ui_theme.tres")
	add_child(cover)
	cover.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_group = Control.new()
	status_group.name = "LoadingStatus"
	status_group.size = Vector2(120,100)
	status_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(status_group)
	robot = TextureRect.new()
	robot.name = "LoadingXiaoyi"
	robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	robot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	robot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_group.add_child(robot)
	robot_animation = preload("res://scenes/ui/intro_cutscene/loading_robot_animation.gd").new()
	robot_animation.update(robot,robot_clock,true)
	var track := ColorRect.new()
	track.position = Vector2(0,68)
	track.size = Vector2(120,5)
	track.color = Color("333736")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_group.add_child(track)
	fill = ColorRect.new()
	fill.color = Color("b58d53")
	fill.size = Vector2(0,5)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	caption = Label.new()
	caption.position = Vector2(0,78)
	caption.size = Vector2(120,22)
	caption.text = "0%"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.add_theme_font_size_override("font_size",13)
	caption.add_theme_color_override("font_color",Color("c8b791"))
	status_group.add_child(caption)
	back = Button.new()
	back.text = "RETURN"
	back.size = Vector2(120,34)
	back.hide()
	back.pressed.connect(_cancel)
	cover.add_child(back)
	cover.resized.connect(_layout_status)
	_layout_status()
	card_selected.emit(selected_card,background.texture.resource_path)

func _layout_status() -> void:
	var scale_factor := minf(cover.size.x/1280.0,cover.size.y/720.0)
	status_group.scale = Vector2.ONE*scale_factor
	status_group.position = cover.size-(Vector2(32,24)+status_group.size)*scale_factor
	back.scale = Vector2.ONE*scale_factor
	back.position = status_group.position-Vector2(0,42)*scale_factor

func begin(path: String, resource: PackedScene = null) -> void:
	target_path = path
	packed = resource
	previous_pause = get_tree().paused
	get_tree().paused = true
	if packed != null:
		_report_progress(0.60)
	elif ResourceLoader.load_threaded_request(target_path,"PackedScene") != OK:
		_fail()

func _input(_event: InputEvent) -> void:
	# Consume input across the handoff, including the click that opened this screen.
	if not failed:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	robot_clock += delta
	robot_animation.update(robot,robot_clock,true)
	_update_progress(delta)
	if switching or failed or target_path.is_empty(): return
	elapsed += delta
	if packed == null:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(target_path,progress)
		if not progress.is_empty(): _report_progress(0.60*clampf(float(progress[0]),0.0,1.0))
		if status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			_fail()
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			packed = ResourceLoader.load_threaded_get(target_path) as PackedScene
			if packed == null:
				_fail()
				return
			_report_progress(0.60)
	if packed != null and not preparing_sources:
		preparing_sources = true
		_prepare_sources()
	if packed != null and sources_ready and elapsed >= minimum_seconds:
		_switch_scene()

func _report_progress(value: float) -> void:
	progress_target = maxf(progress_target,clampf(value,0.0,1.0 if ready_to_finish else 0.99))

func _update_progress(delta: float) -> void:
	# Visual easing can lag completed work, but never invents work or moves backward.
	display_progress = minf(progress_target,display_progress+delta*1.8)
	fill.size.x = display_progress*120.0
	if not failed:
		caption.text = "%d%%" % (100 if ready_to_finish and display_progress >= 1.0 else mini(99,floori(display_progress*100.0)))
	progress_changed.emit(display_progress)

func _on_source_warmed(completed: int, total: int) -> void:
	_report_progress(0.60+0.25*float(completed)/maxi(total,1))

func _prepare_sources() -> void:
	if target_path.begins_with("res://scenes/gameplay/"):
		await FRAME_CACHE.warm_loading_sources(self,_on_source_warmed)
	_report_progress(0.85)
	sources_ready = true

func _observe_initialization(destination: Node) -> void:
	if destination.has_method("get_entry_progress"):
		_report_progress(0.88+0.09*clampf(float(destination.get_entry_progress()),0,1))

func _switch_scene() -> void:
	switching = true
	_report_progress(0.85)
	await get_tree().process_frame
	if get_tree().change_scene_to_packed(packed) != OK:
		_fail()
		return
	await get_tree().scene_changed
	var destination := get_tree().current_scene
	_report_progress(0.88)
	if destination != null and destination.has_method("is_entry_ready"):
		while not destination.is_entry_ready():
			_observe_initialization(destination)
			await get_tree().process_frame
	await _finish_loading()

func _finish_loading() -> void:
	_report_progress(0.98)
	await get_tree().process_frame
	await get_tree().process_frame
	ready_to_finish = true
	_report_progress(1.0)
	while display_progress < 1.0: await get_tree().process_frame
	# Leave a real full frame at 100% after the destination is prepared for control.
	await get_tree().create_timer(0.15,true).timeout
	FRAME_CACHE.release_loading_sources()
	get_tree().paused = previous_pause
	queue_free()

func _fail() -> void:
	FRAME_CACHE.release_loading_sources()
	failed = true
	caption.text = "LOAD FAILED"
	back.show()
	back.grab_focus()

func _cancel() -> void:
	FRAME_CACHE.release_loading_sources()
	get_tree().paused = previous_pause
	cancelled.emit()
	queue_free()
