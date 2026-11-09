extends "res://tests/manual/b_combat/cleaner_visual.gd"
func eye_world_position() -> Vector2:
	var pose := sprite_pose()
	var eye: Vector2 = pose.origin+eye_anchors[pose.index]*frame_scale
	if face_left:
		eye.x *= -1.0
	return to_global(eye)
func _draw() -> void:
	super._draw()
	if enemy.state == enemy.State.DEAD or enemy.web_phase == 0:
		return
	var eye := to_local(eye_world_position())
	var charge := clampf(1.0-enemy.web_remaining/enemy.WEB_WARNING,0.0,1.0)
	if enemy.web_phase == 1:
		draw_arc(eye,3.0+charge*4.0,0,TAU,16,Color(1,0.6,0.5,0.8),1.2,true)
		draw_line(eye,eye+enemy.web_direction*25.0,Color(0.85,1,0.92,0.3+charge*0.4),1.0,true)
	else:
		draw_circle(eye,4.0,Color(0.85,1,0.92,0.65))
