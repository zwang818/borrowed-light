extends SceneTree
const LOADER := preload("res://scenes/ui/intro_cutscene/entry_loading.gd")
const SAVE := preload("res://scenes/gameplay/journey_save.gd")
const SPINE_SCENE := "res://scenes/gameplay/spine_level.tscn"
const WORKSHOP_SCENE := "res://scenes/gameplay/spine_workshop_visit.tscn"
const ABDOMEN_IMAGE := "res://assets/loading/abdomen_workshop.png"
const SPINE_IMAGE := "res://assets/loading/energy_spine.png"
const SAVE_PATH := "user://test_loading_cards_journey.json"
class InputProbe extends Node:
	var events := 0
	func _unhandled_input(_event: InputEvent) -> void: events += 1

var failures: Array[String] = []
var cards: Array[String] = []
var tracks: Dictionary = {}
var watching := false
var largest_frame_ms := 0.0
func _process(delta: float) -> bool:
	if watching and root.has_node("EntryLoading"): largest_frame_ms = maxf(largest_frame_ms,delta*1000.0)
	return false
func _initialize() -> void:
	root.size = Vector2i(1152,648)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
		printerr("FAIL: ",message)
func bytes_at(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = down
		root.push_input(event,true)
func accept(action: String) -> void:
	for down in [true,false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		root.push_input(event,true)
func press_return_home(menu: Node) -> void:
	for action in menu._content.find_children("*", "Button", true, false):
		if action.text == "返回首页":
			action.pressed.emit()
			return
	check(false, "The current menu offers Return Home")
func capture(label: String) -> void:
	var folder := OS.get_environment("LOADING_CARDS_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("loading_cards_"+label+".png"))
func watch(node: Node) -> void:
	if not watching or not node is LOADER: return
	var id := node.get_instance_id()
	tracks[id] = {"last":0.0,"full":false,"card":null,"stages":{}}
	node.progress_changed.connect(func(value):
		var track: Dictionary = tracks[id]
		var image_path: String = node.background.texture.resource_path if node.background.texture != null else ""
		if track.card == null:
			track.card = image_path
			cards.append(image_path)
			print("CARD ",node.target_path,": ",image_path)
		check(value>=track.last,"Actual loading progress never moves backward")
		track.last = value
		track.stages[node.progress_target] = true
		check(image_path==track.card,"The destination's loading background stays fixed")
		if value>=1.0:
			track.full = true
			check(node.ready_to_finish and current_scene!=null,"100 percent requires a completed handoff")
			if current_scene != null and current_scene.has_method("is_entry_ready"):
				check(current_scene.is_entry_ready(),"Gameplay is entry-ready before 100 percent")
				var player = current_scene.hero() if current_scene.has_method("hero") else current_scene.player
				check(player.controls_enabled,"Gameplay controller is prepared before 100 percent")
		else:
			check(node.caption.text!="100%","Percentage label cannot round up to 100 early"))
func wait_room(path: String, maximum: float = 100.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(maximum*1000)
	var report_at := Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if Time.get_ticks_msec()>report_at:
			report_at = Time.get_ticks_msec()+5000
			if root.has_node("EntryLoading"):
				var loader = root.get_node("EntryLoading")
				print("WAIT ",path," progress=",loader.display_progress," source=",loader.sources_ready," switching=",loader.switching," scene=",current_scene.scene_file_path if current_scene!=null else "none")
		if current_scene!=null and current_scene.scene_file_path==path and not root.has_node("EntryLoading") and (not current_scene.has_method("is_entry_ready") or current_scene.is_entry_ready()) and not paused:
			return true
	return false
func capture_active(label: String) -> void:
	for i in 4: await process_frame
	if root.has_node("EntryLoading"):
		await capture(label)
func run() -> void:
	var personal := [bytes_at(SAVE.DEFAULT_PATH),bytes_at("user://settings.cfg"),bytes_at("user://achievements.cfg")]
	SAVE.erase(SAVE_PATH)
	# Observe two whole run cycles while paused and with progress intentionally held.
	var probe := InputProbe.new()
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(probe)
	var preview = LOADER.new()
	root.add_child(preview)
	preview.begin(SPINE_SCENE,load(SAVE.SCENE))
	check(preview.background.texture.resource_path == ABDOMEN_IMAGE,"Explicit PackedScene uses its actual destination card")
	preview.switching = true
	preview.progress_target = 0.42
	preview.display_progress = 0.42
	for action in ["interact","pause","shoot","ui_cancel"]: accept(action)
	check(probe.events==0,"Paused loading layer consumes gameplay input")
	var start: float = preview.robot_clock
	var poses := {}
	var position: Vector2 = preview.robot.position
	var deadline := Time.get_ticks_msec()+1400
	while Time.get_ticks_msec()<deadline:
		await process_frame
		poses[preview.robot.texture.region.position.x] = true
		check(preview.robot.position==position and preview.robot.size==Vector2(64,64),"Run uses a fixed canvas and position without frame recentering")
	check(preview.robot_clock-start>16.0/14.0 and poses.size()==8 and is_equal_approx(preview.display_progress,0.42),"Animation completes at least two cycles while progress is frozen and the world paused")
	for dimensions in [Vector2i(1280,720),Vector2i(960,720)]:
		root.size = dimensions
		await create_timer(0.2,true).timeout
		check(preview.background.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Authored Chinese card uses contain rather than crop")
		check(root.get_visible_rect().encloses(preview.status_group.get_global_rect()),"Bottom-right status remains visible at both aspect ratios")
		var scale_factor: float = preview.status_group.scale.x
		var edge: Vector2 = preview.cover.size-preview.status_group.get_global_rect().end
		check(edge.distance_to(Vector2(32,24)*scale_factor)<0.1,"Status margins follow the 1280x720 design reference")
		check(preview.find_children("*","Label",true,false).size()==1,"No duplicate lore labels overlay the precomposed card")
		await capture("layout_%dx%d" % [dimensions.x,dimensions.y])
	preview._cancel()
	probe.queue_free()
	await process_frame
	root.size = Vector2i(1152,648)
	watching = true
	root.child_entered_tree.connect(watch)
	var title = load("res://scenes/main.tscn").instantiate()
	title.game_save_path = SAVE_PATH
	root.add_child(title)
	current_scene = title
	await create_timer(0.3,true).timeout
	click(title.start_button)
	var opening_limit := Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<opening_limit and (current_scene==null or current_scene.scene_file_path!="res://scenes/ui/intro_cutscene/intro_cutscene.tscn"):
		await process_frame
	check(current_scene!=null and current_scene.scene_file_path=="res://scenes/ui/intro_cutscene/intro_cutscene.tscn","Real title click enters the existing opening")
	# Use the opening's real skip input, then retain the normal entry loader.
	accept("ui_cancel")
	await capture_active("entry")
	check(await wait_room(SAVE.SCENE),"Title / opening reaches playable abdomen through the new loader")
	var first = current_scene
	first.blueprint_known = true
	first.pulse_learned = true
	first.player.learn_pulse()
	first.terminal_activated = true
	first.player.global_position = first.final_exit.global_position
	first._on_exit_entered(first.player,first.final_exit.get_meta("exit_id"))
	await process_frame
	var transition: CanvasLayer
	for child in root.get_children():
		if child.get_script()==load("res://scenes/ui/intro_cutscene/level_transition.gd"): transition=child
	check(transition!=null and transition.video.stream.resource_path=="res://assets/video/abdomen_to_spine.ogv","Teammate's production video transition is retained")
	if transition!=null:
		await transition.video.finished
	await capture_active("spine_entry")
	check(await wait_room(SPINE_SCENE),"Normal video ending loads the current production spine scene")
	var spine = current_scene
	check(spine.art_enabled and spine.story_ready,"The current spine scene has its art and story enabled")
	var cached_spine: PackedScene = load(SPINE_SCENE)
	spine.menus.show_death()
	press_return_home(spine.menus)
	await capture_active("title_return")
	check(await wait_room("res://scenes/main.tscn"),"Production spine Return uses the same loading screen")
	check(cards == [ABDOMEN_IMAGE, SPINE_IMAGE, SPINE_IMAGE],"Returning home from the spine death menu shows the spine card")
	title = current_scene
	title.game_save_path = SAVE_PATH
	title._refresh_archive()
	check(ResourceLoader.has_cached(SPINE_SCENE),"Next continuation uses an already cached PackedScene")
	await create_timer(0.3,true).timeout
	click(title.start_button)
	await capture_active("spine_cached")
	check(await wait_room(SPINE_SCENE),"Continue restores production spine with cached scene resources")
	spine = current_scene
	spine._begin_workshop_trip()
	check(await wait_room(WORKSHOP_SCENE),"Workshop transfer loads the real abdomen workshop")
	current_scene.game_menus.toggle_pause()
	press_return_home(current_scene.game_menus)
	check(await wait_room("res://scenes/main.tscn"),"Workshop Return Home also uses the loader")
	title = current_scene
	title.game_save_path = SAVE_PATH
	title._refresh_archive()
	title.start_button.pressed.emit()
	check(await wait_room(WORKSHOP_SCENE),"Continue from the title restores the saved workshop after Return Home")
	current_scene._return_spine()
	check(await wait_room(SPINE_SCENE),"Returning from the workshop loads the real spine")
	var resource_loader = LOADER.new()
	resource_loader.name = "EntryLoading"
	root.add_child(resource_loader)
	resource_loader.begin(SPINE_SCENE,cached_spine)
	await capture_active("packed_cached")
	check(await wait_room(SPINE_SCENE),"Explicitly provided cached PackedScene also follows real readiness and full progress")
	check(cards == [ABDOMEN_IMAGE, SPINE_IMAGE, SPINE_IMAGE, SPINE_IMAGE, ABDOMEN_IMAGE,
		ABDOMEN_IMAGE, ABDOMEN_IMAGE, SPINE_IMAGE, SPINE_IMAGE],
		"Return Home uses the source card and gameplay loads use the destination card")
	for track in tracks.values():
		check(track.full,"Every successful production loading screen reaches 100 percent")
		check(track.stages.size()>=3,"Successful progress reflects completed load stages")
	print("ACTUAL CARD ORDER: ",cards)
	print("SUCCESSFUL LOADS: ",tracks.size())
	print("LARGEST CAPTURE-INCLUSIVE FRAME MS: ",largest_frame_ms)
	watching = false
	# Return UI remains usable without writing to the real journey or force-loading a missing resource.
	var failed = LOADER.new()
	failed.name = "EntryLoading"
	root.add_child(failed)
	failed.previous_pause = paused
	paused = true
	failed._fail()
	accept("pause")
	check(paused and current_scene.menus.page==current_scene.menus.Page.CLOSED,"Pause key cannot bypass a failed loading overlay")
	check(failed.back.visible and failed.caption.text=="LOAD FAILED","Failure hint and Return remain available")
	var fail_clock: float = failed.robot_clock
	await create_timer(0.2,true).timeout
	check(failed.robot_clock>fail_clock,"Failure screen still animates while paused")
	click(failed.back)
	await process_frame
	check(not paused and not is_instance_valid(failed),"Failure Return restores pause and removes only the overlay")
	check(personal==[bytes_at(SAVE.DEFAULT_PATH),bytes_at("user://settings.cfg"),bytes_at("user://achievements.cfg")],"Personal journey, settings and achievements remain byte-for-byte unchanged")
	current_scene.queue_free()
	await create_timer(0.15,true).timeout
	SAVE.erase(SAVE_PATH)
	print("LOADING CARDS CHECK: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
