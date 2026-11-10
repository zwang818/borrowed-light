extends "res://scenes/ui/title_screen/xiaoyi_title_animation.gd"
## Loading-only choreography, reusing the original eight greeting poses.
func update(robot: TextureRect, elapsed: float, enabled: bool) -> void:
	robot.scale = Vector2.ONE
	if not enabled:
		super.update(robot, 0, false)
		return
	var t := fposmod(elapsed, 7.0)
	var source_time := 0.0
	var offset := Vector2.ZERO
	var tilt := 0.0
	var stretch := Vector2.ONE
	if t < 1.0:
		source_time = 2.25 + t
	elif t < 2.0:
		var sway := sin((t - 1.0) * TAU)
		offset.x = sway * 5
		tilt = sway * 0.07
	elif t < 3.1:
		var jump := (t - 2.0) / 1.1
		if jump < 0.18:
			source_time = 5.4 + jump / 0.18 * 0.24
		elif jump < 0.82:
			var air := (jump - 0.18) / 0.64
			source_time = 5.65 + air * 0.599
			offset.y = -sin(air * PI) * 8
		else:
			source_time = 6.25 + (jump - 0.82) / 0.18 * 0.249
			var settle := sin((jump - 0.82) / 0.18 * PI)
			stretch = Vector2(1 + 0.06 * settle, 1 - 0.06 * settle)
	elif t < 4.5:
		var step := (t - 3.1) / 1.4
		offset = Vector2(sin(step * TAU) * 9, -absf(sin(step * TAU * 2)) * 3)
		tilt = sin(step * TAU) * 0.04
	elif t < 5.6:
		var bow := sin((t - 4.5) / 1.1 * PI)
		stretch = Vector2(1 + 0.04 * bow, 1 - 0.10 * bow)
		tilt = bow * 0.05
	else:
		source_time = 2.25 + (t - 5.6)
	super.update(robot, source_time, true)
	robot.position += offset
	robot.rotation += tilt
	robot.scale = stretch
