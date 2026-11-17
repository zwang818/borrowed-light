extends RefCounted
## In-memory source/cleanup reuse during loading; no baked or generated assets.
static var loading := false
static var pixels: Dictionary = {}
static var _source_images: Dictionary = {}
const LOADING_SHEETS := [
	"res://tests/manual/b_combat/art/cleaner/side_animation.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_body_rig.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_arm_rig.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_laser_8dir.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_unarmed_8dir.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_scatter_8dir.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_laser_handedness.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_scatter_handedness.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_diagonal_walk_v2.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_side_walk_v1.png",
	"res://tests/manual/b_combat/art/xiaoyi/xiaoyi_vertical_walk_v1.png",
]

static func source_image(texture: Texture2D) -> Image:
	var key := texture.resource_path
	if key.is_empty():
		key = str(texture.get_instance_id())
	if _source_images.has(key) and _source_images[key].texture == texture:
		return _source_images[key].image
	var result := texture.get_image()
	_source_images[key] = {"texture": texture, "image": result}
	return result

static func warm_loading_sources(node: Node, progress: Callable = Callable()) -> void:
	loading = true
	# Read back each original sheet before the world queues its first large draw.
	# Scene nodes and textures remain on the main thread; I/O uses ResourceLoader.
	for path in LOADING_SHEETS:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path, "Texture2D")
	var completed := 0
	for path in LOADING_SHEETS:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): return
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await node.get_tree().process_frame
			if not is_instance_valid(node) or node.is_queued_for_deletion(): return
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			var texture := ResourceLoader.load_threaded_get(path) as Texture2D
			if texture != null:
				source_image(texture)
		completed += 1
		if progress.is_valid(): progress.call(completed,LOADING_SHEETS.size())
		await node.get_tree().process_frame

static func release_loading_sources() -> void:
	# Actors now own their cropped textures; original CPU sheets can be released.
	_source_images.clear()
	pixels.clear()
	loading = false

static func yield_loading_frame(node: Node) -> void:
	if node.is_inside_tree() and node.get_tree().root.has_node("EntryLoading"):
		await node.get_tree().process_frame

static func key_for(source: Image) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(source.get_data())
	return "%dx%d_%s" % [source.get_width(), source.get_height(), digest.finish().hex_encode()]

static func find(source: Image) -> Image:
	if not loading: return null
	var key := key_for(source)
	return pixels[key].duplicate() if pixels.has(key) else null

static func record(source: Image, result: Image) -> void:
	if loading: pixels[key_for(source)] = result.duplicate()
