extends SceneTree
const CACHE := preload("res://scenes/gameplay/prepared_sprite_frames.gd")
const CLEANUP := preload("res://tests/manual/b_combat/sprite_frame_cleanup.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	CACHE.loading = true
	for path in ["res://tests/manual/b_combat/art/cleaner/side_animation.png","res://tests/manual/b_combat/art/xiaoyi/xiaoyi_body_rig.png","res://tests/manual/b_combat/art/xiaoyi/xiaoyi_laser_8dir.png"]:
		var texture: Texture2D = load(path)
		var original := texture.get_image()
		var source := CACHE.source_image(texture)
		assert(source.get_data()==original.get_data())
		assert(CACHE.source_image(texture)==source)
		var region := source.get_region(Rect2i(0,0,mini(220,source.get_width()/4),mini(213,source.get_height()/4)))
		var expected := CLEANUP._clean_frame_uncached(region)
		var prepared := CLEANUP.clean_frame(region)
		assert(prepared.get_data()==expected.get_data())
		var cached := CACHE.find(region)
		assert(cached!=null and cached.get_data()==expected.get_data())
		cached.set_pixel(0,0,Color.MAGENTA)
		assert(CACHE.find(region).get_data()==expected.get_data())
	CACHE.release_loading_sources()
	assert(CACHE.pixels.is_empty() and CACHE._source_images.is_empty() and not CACHE.loading)
	print("LOADING RESOURCE CHECK: byte-identical sources, original cleanup, isolated memo results and release: PASS")
	quit(0)
