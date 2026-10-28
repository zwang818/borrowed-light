@tool
extends Node2D
const WEB = preload("res://scenes/levels/abdomen/breakable_web.gd")
const SPIDER = preload("res://scenes/levels/abdomen/fleeing_spider.gd")
const CATALOG = preload("res://scenes/levels/abdomen/abdomen_web_catalog.gd")
var webs: Array[Node2D] = []
var _floor_polygons: Array[PackedVector2Array] = []
var _solid_polygons: Array[PackedVector2Array] = []

func _ready() -> void:
	var map := get_parent()
	if map.has_node("Floors"):
		for floor_node in map.get_node("Floors").get_children():
			_floor_polygons.append(floor_node.global_transform * _rectangle(floor_node.size))
	if map.has_node("Walls"):
		for wall in map.get_node("Walls").get_children():
			if wall is Polygon2D:
				_solid_polygons.append(wall.global_transform * wall.polygon)
			else:
				_solid_polygons.append(wall.global_transform * _rectangle(wall.size))
	for child in get_node("Decor").get_children():
		if child.get_script() == WEB:
			child.environment = self
			webs.append(child)
	var background := Node2D.new()
	background.name = "BackgroundWebs"
	background.z_index = -19
	add_child(background)
	for row in range(8):
		for column in range(6):
			for index in range(CATALOG.CAVITY_REGIONS.size()):
				var region: Rect2 = CATALOG.CAVITY_REGIONS[index]
				var web := Area2D.new()
				web.set_script(WEB)
				web.name = "PipeWeb_%d_%d_%d" % [column, row, index]
				web.background_region = region
				web.draw_size = region.size / 1254.0 * 640.0
				web.position = Vector2(-1152 + column * 640, -1024 + row * 640) + region.get_center() / 1254.0 * 640.0
				web.environment = self
				background.add_child(web)
				webs.append(web)
				if not Engine.is_editor_hint():
					_clip_hidden_hit_shapes(web)

func _rectangle(size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])

func _clip_hidden_hit_shapes(web: Area2D) -> void:
	var pieces: Array[PackedVector2Array] = [web.global_transform * web.hit_polygon()]
	# A background target hidden under a walkable floor or a wall must not block shots.
	for cover in _floor_polygons + _solid_polygons:
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			next.append_array(Geometry2D.clip_polygons(piece, cover))
		pieces = next
		if pieces.is_empty():
			break
	for child in web.get_children():
		child.free()
	for piece in pieces:
		# clip_polygons can return clockwise holes. Triangulate outer pieces only;
		# our small patches never surround a complete room or wall.
		if Geometry2D.is_polygon_clockwise(piece):
			continue
		var shape := CollisionPolygon2D.new()
		shape.polygon = web.global_transform.affine_inverse() * piece
		web.add_child(shape)
	if web.get_child_count() == 0:
		web.collision_layer = 0

func _free_floor(point: Vector2) -> bool:
	var on_floor := false
	for polygon in _floor_polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			on_floor = true
			break
	if not on_floor:
		return false
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func spawn_spider(web: Area2D) -> void:
	var start := web.global_position
	var background: bool = web.background_region.has_area()
	if not background:
		var found := false
		for radius in [12.0, 24.0, 36.0, 52.0, 72.0]:
			for i in range(16):
				var candidate: Vector2 = web.global_position + Vector2.from_angle(float(i) * TAU / 16.0) * radius
				if _free_floor(candidate):
					start = candidate
					found = true
					break
			if found:
				break
		if not found:
			return
	var best := Vector2.RIGHT
	var best_score := -INF
	var player := get_tree().current_scene.find_child("Player", true, false) if get_tree().current_scene != null else null
	for i in range(16):
		var direction := Vector2.from_angle(float(i) * TAU / 16.0)
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start, start + direction * 140.0, 1))
		var distance := 140.0 if hit.is_empty() or background else start.distance_to(hit.position)
		var score := distance
		if is_instance_valid(player):
			score += direction.dot((start - player.global_position).normalized()) * 35.0
		if score > best_score:
			best_score = score
			best = direction
	var spider := CharacterBody2D.new()
	spider.set_script(SPIDER)
	spider.background = background
	spider.direction = best
	spider.drop_offset = web.global_position - start + Vector2(0, -8)
	spider.z_index = -18 if background else 5
	add_child(spider)
	spider.global_position = start

func reset_breakable_webs() -> void:
	for spider in get_tree().get_nodes_in_group("ambient_spiders"):
		if is_ancestor_of(spider):
			spider.queue_free()
	for web in webs:
		web.reset_web()
