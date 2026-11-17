extends Control
## Title presentation and the archive empty state. Assign start_scene for gameplay.

signal start_requested
signal archive_opened
const JOURNEY_SAVE := preload("res://scenes/gameplay/journey_save.gd")
@export var game_save_path := JOURNEY_SAVE.DEFAULT_PATH
var _save_data: Dictionary = {}
var _archive_action := ""
var _load_button: Button
var _new_button: Button
var _delete_button: Button

@export_group("Presentation")
@export var design_size := Vector2(1280.0, 720.0)
@export var lamp_pulse_enabled := true
@export_range(0.0, 0.3, 0.01) var lamp_pulse_amount := 0.08
@export_range(0.1, 3.0, 0.1) var lamp_pulse_speed := 0.8
@export var robot_motion_enabled := true
@export_range(0.0, 0.04, 0.002) var robot_sway_amount := 0.012

@export_group("Scene Navigation")
@export var start_scene: PackedScene

@export_group("Audio")
@export var title_bgm: AudioStream = preload("res://assets/audio/title_bgm.wav")
@export_range(0.0, 1.0, 0.05) var title_bgm_volume := 0.35

@onready var presentation: Control = $Presentation
@onready var lamp_glow: TextureRect = $Presentation/WorldLayers/RobotAnchor/LampGlow
@onready var robot: TextureRect = $Presentation/WorldLayers/RobotAnchor/Robot
@onready var archive_button: Button = $Presentation/WorldLayers/RobotAnchor/SaveButton
@onready var archive_caption: Label = $Presentation/WorldLayers/RobotAnchor/SaveCaption
@onready var archive_overlay: Control = $Presentation/SaveOverlay
@onready var archive_close: Button = $Presentation/SaveOverlay/ArchivePanel/CloseButton
@onready var start_button: Button = $Presentation/Menu/Buttons/StartButton
@onready var quit_button: Button = $Presentation/Menu/Buttons/QuitButton
@onready var status_label: Label = $Presentation/Menu/Status

var _bgm_player := AudioStreamPlayer.new()
var _elapsed := 0.0
var _is_starting := false
var _robot_animation
var _robot_hovered := false
var _robot_emphasis := 0.0
var _previous_focus: Control


func _ready() -> void:
	_robot_animation = preload("res://scenes/ui/title_screen/xiaoyi_title_animation.gd").new()
	_robot_animation.update(robot, 0.0, robot_motion_enabled)
	resized.connect(_fit_presentation)
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	archive_button.pressed.connect(_open_archive)
	archive_close.pressed.connect(_close_archive)
	archive_button.mouse_entered.connect(func(): _robot_hovered = true)
	archive_button.mouse_exited.connect(func(): _robot_hovered = false)
	start_button.disabled = start_scene == null
	status_label.visible = start_scene == null
	_fit_presentation()
	_init_bgm()
	_build_archive_actions()
	_refresh_archive()

func _build_archive_actions() -> void:
	var panel: Control = archive_close.get_parent()
	panel.position.y = 140
	panel.size.y = 440
	var font: Font = preload("res://scenes/gameplay/gameplay_ui_theme.tres").default_font
	for label in panel.find_children("*", "Label", true, false):
		label.add_theme_font_override("font", font)
	var description: Label = panel.get_node("Description")
	description.size.y = 48
	description.text = "自动保存图纸、能力、记录与管道解锁。\n读档从房间入口继续，敌人和门禁重新开始。"
	archive_close.position.y = 350
	archive_close.add_theme_font_override("font", font)
	var actions := HBoxContainer.new()
	actions.position = Vector2(38, 272)
	actions.size = Vector2(544, 44)
	actions.add_theme_constant_override("separation", 12)
	actions.theme = preload("res://scenes/gameplay/gameplay_ui_theme.tres")
	panel.add_child(actions)
	_load_button = Button.new()
	_new_button = Button.new()
	_delete_button = Button.new()
	for action in [_load_button, _new_button, _delete_button]:
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(action)
	_load_button.pressed.connect(_continue_journey)
	_new_button.pressed.connect(_new_journey)
	_delete_button.pressed.connect(_delete_journey)
	start_button.add_theme_font_override("font", font)

func _refresh_archive() -> void:
	_save_data = JOURNEY_SAVE.read_save(game_save_path)
	var has_save := not _save_data.is_empty()
	start_button.text = "继续游戏" if has_save else "开始游戏"
	var cleared: bool = has_save and _save_data.get("first_level_cleared", false)
	if cleared:
		start_button.text = "继续第二关"
	status_label.visible = cleared or start_scene == null
	if cleared:
		status_label.add_theme_font_override("font", preload("res://scenes/gameplay/gameplay_ui_theme.tres").default_font)
		status_label.text = "第一关已通关"
	_load_button.text = "读取存档"
	if cleared:
		_load_button.text = "继续第二关"
	_load_button.disabled = not has_save
	_new_button.text = "确认新旅程" if _archive_action == "new" else "开启新旅程"
	_delete_button.text = "确认删除" if _archive_action == "delete" else "删除存档"
	_delete_button.disabled = not FileAccess.file_exists(game_save_path) and not FileAccess.file_exists(game_save_path + ".bak")
	var slot: Node = archive_close.get_parent().get_node("EmptySlot")
	if has_save:
		slot.get_node("EmptyTitle").text = "第二关 · 脊柱入口" if cleared else "腹腔 · " + ("脉冲机械臂已解锁" if _save_data.pulse_learned else ("已记录图纸" if _save_data.blueprint_known else "旅程起点"))
		slot.get_node("EmptyHint").text = "%s · 管道 %d/3%s" % [_save_data.saved_at, _save_data.ducts.size(), " · 备份恢复" if _save_data.get("recovered", false) else ""]
	else:
		slot.get_node("EmptyTitle").text = "尚无存档" if _delete_button.disabled else "存档无法读取"
		slot.get_node("EmptyHint").text = "开启新旅程后自动建立记录。"
	if not _archive_action.is_empty():
		slot.get_node("EmptyHint").text = "再次点击确认将覆盖当前旅程。" if _archive_action == "new" else "再次点击确认删除，成就记录保留。"

func _continue_journey() -> void:
	if _is_starting:
		return
	var data := JOURNEY_SAVE.read_save(game_save_path)
	if data.is_empty():
		_refresh_archive()
		_open_archive()
		return
	_is_starting = true
	get_tree().set_meta("journey_session", {"path": game_save_path, "data": data})
	var loading := preload("res://scenes/ui/intro_cutscene/entry_loading.gd").new()
	loading.name = "EntryLoading"
	loading.cancelled.connect(func():
		_is_starting = false
		get_tree().remove_meta("journey_session"))
	get_tree().root.add_child(loading)
	loading.begin("res://scenes/gameplay/spine_level.tscn" if data.get("first_level_cleared",false) else JOURNEY_SAVE.SCENE)

func _new_journey() -> void:
	if _is_starting:
		return
	if (FileAccess.file_exists(game_save_path) or FileAccess.file_exists(game_save_path + ".bak")) and _archive_action != "new":
		_archive_action = "new"
		_refresh_archive()
		return
	_start_new_journey()

func _delete_journey() -> void:
	if _archive_action != "delete":
		_archive_action = "delete"
		_refresh_archive()
		return
	var error := JOURNEY_SAVE.erase(game_save_path)
	_archive_action = ""
	_refresh_archive()
	if error != OK:
		archive_close.get_parent().get_node("EmptySlot/EmptyHint").text = "删除失败，请检查文件权限。"


func _init_bgm() -> void:
	add_child(_bgm_player)
	_bgm_player.volume_db = linear_to_db(title_bgm_volume)
	# Godot 4: loop 必须在 .import 的 edit/loop_mode 上设置，AudioStreamPlayer 本身没有 loop 属性
	_bgm_player.stream = title_bgm
	if title_bgm != null:
		_bgm_player.play()
	else:
		push_warning("Title BGM stream not assigned;  assign in scene Inspector or script.")


func _process(delta: float) -> void:
	_elapsed += delta
	var emphasized := (_robot_hovered or archive_button.has_focus()) and not archive_overlay.visible
	_robot_emphasis = move_toward(_robot_emphasis, 1.0 if emphasized else 0.0, delta * 5.0)
	var pulse := sin(_elapsed * lamp_pulse_speed) * lamp_pulse_amount if lamp_pulse_enabled else 0.0
	lamp_glow.modulate.a = 0.78 + pulse + _robot_emphasis * 0.12
	_robot_animation.update(robot, _elapsed, robot_motion_enabled)
	robot.scale = Vector2.ONE * (1.0 + _robot_emphasis * 0.035)
	robot.modulate = Color.WHITE.lerp(Color(1.15, 1.12, 1.04), _robot_emphasis)
	archive_caption.modulate.a = 0.8 + _robot_emphasis * 0.2


func _input(event: InputEvent) -> void:
	if archive_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_archive()
		get_viewport().set_input_as_handled()


func _open_archive() -> void:
	_archive_action = ""
	_refresh_archive()
	_previous_focus = get_viewport().gui_get_focus_owner()
	archive_overlay.show()
	# Prevent keyboard focus from leaving the modal and triggering background actions.
	archive_button.focus_mode = Control.FOCUS_NONE
	quit_button.focus_mode = Control.FOCUS_NONE
	start_button.focus_mode = Control.FOCUS_NONE
	archive_close.grab_focus()
	archive_opened.emit()


func _close_archive() -> void:
	_archive_action = ""
	archive_overlay.hide()
	archive_button.focus_mode = Control.FOCUS_ALL
	quit_button.focus_mode = Control.FOCUS_ALL
	start_button.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(_previous_focus):
		_previous_focus.grab_focus()
	else:
		archive_button.grab_focus()


func _fit_presentation() -> void:
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return
	var fit_scale := minf(size.x / design_size.x, size.y / design_size.y)
	presentation.scale = Vector2.ONE * fit_scale
	presentation.position = (size - design_size * fit_scale) * 0.5


@onready var _intro_scene_path := "res://scenes/ui/intro_cutscene/intro_cutscene.tscn"


func _on_start_pressed() -> void:
	if start_scene == null or _is_starting or archive_overlay.visible:
		return
	if not JOURNEY_SAVE.read_save(game_save_path).is_empty():
		_continue_journey()
	elif FileAccess.file_exists(game_save_path) or FileAccess.file_exists(game_save_path + ".bak"):
		_open_archive()
	else:
		_start_new_journey()

func _start_new_journey() -> void:
	_is_starting = true
	start_requested.emit()
	get_tree().set_meta("journey_session", {"path": game_save_path})
	var error := get_tree().change_scene_to_file(_intro_scene_path)
	if error != OK:
		get_tree().remove_meta("journey_session")
		_is_starting = false
		push_error("Title could not open intro cutscene: %s" % error)


func _on_quit_pressed() -> void:
	if not archive_overlay.visible:
		get_tree().quit()
