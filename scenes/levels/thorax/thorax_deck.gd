@tool
extends Polygon2D
## The editable top face also supplies the perimeter collision and shadow.
var _last_outline := PackedVector2Array()

func _ready() -> void:
	_sync_outline()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if polygon != _last_outline:
		_sync_outline()

func _sync_outline() -> void:
	_last_outline = polygon.duplicate()
	$Perimeter/Collision.polygon = polygon
	var shadow := OccluderPolygon2D.new()
	shadow.polygon = polygon
	$Occluder.occluder = shadow
