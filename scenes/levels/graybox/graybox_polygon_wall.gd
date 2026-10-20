@tool
extends Polygon2D
## Edit the Polygon2D vertices. Collision and occlusion share the same polygon.
var _last_polygon := PackedVector2Array()

func _ready() -> void:
	_sync_geometry()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if polygon != _last_polygon:
		_sync_geometry()

func _sync_geometry() -> void:
	_last_polygon = polygon.duplicate()
	$Body/Collision.polygon = polygon
	var shadow := OccluderPolygon2D.new()
	shadow.polygon = polygon
	$Occluder.occluder = shadow
