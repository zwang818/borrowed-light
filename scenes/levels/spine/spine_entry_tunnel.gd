extends Node2D
## Closed outer shell. Cross sections are projected into 2D with the front face hidden.
const PIXELS = preload("res://scenes/levels/abdomen/abdomen_art_scale.gd")
const ARMOR = preload("res://scenes/levels/spine/spine_entry_tunnel.gdshader")
const SHELL_LENGTH := 1560.0
const BODY_COLOR := Color("a34d42")
const HOOP_COLOR := Color("925045")
const ARC_STEPS := 28

var deck_radius := 0.0

func build(half_deck_width: float) -> void:
	deck_radius = half_deck_width
	var radius := deck_radius * 2.08
	# Stations store distance along the axis, radius, and the apparent curvature of the lip.
	_add_surface(PackedVector3Array([
		Vector3(-SHELL_LENGTH, radius, 90), Vector3(-94, radius, 90),
		Vector3(-65, radius * 0.96, 65), Vector3(-40, radius * 0.78, 36),
		Vector3(-12, deck_radius + 14, 10), Vector3(1, deck_radius, 0),
	]), BODY_COLOR)
	for distance in [-1282.0, -1018.0, -754.0, -490.0, -226.0]:
		_add_hoop(distance, 28.0, radius, 91.0, HOOP_COLOR)
	_add_hoop(-125.0, 44.0, radius, 89.0, Color("a35a4c"))
	_add_hoop(-28.0, 15.0, deck_radius + 25.0, 14.0, Color("79443c"))

func _add_hoop(at: float, width: float, radius: float, bow: float, paint: Color) -> void:
	_add_surface(PackedVector3Array([
		Vector3(at, radius + 4, bow), Vector3(at + 5, radius + 12, bow),
		Vector3(at + width - 5, radius + 12, bow), Vector3(at + width, radius + 3, bow),
	]), paint, true)

func _add_surface(stations: PackedVector3Array, paint: Color, hoop := false) -> void:
	var vertices := PackedVector2Array()
	var texture_coords := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_length := ARC_STEPS + 1
	for row in range(stations.size()):
		var station := stations[row]
		for index in range(row_length):
			var across := float(index) / ARC_STEPS
			var angle := (across - 0.5) * PI
			var side := sin(angle)
			var roll := (1.0 - cos(angle)) * station.z
			vertices.append(Vector2(station.x - roll + side * station.z * 0.12, side * station.y))
			texture_coords.append(Vector2(station.x, across))
			if row == 0 or index == 0:
				continue
			var corner := row * row_length + index
			indices.append_array(PackedInt32Array([
				corner - row_length - 1, corner - row_length, corner,
				corner - row_length - 1, corner, corner - 1,
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = texture_coords
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := MeshInstance2D.new()
	surface.mesh = mesh
	surface.modulate = paint
	var material := ShaderMaterial.new()
	material.shader = ARMOR
	material.set_shader_parameter("pixel_world", PIXELS.ART_PIXEL_WORLD)
	material.set_shader_parameter("hoop", hoop)
	material.set_shader_parameter("start", stations[0].x)
	material.set_shader_parameter("run", stations[-1].x - stations[0].x)
	surface.material = material
	add_child(surface)

func _draw() -> void:
	if deck_radius <= 0:
		return
	# The front trim projects a little over the road. The seam is drawn flush on the deck.
	draw_rect(Rect2(0, -deck_radius, 22, deck_radius * 2), Color(0.16, 0.074, 0.064, 0.6))
	draw_rect(Rect2(2, -deck_radius + 1, 7, deck_radius * 2 - 2), Color("573432"))
	draw_rect(Rect2(9, -deck_radius + 1, 2, deck_radius * 2 - 2), Color("956754"))
	for side: int in [-1, 1]:
		var lamp_y := side * (deck_radius - 14)
		for reach in range(3, 0, -1):
			draw_rect(Rect2(7, lamp_y - 5, 12, 10).grow(reach * 4), Color(1.0, 0.49, 0.18, 0.032))
		draw_rect(Rect2(5, lamp_y - 8, 17, 16), Color("2c1719"))
		draw_rect(Rect2(7, lamp_y - 7, 13, 14), Color("8d512f"))
		draw_rect(Rect2(9, lamp_y - 5, 9, 10), Color("ffad50"))
		draw_rect(Rect2(11, lamp_y - 3, 5, 6), Color("ffdb89"))
