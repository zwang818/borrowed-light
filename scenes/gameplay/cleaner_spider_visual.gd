extends Sprite2D
## Reference spider skin. Original cleaner silhouette was approximately 34 px wide.
const MODEL_WIDTH := 34.0 * 1.5

func _ready() -> void:
	texture = preload("res://assets/sprites/enemies/cleaner_spider.png")
	var bounds := texture.get_image().get_used_rect()
	region_enabled = true
	region_rect = Rect2(bounds)
	scale = Vector2.ONE * MODEL_WIDTH / float(bounds.size.x)
	# Source faces down; combat Facing points along +X.
	rotation = -PI / 2.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
