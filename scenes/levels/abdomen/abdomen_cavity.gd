@tool
extends Node2D
## Deep infrastructure is a background, never a walkable surface or a collider.
const CAVITY = preload("res://assets/sprites/environment/abdomen/service_cavity.png")
const MOTION = preload("res://scenes/levels/abdomen/abdomen_cavity_motion.gdshader")
const STEAM = preload("res://scenes/levels/abdomen/abdomen_pipe_steam.gd")
const CLEAN = preload("res://assets/sprites/environment/abdomen/service_cavity_clean.png")
const WEB_CATALOG = preload("res://scenes/levels/abdomen/abdomen_web_catalog.gd")

@export_range(8.0, 40.0, 0.5) var cycle_seconds := 16.0
@export_range(0.25, 2.0, 0.05) var animation_speed := 1.0
@export var steam_enabled := true
@export var preview_in_editor := false
var _elapsed := 0.0
var _frame := -1
var _steam: Node2D

func _ready() -> void:
	# Unique material prevents one instance's clock from changing another instance.
	var motion_material := ShaderMaterial.new()
	motion_material.shader = MOTION
	motion_material.set_shader_parameter("clean_cavity", CLEAN)
	var regions := PackedVector4Array()
	for rect in WEB_CATALOG.CAVITY_REGIONS:
		regions.append(Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y))
	motion_material.set_shader_parameter("web_regions", regions)
	material = motion_material
	_steam = Node2D.new()
	_steam.name = "AmbientSteam"
	_steam.set_script(STEAM)
	add_child(_steam)
	_update_pose(0.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_elapsed = fposmod(_elapsed + delta * animation_speed, cycle_seconds)
	var frame := int(_elapsed * 12.0)
	if frame != _frame:
		_frame = frame
		_update_pose(float(frame) / 12.0)

func _update_pose(time: float) -> void:
	var phase := fposmod(time, cycle_seconds) / cycle_seconds
	if material is ShaderMaterial:
		material.set_shader_parameter("cycle_phase", phase)
	if is_instance_valid(_steam):
		_steam.visible = steam_enabled
		_steam.set("cycle_phase", phase)
		_steam.queue_redraw()

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for y in range(-1024, 4096, 640):
		for x in range(-1152, 2432, 640):
			draw_texture_rect(CAVITY, Rect2(Vector2(x, y), Vector2(640, 640)), false, Color(0.46, 0.54, 0.58, 1))
