extends SceneTree
const SAVE=preload("res://scenes/gameplay/journey_save.gd")
const PATH="/tmp/borrowed-light-spine-save-check.json"
func _initialize(): call_deferred("run")
func run():
	var data={"first_level_cleared":true,"scatter_unlocked":true,"blueprint_known":true,"pulse_learned":true,"workshop_seen":true,"ducts":[],"explored":[]}
	assert(SAVE.write_save(PATH,data)==OK)
	var title=load("res://scenes/main.tscn").instantiate()
	title.game_save_path=PATH
	root.add_child(title)
	current_scene=title
	assert(title.start_button.text=="继续第二关")
	title._continue_journey()
	await scene_changed
	while root.has_node("EntryLoading"): await process_frame
	var room=current_scene
	assert(room.scene_file_path=="res://scenes/gameplay/spine_level.tscn")
	assert(room.art_enabled and not paused)
	var player=room.get_node("SpawnPoints/PlayerSpawn/Player")
	assert(player.scatter_unlocked and player.pulse_gun_equipped)
	assert(room._save_progress())
	assert(SAVE.read_save(PATH).scatter_unlocked)
	SAVE.erase(PATH)
	print("Spine save: cleared title routing, ability reload, checkpoint save: PASS")
	quit()
