@tool
extends Node2D
## Pure 2D diagonal blockout. Top polygons are terrain; machinery remains background.
enum ServicePassage { CONCEALED, REVEALED, OPEN }
const SERVICE_OPEN_TIME := 3.0

var depth_enabled := true
var service_passage_state := ServicePassage.CONCEALED
var service_opening: Tween
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
func set_service_passage_state(value: ServicePassage, animate := false) -> void:
	if animate and value == service_passage_state:
		return
	var opening := animate and value == ServicePassage.OPEN
	if service_opening != null:
		service_opening.kill()
		service_opening = null
	service_passage_state = value
	var opened := value == ServicePassage.OPEN
	$Floors/ServiceCatwalk.visible = opened
	$EntranceDefense/ServiceWalls.visible = opened
	_set_service_seals_open(opened and not opening)
	$SpineArt.update_service_passage(opening)
	if opening:
		service_opening = create_tween().set_parallel(true)
		$SpineArt.animate_service_passage(service_opening)
		service_opening.tween_interval(SERVICE_OPEN_TIME)
		service_opening.chain().tween_callback(_finish_service_opening)

func service_camera_weight() -> float:
	if service_opening == null:
		return 0.0
	var elapsed := service_opening.get_total_elapsed_time()
	return smoothstep(0.0, 0.58, elapsed) * (1.0 - smoothstep(2.40, SERVICE_OPEN_TIME, elapsed))

func _finish_service_opening() -> void:
	service_opening = null
	_set_service_seals_open(true)
	$SpineArt.update_service_passage()

func _set_service_seals_open(opened: bool) -> void:
	for seal in $EntranceDefense/ServiceSeals.get_children():
		seal.get_node("Collision").set_deferred("disabled", opened)
		seal.get_node("Occluder").visible = not opened
