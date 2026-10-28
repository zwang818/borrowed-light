extends RefCounted
## Autonomous greeting; archive input stays on the existing sibling button.
const SHEET = preload("res://assets/sprites/title/xiaoyi_greeting.png")
const CLEANUP = preload("res://tests/manual/b_combat/sprite_frame_cleanup.gd")
var frames: Array[AtlasTexture] = []
var factor := 1.0

func _init() -> void:
	var source := SHEET.get_image()
	var cell := Vector2i(source.get_width()/4, source.get_height()/2)
	for i in range(8):
		var image := CLEANUP.clean_frame(source.get_region(Rect2i(Vector2i(i%4,i/4)*cell,cell)))
		var frame := AtlasTexture.new()
		frame.atlas = ImageTexture.create_from_image(image)
		frame.region = Rect2(image.get_used_rect())
		frames.append(frame)
	factor = 124.0 / frames[0].get_height()

func update(robot: TextureRect, elapsed: float, enabled: bool) -> void:
	var t := fposmod(elapsed, 9.0) if enabled else 0.0
	var frame := 0
	var lift := 0.0
	if t >= 2.0 and t < 2.25:
		frame = 1
	elif t >= 2.25 and t < 3.65:
		frame = 1 + int((t-2.25)/0.175)%2
	elif t >= 3.65 and t < 3.95:
		frame = 4
	elif t >= 5.4 and t < 5.65:
		frame = 5
	elif t >= 5.65 and t < 6.25:
		frame = 6
		lift = sin((t-5.65)/0.6*PI)*18.0
	elif t >= 6.25 and t < 6.5:
		frame = 7
	robot.texture = frames[frame]
	robot.size = frames[frame].get_size()*factor
	robot.position = Vector2(48-robot.size.x/2,128-robot.size.y-lift)
	robot.pivot_offset = Vector2(robot.size.x/2,robot.size.y)
	robot.rotation = sin(t*1.7)*0.008 if frame == 0 and enabled else 0.0
