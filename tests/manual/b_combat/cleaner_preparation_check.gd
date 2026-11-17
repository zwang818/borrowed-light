extends SceneTree
## Exercise the real per-frame loading yield and the shared frame-cache hit.
const VISUAL := preload("res://tests/manual/b_combat/web_cleaner_visual.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	paused = true
	var loading := Node.new()
	loading.name = "EntryLoading"
	root.add_child(loading)
	VISUAL.frame_cache.clear()
	var first: Node2D
	var actors: Array[Node] = []
	for cached in [false,true]:
		var enemy = load("res://scenes/enemies/cleaner/cleaner.tscn").instantiate()
		root.add_child(enemy)
		actors.append(enemy)
		var visual := VISUAL.new()
		visual.match_hurtbox = true
		visual.hide()
		enemy.add_child(visual)
		if not cached:
			assert(not visual.preparation_complete)
			assert(visual.hurt_shape == null)
			assert(VISUAL.frame_cache.is_empty(),"Never publish partially prepared frames")
		for frame in range(120):
			if visual.preparation_complete: break
			await process_frame
		assert(visual.preparation_complete,"Preparation must finish while the world is paused")
		assert(visual.pieces.size() == 16 and visual.hit_polygons.size() == 16 and visual.eye_anchors.size() == 16)
		assert(visual.hurt_shape != null and visual.hurt_shape.polygon.size() >= 3)
		assert(visual.sprite_pose().index == 15)
		if cached:
			assert(visual.pieces[15] == first.pieces[15])
			assert(visual.hit_polygons == first.hit_polygons and visual.eye_anchors == first.eye_anchors)
			assert(is_equal_approx(visual.frame_scale,first.frame_scale))
			assert(visual.hurt_shape != first.hurt_shape,"Collision nodes remain per enemy")
		else:
			first = visual
	for actor in actors: actor.queue_free()
	loading.queue_free()
	await process_frame
	print("Cleaner preparation: async completion, complete cache, identical visuals/hulls and independent collision nodes: PASS")
	quit()
