extends StaticBody2D
## Damage-only body: shared ray projectiles already query bodies on layer 2.
## Foot collision stays on the CharacterBody, which still moves against layer 1.
var player: CharacterBody2D
var visual: Node2D
var outlines: Dictionary = {}
var shapes: Array[CollisionPolygon2D] = []

func _ready() -> void:
	player = get_parent()
	visual = player.get_node("Facing/XiaoyiCombatVisual")
	collision_layer = 2
	collision_mask = 0
	process_physics_priority = 20
	player.collision_layer = 0
	player.health_changed.connect(_health_changed)
	sync_pose()

func get_damage_receiver() -> Node:
	return player

func apply_damage(amount: int) -> void:
	player.apply_damage(amount)

func apply_web_slow(duration: float, factor: float) -> void:
	if player.has_method("apply_web_slow"):
		player.apply_web_slow(duration,factor)

func _health_changed(health: int, _maximum: int) -> void:
	set_deferred("collision_layer",2 if health > 0 else 0)

func _physics_process(_delta: float) -> void:
	sync_pose()

func sync_pose() -> void:
	var parts: Array[Sprite2D] = [visual.sprite]
	if visual.leg_sprite != null:
		parts.append(visual.leg_sprite)
	for arm in visual.arm_nodes:
		parts.append(arm.get_node("Art"))
	var used := 0
	for part in parts:
		if not part.is_visible_in_tree() or part.texture == null:
			continue
		var key := part.texture.get_instance_id()
		if not outlines.has(key):
			var pixels: Image
			if part.texture is AtlasTexture:
				pixels = part.texture.atlas.get_image().get_region(Rect2i(part.texture.region))
			else:
				pixels = part.texture.get_image()
			var mask := BitMap.new()
			mask.create_from_image_alpha(pixels,0.5)
			var contours: Array[PackedVector2Array] = []
			for contour in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,pixels.get_size()),1.0):
				if contour.size() >= 3:
					contours.append(contour)
			outlines[key] = contours
		var offset := part.get_rect().position
		var transform_to_body := global_transform.affine_inverse()*part.global_transform
		for contour_index in range(outlines[key].size()):
			var contour: PackedVector2Array = outlines[key][contour_index]
			if used == shapes.size():
				var shape := CollisionPolygon2D.new()
				add_child(shape)
				shapes.append(shape)
			# Decompose only on a pose change; movement/aim/bob update transforms.
			# Rebuilding world-space polygons every tick caused needless CPU work.
			if shapes[used].get_meta("texture_id",0) != key or shapes[used].get_meta("contour_index",-1) != contour_index:
				shapes[used].polygon = contour
				shapes[used].set_meta("texture_id",key)
				shapes[used].set_meta("contour_index",contour_index)
			shapes[used].transform = transform_to_body*Transform2D(0,offset)
			if shapes[used].disabled:
				shapes[used].disabled = false
			used += 1
	for i in range(used,shapes.size()):
		shapes[i].disabled = true
