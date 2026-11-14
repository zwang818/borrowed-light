extends CanvasLayer
## First exit: full video, then the existing loading screen, then spine gameplay.
signal cancelled
const NEXT_SCENE := "res://scenes/gameplay/spine_level.tscn"
var video: VideoStreamPlayer
var handing_off := false
var previous_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 190
	previous_pause = get_tree().paused
	get_tree().paused = true
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.stream = load("res://assets/video/abdomen_to_spine.ogv")
	cover.add_child(video)
	get_viewport().size_changed.connect(_fit_video)
	_fit_video()
	video.finished.connect(_finish)
	video.play()

func _fit_video() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := minf(viewport_size.x/1152.0,viewport_size.y/648.0)
	video.size = Vector2(1152,648)*scale_factor
	video.position = (viewport_size-video.size)/2.0

func _input(_event: InputEvent) -> void:
	if not handing_off:
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if handing_off: return
	handing_off = true
	get_tree().paused = previous_pause
	var loading := preload("res://scenes/ui/intro_cutscene/entry_loading.gd").new()
	loading.name = "EntryLoading"
	loading.cancelled.connect(func():
		cancelled.emit()
		queue_free())
	get_tree().root.add_child(loading)
	loading.begin(NEXT_SCENE)
	# Remain behind loading until the old scene is replaced; no exposed gameplay frame.
	get_tree().scene_changed.connect(func(): queue_free(),CONNECT_ONE_SHOT)
