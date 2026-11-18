extends CanvasLayer

signal finished(token: int, completed: bool)

const FRAMES: Array[Texture2D] = [
	preload("res://assets/backgrounds/abdomen_voice/01.webp"),
	preload("res://assets/backgrounds/abdomen_voice/02.webp"),
	preload("res://assets/backgrounds/abdomen_voice/03.webp"),
	preload("res://assets/backgrounds/abdomen_voice/04.webp"),
	preload("res://assets/backgrounds/abdomen_voice/05.webp"),
]
const LIGHT_CENTERS: Array[Vector2] = [
	Vector2(0.49, 0.816),
	Vector2.ZERO,
	Vector2(0.52, 0.56),
	Vector2(0.49, 0.08),
	Vector2(0.47, 0.80),
]
const DIALOGUE_EFFECT := preload("res://scenes/gameplay/abdomen_dialogue.gdshader")
const EFFECT_POINTS: Array[Vector4] = [
	Vector4(0.30, 0.80, 0.68, 0.80),
	Vector4(0.24, 0.43, 0.63, 0.43),
	Vector4(0.224, 0.25, 0.0, 0.0),
	Vector4(0.50, 0.38, 0.0, 0.0),
	Vector4(0.49, 0.58, 0.56, 0.58),
	Vector4(0.17, 0.45, 0.54, 0.45),
	Vector4(0.66, 0.54, 0.0, 0.0),
	Vector4(0.46, 0.65, 0.58, 0.53),
]
const FONT := preload("res://assets/fonts/lxgw_wenkai.ttf")
const LINES: Array[String] = [
	"小一，你听见了吗？你的脚下？",
	"这是困住我的腹腔。那些管子每响一次，铁壁就收紧一点。",
	"我受了伤，已经没有力气自己出去了。",
	"我把声音送出去过很多次，我终于听见了你的脚步。",
	"谢谢你回来，小一。勇敢向前吧，迎着光亮。你脚下那一点光，我还能替你留住。",
]

var page := 0
var _token := -1
var _elapsed := 0.0
var _art: TextureRect
var _light: TextureRect
var _subtitle: Label
var _next: Button
var _dialogue: Array[String] = []
var _illustrations: Array[Texture2D] = []
var _effect := ShaderMaterial.new()
var _first_shot := 0
var _confirm := ""

func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	set_process(false)

	var backdrop := ColorRect.new()
	backdrop.color = Color("0b1011")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_effect.shader = DIALOGUE_EFFECT
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.offset_bottom = -128
	backdrop.add_child(_art)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.34), Color(1.0, 1.0, 1.0, 0.0)])
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	_light = TextureRect.new()
	_light.texture = glow
	_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_light)

	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.anchor_left = 0.13
	footer.anchor_right = 0.87
	footer.offset_top = -16
	footer.offset_bottom = -16
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.07, 0.07, 0.93)
	panel.border_color = Color("687670")
	panel.border_width_top = 1
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 10
	panel.content_margin_bottom = 8
	footer.add_theme_stylebox_override("panel", panel)
	backdrop.add_child(footer)
	footer.resized.connect(func(): _art.offset_bottom = -maxf(128.0, footer.size.y + 24.0))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	footer.add_child(column)
	_subtitle = Label.new()
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", FONT)
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", Color("eef0e9"))
	column.add_child(_subtitle)

	_next = Button.new()
	_next.theme = preload("res://scenes/gameplay/gameplay_ui_theme.tres")
	_next.focus_mode = Control.FOCUS_NONE
	_next.flat = true
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.pressed.connect(_advance)
	column.add_child(_next)

func present(token: int, dialogue: Array[String] = [], illustrations: Array[Texture2D] = [], confirm := "返回", first_shot := 0) -> void:
	_dialogue = dialogue
	_illustrations = illustrations
	_first_shot = first_shot
	_confirm = confirm
	_token = token
	page = 0
	_show_page()
	show()
	set_process(true)

func dismiss() -> void:
	_token = -1
	_art.material = null
	_illustrations = []
	_dialogue = []
	hide()
	set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if _token >= 0 and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	if _token < 0:
		return
	if page == _page_count() - 1:
		finished.emit(_token, true)
		return
	page += 1
	_show_page()

func _page_count() -> int:
	return LINES.size() if _dialogue.is_empty() else _dialogue.size()

func _show_page() -> void:
	_elapsed = 0.0
	_art.offset_left = 0
	_art.offset_right = 0
	_light.modulate.a = 0.0
	_next.text = "[E] " + ("继续" if page < _page_count() - 1 else _confirm)
	if _dialogue.is_empty():
		_art.material = null
		_art.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
		_art.texture = FRAMES[page]
		_subtitle.text = LINES[page]
		_light.visible = page != 1
		return
	_light.hide()
	var shot := _first_shot + page
	var points := EFFECT_POINTS[shot]
	_effect.set_shader_parameter("shot", shot)
	_effect.set_shader_parameter("target", Vector2(points.x, points.y))
	_effect.set_shader_parameter("secondary", Vector2(points.z, points.w))
	_effect.set_shader_parameter("elapsed", 0.0)
	_art.texture = _illustrations[page]
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.material = _effect
	_subtitle.text = _dialogue[page]

func _process(delta: float) -> void:
	_elapsed += delta
	if not _illustrations.is_empty():
		_effect.set_shader_parameter("elapsed", _elapsed)
		return
	var phase := fposmod(_elapsed, 2.55)
	if page == 1:
		var jolt := exp(-pow((phase - 0.76) / 0.18, 2))
		var sway := roundf(2.0 * jolt * sin(phase * 70.0))
		_art.offset_left = sway
		_art.offset_right = sway
		return
	var center := LIGHT_CENTERS[page]
	var scale_factor := minf(_art.size.x / _art.texture.get_width(), _art.size.y / _art.texture.get_height())
	var art_size := _art.texture.get_size() * scale_factor
	_light.size = art_size * Vector2(0.065, 0.035)
	_light.position = (_art.size - art_size) * 0.5 + art_size * center - _light.size * 0.5
	var flash := exp(-pow((phase - 0.76) / 0.11, 2))
	var echo := exp(-pow((phase - 1.02) / 0.12, 2))
	match page:
		0:
			_light.modulate.a = 0.04 + 0.69 * flash + 0.23 * echo
		2:
			_light.modulate.a = (0.14 + 0.5 * flash + 0.2 * echo) * exp(-_elapsed * 0.7)
		3:
			_light.modulate.a = 0.28 * exp(-pow((_elapsed - 1.45) / 0.24, 2))
		4:
			_light.modulate.a = 0.35 * smoothstep(0.0, 0.8, _elapsed)
