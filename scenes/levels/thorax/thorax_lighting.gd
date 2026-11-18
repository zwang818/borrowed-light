extends Node2D
## The map owns local lighting only. A caller supplies its player's interaction position.
signal switch_pulled(switch_id: String)

const REACH := 96.0
const DARK_AMBIENT := Color("626c82")
const HONEY := Color("ffc36b")

@onready var _markers: Node2D = $"../Markers"
@onready var _beacon_material: ShaderMaterial = $"../Art/CoreBeacon".material
@onready var _reflection_material: ShaderMaterial = $"../Art/CoreReflection".material
@onready var _ambient: CanvasModulate = $Ambient

var _inspection := false
var _core_spill: PointLight2D
var _light_clock := 0.0
var _switches: Array[Marker2D] = []
var _lights: Dictionary[String, PointLight2D] = {}
var _fixtures: Dictionary[String, Polygon2D] = {}
var _handles: Dictionary[String, Line2D] = {}
var _active: Dictionary[String, bool] = {}

func _ready() -> void:
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	falloff.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.52), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.gradient = falloff
	var spill_texture: GradientTexture2D = texture.duplicate()
	spill_texture.height = 512
	_core_spill = PointLight2D.new()
	_core_spill.name = "CoreSpill"
	_core_spill.position = _markers.get_node("CoreBeacon").position
	_core_spill.offset = Vector2(0, 148)
	_core_spill.texture = spill_texture
	_core_spill.texture_scale = 1.5
	_core_spill.color = Color(1.0, 0.69, 0.36)
	_core_spill.shadow_enabled = true
	_core_spill.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	add_child(_core_spill)
	var luminous := CanvasItemMaterial.new()
	luminous.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for marker in _markers.get_children():
		match marker.get_meta("role", ""):
			"zone_light":
				var lamp := PointLight2D.new()
				lamp.name = marker.name
				lamp.position = marker.position
				lamp.texture = texture
				lamp.texture_scale = 2.35
				lamp.color = Color(1.0, 0.70, 0.33)
				lamp.energy = 2.6
				lamp.shadow_enabled = true
				lamp.shadow_filter = Light2D.SHADOW_FILTER_PCF5
				lamp.enabled = false
				add_child(lamp)
				_lights[marker.object_id] = lamp
				var fixture := Polygon2D.new()
				fixture.position = marker.position + marker.get_meta("fixture_offset", Vector2.ZERO)
				fixture.polygon = PackedVector2Array([Vector2(-7, -3), Vector2(7, -3), Vector2(7, 3), Vector2(-7, 3)])
				fixture.color = HONEY.lightened(0.35)
				fixture.z_index = 5
				fixture.material = luminous
				add_child(fixture)
				_fixtures[marker.object_id] = fixture
			"light_switch":
				_switches.append(marker)
				var housing := Polygon2D.new()
				housing.position = marker.position
				housing.polygon = PackedVector2Array([Vector2(-13, -9), Vector2(13, -9), Vector2(17, -3), Vector2(17, 9), Vector2(-17, 9), Vector2(-17, -3)])
				housing.color = Color("303c55")
				add_child(housing)
				var inset := Line2D.new()
				inset.position = marker.position
				inset.width = 2.0
				inset.points = PackedVector2Array([Vector2(-12, 4), Vector2(-12, -5), Vector2(12, -5), Vector2(12, 4)])
				inset.default_color = Color("92a3bb")
				add_child(inset)
				var handle := Line2D.new()
				handle.position = marker.position
				handle.width = 4.0
				handle.points = PackedVector2Array([Vector2(-5, 1), Vector2(5, 1)])
				handle.default_color = Color("7a8dab")
				add_child(handle)
				_handles[marker.object_id] = handle
	_refresh()
	_update_core_glow()

func _process(delta: float) -> void:
	_light_clock += delta
	_update_core_glow()

func _update_core_glow() -> void:
	# Uneven dips, with a steady minimum so the door remains a landmark.
	var dip := pow((sin(_light_clock * 1.65) + 1.0) * 0.5, 10.0)
	var level := 0.97 + 0.055 * sin(_light_clock * 4.4) + 0.032 * sin(_light_clock * 13.7) - 0.125 * dip
	_beacon_material.set_shader_parameter("lamp_level", level)
	_reflection_material.set_shader_parameter("phase", _light_clock)
	_reflection_material.set_shader_parameter("lamp_level", level * (0.64 if _inspection else 1.0))
	_core_spill.energy = level * (0.32 if _inspection else 0.71)

func set_inspection_mode(enabled: bool) -> void:
	_inspection = enabled
	_refresh()

func reset_lighting() -> void:
	_active.clear()
	_light_clock = 0.0
	_refresh()
	_update_core_glow()

func switch_near(world_position: Vector2) -> Marker2D:
	var chosen: Marker2D
	var closest := REACH
	for marker in _switches:
		var distance := world_position.distance_to(marker.global_position)
		if distance <= closest:
			closest = distance
			chosen = marker
	if chosen != null:
		var ray := PhysicsRayQueryParameters2D.create(world_position, chosen.global_position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return null
	return chosen

func pull_switch(world_position: Vector2) -> bool:
	var marker := switch_near(world_position)
	if marker == null or _active.has(marker.object_id):
		return false
	_active[marker.object_id] = true
	_refresh()
	switch_pulled.emit(marker.object_id)
	return true

func is_switch_on(switch_id: String) -> bool:
	return _active.has(switch_id)

func _refresh() -> void:
	var ambient := Color.WHITE if _inspection else DARK_AMBIENT
	_ambient.color = ambient
	_beacon_material.set_shader_parameter("ambient_steel", Vector3(ambient.r, ambient.g, ambient.b))
	for marker in _switches:
		var on := is_switch_on(marker.object_id)
		var lamp: PointLight2D = _lights[marker.linked_ids[0]]
		lamp.enabled = on and not _inspection
		_fixtures[marker.linked_ids[0]].visible = on
		var handle: Line2D = _handles[marker.object_id]
		handle.rotation = 1.05 if on else -0.35
		handle.default_color = HONEY if on else Color("7a8dab")
