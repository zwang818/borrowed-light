extends Control
## Pure HUD view: one mechanical heart per HP in the current 3-HP game.
## Fractional snapshots are supported visually; this component never deals damage.
const MASK := [
	"0011100011100", "0111110111110", "1111111111111",
	"1111111111111", "1111111111111", "0111111111110",
	"0011111111100", "0001111111000", "0000111110000",
	"0000011100000", "0000001000000",
]
var current_health := 3.0
var maximum_health := 3.0
var _initialized := false
var _damage_remaining := 0.0
var _pulse_time := 0.0
var _value: Label
var _status: Label

func _ready() -> void:
	custom_minimum_size = Vector2(252, 82)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var title := _label("机体耐久", Vector2(16, 10), 12, Color("b5c3b8"))
	title.size = Vector2(110, 20)
	_value = _label("", Vector2(158, 10), 12, Color("c6d2c6"))
	_value.size = Vector2(78, 20)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status = _label("", Vector2(160, 42), 12, Color("9fbcb4"))
	_status.size = Vector2(76, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_labels()

func _label(text: String, position_in_panel: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_in_panel
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func set_health(value: float, maximum: float) -> void:
	maximum = maxf(maximum, 1)
	value = clampf(value, 0, maximum)
	if _initialized and is_equal_approx(value, current_health) and is_equal_approx(maximum, maximum_health):
		return
	if _initialized and value < current_health:
		_damage_remaining = 0.3
	elif value >= current_health:
		_damage_remaining = 0.0
	current_health = value
	maximum_health = maximum
	_initialized = true
	_refresh_labels()
	queue_redraw()

func heart_count() -> int:
	return clampi(ceili(maximum_health), 1, 6)

func heart_fill(index: int) -> float:
	var capacity := maximum_health / heart_count()
	return clampf((current_health - index * capacity) / capacity, 0, 1)

func _refresh_labels() -> void:
	if not is_instance_valid(_value):
		return
	_value.text = "HP %s / %s" % [str(current_health).trim_suffix(".0"), str(maximum_health).trim_suffix(".0")]
	_status.text = "离线" if current_health <= 0 else ("危急" if current_health <= 1 else "稳定")
	_status.modulate = Color("f1aa83") if current_health <= 1 else Color.WHITE

func _process(delta: float) -> void:
	if current_health > 0 and current_health <= 1:
		_pulse_time += delta
		queue_redraw()
	if _damage_remaining > 0:
		_damage_remaining = maxf(0, _damage_remaining - delta)
		queue_redraw()

func _occupied(x: int, y: int) -> bool:
	return x >= 0 and x < 13 and y >= 0 and y < MASK.size() and MASK[y][x] == "1"

func _draw_heart(origin: Vector2, fill: float, pixel: float) -> void:
	var core := Color("d99564")
	if current_health > 0 and current_health <= 1:
		core = core.lerp(Color("f2b37b"), (sin(_pulse_time * TAU * 0.8) + 1) * 0.12)
	if _damage_remaining > 0:
		core = core.lerp(Color("ffe2b1"), _damage_remaining / 0.3)
	var split := roundi(13 * fill)
	for y in MASK.size():
		for x in 13:
			if not _occupied(x, y):
				continue
			var border := not _occupied(x - 1, y) or not _occupied(x + 1, y) or not _occupied(x, y - 1) or not _occupied(x, y + 1)
			var color := Color("72867e") if border else Color("16292e")
			if border and y > 5:
				color = Color("3f5759")
			if not border and x < split:
				color = core.darkened(0.22 if y > 5 else 0)
				if y == 2 and x in [2, 3, 8, 9]:
					color = Color("f1d6a3")
			draw_rect(Rect2(origin + Vector2(x, y) * pixel, Vector2.ONE * pixel), color)
	# Tiny casing fasteners reinforce the mechanical rather than organic shape.
	for x in [2, 10]:
		draw_rect(Rect2(origin + Vector2(x, 3) * pixel, Vector2.ONE * pixel), Color("a9b3a0"))

func _draw() -> void:
	# Dark metal instrument plate, stepped corners and discrete brass fasteners.
	var w := size.x
	var h := size.y
	draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(w - 6, 0), Vector2(w, 6), Vector2(w, h - 6), Vector2(w - 6, h), Vector2(6, h), Vector2(0, h - 6), Vector2(0, 6)]), Color(0.035, 0.07, 0.08, 0.95))
	draw_line(Vector2(7, 1), Vector2(w - 7, 1), Color("6e817b"), 1)
	draw_line(Vector2(7, h - 2), Vector2(w - 7, h - 2), Color("273e43"), 2)
	draw_line(Vector2(1, 7), Vector2(1, h - 7), Color("465e60"), 1)
	draw_line(Vector2(w - 2, 7), Vector2(w - 2, h - 7), Color("2d464c"), 2)
	draw_rect(Rect2(16, 33, w - 32, 1), Color("30494c"))
	for x in [7, w - 10]:
		for y in [7, h - 10]:
			draw_rect(Rect2(x, y, 3, 3), Color("8f8265"))
	var count := heart_count()
	var pixel := 2.0 if count <= 4 else 1.5
	var pitch := 13 * pixel + 8
	for i in count:
		_draw_heart(Vector2(18 + i * pitch, 44), heart_fill(i), pixel)
	if count > 4 and is_instance_valid(_status):
		_status.hide()
