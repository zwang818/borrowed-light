extends SceneTree
## Authoring command: rebake saved floor boundaries after editing Top polygons.
## Writes only spine_graybox.tscn. Never called by gameplay or the preview.
## Keep map/data-container transforms at identity.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var map = load("res://scenes/levels/spine/spine_graybox.tscn").instantiate()
	root.add_child(map)
	for old_name in ["Boundaries", "BoundaryDebug"]:
		var old: Node = map.get_node_or_null(old_name)
		if old:
			map.remove_child(old)
			old.free()
	var merged: Array[PackedVector2Array] = []
	var surfaces: Array = map.get_walk_surfaces()
	for surface in surfaces:
		var candidate := PackedVector2Array()
		for point in surface.polygon:
			candidate.append(map.to_local(surface.to_global(point)))
		var i := merged.size() - 1
		while i >= 0:
			var result := Geometry2D.merge_polygons(merged[i], candidate)
			if result.size() == 1:
				candidate = result[0]
				merged.remove_at(i)
				i = merged.size() - 1
			elif result.size() == 2 and (Geometry2D.is_polygon_clockwise(result[0]) != Geometry2D.is_polygon_clockwise(result[1])):
				# The optional bypass closes a hole. Keep both oriented contours.
				merged.remove_at(i)
				merged.append(result[0])
				merged.append(result[1])
				candidate = PackedVector2Array()
				break
			else:
				i -= 1
		if not candidate.is_empty():
			merged.append(candidate)
	var boundaries := Node2D.new()
	boundaries.name = "Boundaries"
	map.add_child(boundaries)
	boundaries.owner = map
	var debug := Node2D.new()
	debug.name = "BoundaryDebug"
	debug.z_index = 25
	debug.visible = false
	map.add_child(debug)
	debug.owner = map
	for i in range(merged.size()):
		var body := StaticBody2D.new()
		body.name = "Perimeter%02d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		boundaries.add_child(body)
		body.owner = map
		var edge := CollisionPolygon2D.new()
		edge.name = "Collision"
		edge.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		edge.polygon = merged[i]
		body.add_child(edge)
		edge.owner = map
		var wire := Line2D.new()
		wire.name = "Perimeter%02d" % i
		wire.points = merged[i]
		wire.add_point(merged[i][0])
		wire.width = 3
		wire.default_color = Color("75e2c5")
		debug.add_child(wire)
		wire.owner = map
	for cover in map.get_node("Covers").get_children():
		var previous: Node = cover.get_node_or_null("Occluder")
		if previous:
			cover.remove_child(previous)
			previous.free()
		var shadow := LightOccluder2D.new()
		shadow.name = "Occluder"
		shadow.occluder = OccluderPolygon2D.new()
		shadow.occluder.polygon = cover.get_node("Body/Collision").polygon
		cover.add_child(shadow)
		shadow.owner = map
		var wire := Line2D.new()
		wire.name = cover.name
		wire.points = shadow.occluder.polygon
		wire.add_point(wire.points[0])
		wire.width = 3
		wire.default_color = Color("e2b775")
		debug.add_child(wire)
		wire.owner = map
	var scene := PackedScene.new()
	assert(scene.pack(map) == OK)
	assert(ResourceSaver.save(scene, "res://scenes/levels/spine/spine_graybox.tscn") == OK)
	print("BAKED_STATIC_BOUNDARIES contours=", merged.size())
	map.queue_free()
	quit()
