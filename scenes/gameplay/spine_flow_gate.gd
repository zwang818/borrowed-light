extends "res://tests/manual/a_map/preview_door.gd"
## Lock withdrawal and collision change share the same animated aperture.
signal opened
var aperture := 0.0
var opening := false

func set_open(value: bool) -> void:
	aperture = 1.0 if value else 0.0
	opening = false
	super.set_open(value)

func unlock() -> void:
	if is_open or opening: return
	opening = true

func _process(delta: float) -> void:
	if not opening: return
	aperture = minf(1, aperture + delta / 0.8)
	queue_redraw()
	if aperture >= 1:
		opening = false
		super.set_open(true)
		opened.emit()

func _draw() -> void:
	var half := size * 0.5
	var color := Color("b59a69")
	for side in [-1,1]:
		var panel := Rect2(Vector2(-half.x, -half.y if side < 0 else aperture*half.y), Vector2(size.x, half.y*(1-aperture)))
		if panel.size.y > 0:
			draw_rect(panel, Color("344042"))
			draw_rect(panel, color, false, 2)
		draw_line(Vector2(-half.x,side*half.y),Vector2(half.x,side*half.y),color,4)
	if aperture < 0.3:
		draw_line(Vector2(-7,0),Vector2(7,0),Color("dfb35c"),3)
