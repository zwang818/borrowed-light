@tool
extends Node2D
## Pure 2D diagonal blockout. Top polygons are terrain; machinery remains background.
var depth_enabled := true
func get_walk_surfaces() -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for part in $Floors.get_children(): result.append(part.get_node("Top"))
	return result
func is_walkable_point(world_point: Vector2) -> bool:
	for top in get_walk_surfaces():
		if Geometry2D.is_point_in_polygon(top.to_local(world_point), top.polygon): return true
	return false
func surface_at(world_point: Vector2) -> String:
	return "shell" if is_walkable_point(world_point) else "void"
func set_depth_enabled(value: bool) -> void:
	depth_enabled = value
	$CoreBundles.visible = value
	for part in $Floors.get_children(): part.get_node("Volume").visible = value
	$SpineArt.set_depth_enabled(value)
