extends Control
## Title presentation and the archive empty state. Assign start_scene for gameplay.

signal start_requested
signal archive_opened

@export_group("Presentation")
@export var design_size := Vector2(1280.0, 720.0)
@export var lamp_pulse_enabled := true
@export_range(0.0, 0.3, 0.01) var lamp_pulse_amount := 0.08
@export_range(0.1, 3.0, 0.1) var lamp_pulse_speed := 0.8
@export var robot_motion_enabled := true
@export_range(0.0, 0.04, 0.002) var robot_sway_amount := 0.012

@export_group("Scene Navigation")
@export var start_scene: PackedScene

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

var _elapsed := 0.0
var _is_starting := false
var _robot_hovered := false
var _robot_emphasis := 0.0
var _previous_focus: Control


func _ready() -> void:
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


func _process(delta: float) -> void:
	_elapsed += delta
	var emphasized := (_robot_hovered or archive_button.has_focus()) and not archive_overlay.visible
	_robot_emphasis = move_toward(_robot_emphasis, 1.0 if emphasized else 0.0, delta * 5.0)
	var pulse := sin(_elapsed * lamp_pulse_speed) * lamp_pulse_amount if lamp_pulse_enabled else 0.0
	lamp_glow.modulate.a = 0.78 + pulse + _robot_emphasis * 0.12
	robot.rotation = sin(_elapsed * 1.25) * robot_sway_amount if robot_motion_enabled else 0.0
	robot.position.y = sin(_elapsed * 1.5) * 1.2 if robot_motion_enabled else 0.0
	robot.scale = Vector2.ONE * (1.0 + _robot_emphasis * 0.035)
	robot.modulate = Color.WHITE.lerp(Color(1.15, 1.12, 1.04), _robot_emphasis)
	archive_caption.modulate.a = 0.8 + _robot_emphasis * 0.2


func _input(event: InputEvent) -> void:
	if archive_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_archive()
		get_viewport().set_input_as_handled()


func _open_archive() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	archive_overlay.show()
	# Prevent keyboard focus from leaving the modal and triggering background actions.
	archive_button.focus_mode = Control.FOCUS_NONE
	quit_button.focus_mode = Control.FOCUS_NONE
	start_button.focus_mode = Control.FOCUS_NONE
	archive_close.grab_focus()
	archive_opened.emit()


func _close_archive() -> void:
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


func _on_start_pressed() -> void:
	if start_scene == null or _is_starting or archive_overlay.visible:
		return
	_is_starting = true
	start_requested.emit()
	var error := get_tree().change_scene_to_packed(start_scene)
	if error != OK:
		_is_starting = false
		push_error("Title could not open start scene: %s" % error)


func _on_quit_pressed() -> void:
	if not archive_overlay.visible:
		get_tree().quit()
