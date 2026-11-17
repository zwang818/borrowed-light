extends Node2D
## Staged signal and idle pose for inspecting the A observation bay.
const SHEET = preload("res://tests/manual/b_combat/art/cleaner/side_animation.png")
const CLEANUP = preload("res://tests/manual/b_combat/sprite_frame_cleanup.gd")
const PULSE_COLOR := Color("a9e6e1")

var clock := 0.0
var spider := Vector2.ZERO
var reader := Vector2.ZERO
var observation := Vector2.ZERO
var actor: Node2D
var spider_texture: Texture2D

func configure(map: Node2D, viewer: Node2D) -> void:
	actor = viewer
	spider = map.get_node("Markers/ProtocolCleaner").global_position
	reader = map.get_node("Markers/ProtocolDemoReader").global_position
	observation = map.get_node("Markers/ProtocolObservation").global_position
	var source := SHEET.get_image()
	var cell := source.get_size() / 4
	var frame := source.get_region(Rect2i(cell * 3, cell))
	frame = CLEANUP.clean_frame(frame)
	spider_texture = ImageTexture.create_from_image(frame.get_region(frame.get_used_rect()))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3

func _process(delta: float) -> void:
	if actor.global_position.distance_squared_to(observation) <= 280.0 * 280.0:
		clock += delta
	else:
		clock = 0.0
	queue_redraw()

func _draw() -> void:
	if spider_texture == null:
		return
	var size := spider_texture.get_size() * (60.0 / spider_texture.get_width())
	draw_texture_rect(spider_texture, Rect2(spider + Vector2(-size.x * 0.5, 9.0 - size.y), size), false)
	var back_lamp := spider + Vector2(-13, -15)
	var reader_lamp := reader + Vector2(0, -7)
	var phase := fmod(clock, 5.0)
	_draw_signal(back_lamp, _lit(phase - 0.35))
	_draw_signal(reader_lamp, _lit(phase - 2.25))

func _lit(time: float) -> bool:
	return (time >= 0.0 and time < 0.18) or (time >= 0.43 and time < 0.98) or (time >= 1.23 and time < 1.41)

func _draw_signal(at: Vector2, lit: bool) -> void:
	draw_rect(Rect2(at - Vector2(5, 4), Vector2(10, 8)), Color("25323b"))
	draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 4)), PULSE_COLOR if lit else Color("557479"))
	if lit:
		draw_circle(at, 9.0, Color(0.53, 0.84, 0.85, 0.20))
