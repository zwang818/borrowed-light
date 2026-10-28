@tool
extends RefCounted
## Single place for the abdomen art-pixel baseline (A-ART-02).
## Surface art uses one art pixel per ART_PIXEL_WORLD world units; devices keep
## their native close-up detail and are not converted yet.
const PIXEL_MATERIAL = preload("res://scenes/levels/abdomen/abdomen_pixel.tres")
const ATLAS_CELL_PX := 313.5
const FLOOR_TILE_WORLD := 64.0
const WALL_STEP_WORLD := Vector2(64.0, 32.0)
## 2026-10-28 用户选定 B 档：相机 zoom 1.5 时 1 美术像素 = 1.5 屏幕像素。
const ART_PIXEL_WORLD := 1.0

static func surface_material(src_px_per_world_x: float, src_px_per_world_y := -1.0) -> ShaderMaterial:
	var py := src_px_per_world_x if src_px_per_world_y < 0.0 else src_px_per_world_y
	var material: ShaderMaterial = PIXEL_MATERIAL.duplicate()
	_set_groups(material, src_px_per_world_x, py)
	return material

## Re-applies the baseline to an existing material, e.g. after a decal is resized.
static func apply_to(node: CanvasItem, src_px_per_world_x: float, src_px_per_world_y := -1.0) -> void:
	if node.material is ShaderMaterial:
		_set_groups(node.material, src_px_per_world_x, src_px_per_world_y if src_px_per_world_y >= 0.0 else src_px_per_world_x)

static func _set_groups(material: ShaderMaterial, src_x: float, src_y: float) -> void:
	# Only write on change: _draw() calls this, and a changed parameter re-dirties the item.
	var gx := maxf(1.0, ART_PIXEL_WORLD * src_x)
	var gy := maxf(1.0, ART_PIXEL_WORLD * src_y)
	var current_x: Variant = material.get_shader_parameter("texel_group_x")
	var current_y: Variant = material.get_shader_parameter("texel_group_y")
	if not (current_x is float) or not is_equal_approx(current_x, gx):
		material.set_shader_parameter("texel_group_x", gx)
	if not (current_y is float) or not is_equal_approx(current_y, gy):
		material.set_shader_parameter("texel_group_y", gy)
