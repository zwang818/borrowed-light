extends RefCounted
## Authored 8 x 96px frames retain their common canvas and natural airborne poses.
const SHEET := preload("res://assets/loading/xiaoyi_run.png")
const FRAME_SIZE := 96
const FPS := 14.0
var frames: Array[AtlasTexture] = []

func _init() -> void:
	assert(SHEET.get_size() == Vector2(768,96),"Loading run atlas must be 8 horizontal 96 x 96 frames")
	for index in range(8):
		var frame := AtlasTexture.new()
		frame.atlas = SHEET
		frame.region = Rect2(index*FRAME_SIZE,0,FRAME_SIZE,FRAME_SIZE)
		frame.filter_clip = true
		frames.append(frame)

func update(robot: TextureRect, elapsed: float, enabled: bool) -> void:
	var index := int(elapsed*FPS)%frames.size() if enabled else 0
	robot.texture = frames[index]
	robot.size = Vector2(64,64)
	robot.position = Vector2(28,0)
	robot.pivot_offset = Vector2(32,92.0/96.0*64.0)
