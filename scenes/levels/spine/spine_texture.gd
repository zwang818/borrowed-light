extends RefCounted
## Fits existing environment atlas parts to the same art-pixel scale as the shell.
const PIXELS = preload("res://scenes/levels/abdomen/abdomen_art_scale.gd")

static func part(parent: Node2D, atlas: Texture2D, source: Rect2, target: Rect2, tint := Color.WHITE) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.region_rect = source
	sprite.position = target.position
	sprite.scale = target.size / source.size
	sprite.self_modulate = tint
	sprite.material = PIXELS.surface_material(1.0 / sprite.scale.x, 1.0 / sprite.scale.y)
	parent.add_child(sprite)
	return sprite
