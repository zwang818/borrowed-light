@tool
extends Node2D
## Pure 2D diagonal blockout. Top polygons are terrain; machinery remains background.
enum ServicePassage { CONCEALED, REVEALED, OPEN }

var depth_enabled := true
var service_passage_state := ServicePassage.CONCEALED
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


## C can reveal the hatch after dialogue and open the passage on interaction.
func set_service_passage_state(value: ServicePassage) -> void:
	service_passage_state = value
	var opened := value == ServicePassage.OPEN
	$Floors/ServiceCatwalk.visible = opened
	$EntranceDefense/ServiceWalls.visible = opened
	for seal in $EntranceDefense/ServiceSeals.get_children():
		seal.get_node("Collision").set_deferred("disabled", opened)
		seal.get_node("Occluder").visible = not opened
	$SpineArt.update_service_passage()
