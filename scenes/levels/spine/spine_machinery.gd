@tool
extends Node2D
## Reuses the graybox machine anchors and animation phase for the environment art.
const SKIN = preload("res://scenes/levels/spine/spine_machine_skin.gd")
var skin: Node2D
@export_enum("fan", "piston", "distributor") var kind := "fan"
@export var phase := 0.0
var clock := 0.0
var art_frame := -1
var view_probe: VisibleOnScreenNotifier2D
var art_enabled := false:
	set(value):
		art_enabled = value
		if value and skin == null:
			skin = SKIN.new()
			skin.name = "MachineSkin"
			add_child(skin)
			skin.build()
		if skin != null:
			skin.visible = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	view_probe = VisibleOnScreenNotifier2D.new()
	view_probe.rect = Rect2(-106, -103, 212, 206)
	view_probe.screen_entered.connect(_update_pose)
	add_child(view_probe)

func _process(delta: float) -> void:
	clock += delta
	var frame := int(clock * 18.0)
	if frame != art_frame and view_probe.is_on_screen():
		art_frame = frame
		_update_pose()

func _update_pose() -> void:
	if art_enabled and skin != null:
		skin.set_pose(floorf(clock * 18.0) / 18.0, phase)
	else:
		queue_redraw()

func _draw() -> void:
	if art_enabled:
		return
	var pale := Color("657b81")
	var dark := Color("20333d")
	draw_rect(Rect2(-90,-90,180,180), Color("172730"))
	draw_rect(Rect2(-90,-90,180,180), pale, false, 4)
	if kind == "fan":
		draw_circle(Vector2.ZERO, 72, dark)
		draw_arc(Vector2.ZERO,74,0,TAU,48,pale,4)
		for i in range(4):
			var angle := clock * TAU / 6 + phase + i * PI / 2
			var direction := Vector2.from_angle(angle)
			draw_line(direction * 16,direction * 64,Color("435b65"),23)
		draw_circle(Vector2.ZERO,16,pale)
	else:
		for side in [-1,1]:
			var x: float = side * 42.0
			var travel: float = sin(clock * TAU / 4 + phase) * side * 24
			draw_rect(Rect2(x-15,-64,30,128),dark)
			draw_rect(Rect2(x-9,-32+travel,18,64),pale)
			draw_rect(Rect2(x-22,-44+travel,44,12),Color("405761"))
	for x in [-76,76]:
		for y in [-76,76]: draw_circle(Vector2(x,y),4,pale)
