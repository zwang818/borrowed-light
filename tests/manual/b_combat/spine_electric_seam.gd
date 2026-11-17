extends "res://scenes/levels/spine/spine_fixture.gd"
## B-only faster arc cycle and damage; original arc appearance retained.
const PERIOD := 2.0
const WARNING_END := 1.55
var player: CharacterBody2D
var room: Node2D
var previous := Vector2.ZERO

func _ready() -> void:
	kind = "seam"
	arc_preview = false
	super._ready()
	set_process(false)
	previous = player.global_position

func reset_cycle() -> void:
	seconds = 0.0
	previous = player.global_position
	queue_redraw()

func active() -> bool:
	return fmod(seconds,PERIOD) >= WARNING_END

func _physics_process(delta: float) -> void:
	seconds = fmod(seconds+delta,PERIOD)
	last_frame = int(seconds*14)
	var current := player.global_position
	if active() and not player.is_dead and player.controls_enabled:
		# Arc occupies the central strip; expand by the existing 10px foot radius.
		var box := Rect2(Vector2(span.x/2-18,13),Vector2(36,span.y-26)).grow(10)
		var a := to_local(previous)
		var b := to_local(current)
		var touches := box.has_point(b)
		if current.distance_to(previous)<64 and not touches:
			var corners := [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
			for i in range(4):
				if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null: touches = true
		if touches: player.apply_damage(1)
	previous = current
	queue_redraw()

func _draw() -> void:
	if not room.art_enabled:
		super._draw()
	if active():
		# Same single arc, jitter, colors and widths as A's original seam fixture.
		var sparks := PackedVector2Array([Vector2(span.x / 2, 13)])
		for y in range(25, int(span.y) - 13, 13):
			var jitter := float(posmod(y * 17 + last_frame * 13, 29) - 14)
			sparks.append(Vector2(span.x / 2 + jitter, y))
		sparks.append(Vector2(span.x / 2, span.y - 13))
		draw_polyline(sparks, Color(0.32, 0.66, 1.0, 0.30), 6)
		draw_polyline(sparks, Color("c8ecff"), 2)
