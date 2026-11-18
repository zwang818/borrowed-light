extends CanvasLayer

const ART := preload("res://assets/backgrounds/enemy_intro/cleaner-card-v2.png")
const UI_THEME := preload("res://scenes/gameplay/gameplay_ui_theme.tres")
const FADE_SECONDS := 0.5
const CARD_SIZE := Vector2(836, 470.5)

var _card: TextureRect

func _ready() -> void:
	layer = 24
	hide()

	_card = TextureRect.new()
	_card.texture = ART
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.size = CARD_SIZE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	var details := ColorRect.new()
	details.color = Color("01282d")
	details.position = Vector2(536, 184)
	details.size = Vector2(282, 158)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(details)

	_add_text(details, "来路", 0, 19, Color("f6bf70"))
	_add_text(details, "腹腔维护单元", 27, 23, Color("f4ebd8"))
	_add_text(details, "能力", 77, 19, Color("f6bf70"))
	_add_text(details, "蛛网限制移动，近身攻击", 104, 23, Color("f4ebd8"))
	get_viewport().size_changed.connect(_layout)
	_layout()

func _add_text(parent: Control, value: String, y: float, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.theme = UI_THEME
	label.text = value
	label.position = Vector2(10, y)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func present(duration: float) -> void:
	_card.modulate.a = 1.0
	show()
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_interval(duration - FADE_SECONDS)
	fade.tween_property(_card, "modulate:a", 0.0, FADE_SECONDS)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x * 0.68 / CARD_SIZE.x, viewport_size.y * 0.65 / CARD_SIZE.y)
	_card.scale = Vector2.ONE * factor
	_card.position = (viewport_size - CARD_SIZE * factor) * 0.5
