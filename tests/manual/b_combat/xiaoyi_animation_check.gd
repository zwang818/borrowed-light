extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var room = load("res://tests/manual/b_combat/combat_test.tscn").instantiate()
	root.add_child(room)
	var player = room.get_node("SpawnPoints/PlayerSpawn/Player")
	var visual = player.get_node("Facing/XiaoyiCombatVisual")
	player.set_physics_process(false)
	player.set_attack_mode(2)
	visual.set_process(false)
	visual.set_physics_process(false)
	check(visual.frames.size() == 32, "All 32 animation frames must be available.")
	for atlas in visual.frames:
		check(atlas.get_width() > 0 and atlas.get_height() > 0, "No empty animation cells.")
	var directions := [Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1)]
	for row in range(8):
		visual.update_animation(0.2, directions[row].normalized() * 4.0, false)
		check(visual.facing_row == row, "Movement direction must select row %d." % row)
		check(not visual.sprite.flip_h, "Never mirror the anatomical laser arm.")
	player.aim_at(player.global_position + Vector2.LEFT * 100)
	visual.update_animation(0.2, Vector2.RIGHT * 16, false)
	check(visual.facing_row == 6 and player.aim_direction == Vector2.LEFT, "Move right while aiming left independently.")
	var first_frame: int = visual.current_column
	var stride_before: float = visual.walk_distance
	for render_tick in range(4):
		visual._process(1.0 / 240.0)
	check(visual.current_column == first_frame and visual.walk_distance == stride_before, "240 Hz render ticks must not reset the 60 Hz walk stride.")
	var sample := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	sample.fill(Color.TRANSPARENT)
	sample.fill_rect(Rect2i(2, 2, 5, 7), Color.WHITE)
	sample.set_pixel(10, 10, Color.WHITE)
	sample.set_pixel(1, 1, Color(1, 0, 0, 0.2))
	var cleaned: Image = visual.FRAME_CLEANUP.clean_frame(sample)
	check(cleaned.get_pixel(10, 10).a == 0.0 and cleaned.get_pixel(1, 1).a == 0.0, "Neighbour fragments and translucent fringe must be removed.")
	check(cleaned.get_pixel(4, 5) == Color.WHITE, "Robot body pixels must survive cleanup.")
	visual.update_animation(0.1, Vector2.RIGHT * 16, false)
	check(visual.current_column != first_frame, "Walk stride must advance actual limb frames.")
	visual.update_animation(0.2, Vector2.ZERO, false)
	check(visual.current_column == 0 and visual.facing_row == 6, "Idle keeps last facing and stops stepping.")
	visual.update_animation(0.035, Vector2.LEFT, false)
	check(visual.facing_row != 2 and visual.facing_row != 6, "Reverse turn passes through intermediate directions.")
	visual.update_animation(0.2, Vector2.LEFT, false)
	check(visual.facing_row == 2, "Reverse turn finishes facing movement.")
	visual.update_animation(0.2, Vector2.DOWN, true)
	check(visual.facing_row == 2 and visual.current_column == 0, "Death/disabled input freezes locomotion.")
	room.queue_free()
	await process_frame
	print("Xiaoyi animation checks: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
