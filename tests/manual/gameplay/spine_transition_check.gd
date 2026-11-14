extends SceneTree
## Run with a graphical renderer to verify real video completion and loading handoff.
func _initialize(): call_deferred("run")
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var first=load("res://scenes/gameplay/abdomen_level.tscn").instantiate()
	root.add_child(first)
	current_scene=first
	first.journey_save_path=""
	first.player.health=2
	first.is_level_complete=true
	first._show_level_complete()
	await create_timer(2.0).timeout
	assert(paused)
	var transition
	for child in root.get_children():
		if child.get_script()==load("res://scenes/ui/intro_cutscene/level_transition.gd"): transition=child
	assert(transition!=null and transition.video.is_playing())
	await capture("/tmp/spine-transition-video.png")
	await transition.video.finished
	await process_frame
	assert(root.has_node("EntryLoading"))
	await capture("/tmp/spine-transition-loading.png")
	await scene_changed
	await create_timer(1.0).timeout
	var level=current_scene
	assert(level.scene_file_path=="res://scenes/gameplay/spine_level.tscn")
	assert(level.art_enabled and not paused)
	assert(not level.get_node("TestOverlay").visible)
	var player=level.get_node("SpawnPoints/PlayerSpawn/Player")
	assert(player.health==2 and player.pulse_gun_equipped and not player.scatter_unlocked)
	assert(player.get_node("Facing/XiaoyiCombatVisual").relaxed_walk_arms)
	assert(level.enemies.size()==12)
	for enemy in level.enemies: assert(enemy.persistent_projectiles)
	await capture("/tmp/spine-transition-map.png")
	player.global_position=level.map.get_node("Markers/ScatterEvolution").global_position+Vector2(0,40)
	await physics_frame
	assert(level.try_unlock_scatter())
	player.apply_damage(99)
	assert(level.menus.page==level.menus.Page.DEATH)
	level._retry()
	assert(not paused and not player.is_dead and player.scatter_unlocked)
	print("Production spine: real video -> loading -> art map, carried health/laser, enemies, scatter and death retry: PASS")
	quit()
