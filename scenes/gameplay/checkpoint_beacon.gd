extends Node2D
## A non-solid beacon. Authored models can supply contact outlines in local space.
signal touched
signal activation_changed(active: bool)

const TEXTURE := preload("res://assets/sprites/ui/checkpoints/checkpoint_beacon.png")
const LAMP := preload("res://scenes/gameplay/checkpoint_lamp.gdshader")
const TOUCH_RADIUS := 22.0
const PIXEL_BOUNDS := Rect2(314, 180, 634, 891)
const WORLD_HEIGHT := 39.0
var use_default_visual := true
var contact_outlines: Array[PackedVector2Array] = []
var contact_radius := 0.0
var activated := false:
	set(value):
		activated = value
		if lamp_material != null:
			lamp_material.set_shader_parameter("activated", value)
		activation_changed.emit(value)
var lamp_material: ShaderMaterial
var contact_attempted := false
var banner: CenterContainer
var banner_text: Label
var banner_timer: Timer

func _ready() -> void:
	if not use_default_visual:
		return
	var crop := AtlasTexture.new()
	crop.atlas = TEXTURE
	crop.region = PIXEL_BOUNDS
	crop.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = crop
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * (WORLD_HEIGHT / PIXEL_BOUNDS.size.y)
	sprite.position.y = -WORLD_HEIGHT * 0.5
	lamp_material = ShaderMaterial.new()
	lamp_material.shader = LAMP
	lamp_material.set_shader_parameter("activated", activated)
	sprite.material = lamp_material
	add_child(sprite)

func check_contact(foot_position: Vector2, allow_reactivation := false) -> void:
	if not _has_contact(foot_position):
		contact_attempted = false
	elif not contact_attempted and (not activated or allow_reactivation):
		contact_attempted = true
		touched.emit()

func _has_contact(foot_position: Vector2) -> bool:
	if contact_outlines.is_empty():
		return foot_position.distance_squared_to(global_position) <= TOUCH_RADIUS * TOUCH_RADIUS
	var foot := to_local(foot_position)
	var radius_squared := contact_radius * contact_radius
	for outline in contact_outlines:
		if Geometry2D.is_point_in_polygon(foot, outline):
			return true
		for i in range(outline.size()):
			var edge := Geometry2D.get_closest_point_to_segment(foot, outline[i - 1], outline[i])
			if foot.distance_squared_to(edge) <= radius_squared:
				return true
	return false

func show_notice(message: String) -> void:
	if banner == null:
		_build_notice()
	banner_text.text = message
	banner.show()
	banner_timer.start()

func _build_notice() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 6
	add_child(canvas)
	banner = CenterContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 26.0
	canvas.add_child(banner)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.theme = preload("res://scenes/gameplay/gameplay_ui_theme.tres")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d20f5")
	style.border_color = Color("6fa489")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	plate.add_theme_stylebox_override("panel", style)
	banner.add_child(plate)
	banner_text = Label.new()
	banner_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_text.add_theme_color_override("font_color", Color("d9f2d3"))
	banner_text.add_theme_font_size_override("font_size", 21)
	plate.add_child(banner_text)
	banner_timer = Timer.new()
	banner_timer.one_shot = true
	banner_timer.wait_time = 2.5
	banner_timer.timeout.connect(banner.hide)
	add_child(banner_timer)
