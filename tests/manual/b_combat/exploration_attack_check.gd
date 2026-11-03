extends SceneTree

class WebEnvironment extends Node2D:
	var released := 0
	func spawn_spider(_web: Area2D) -> void:
		released += 1

func _initialize() -> void:
	call_deferred("run")

func click(player: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"shoot"
	event.pressed = true
	player._unhandled_input(event)

func run() -> void:
	var room := WebEnvironment.new()
	root.add_child(room)
	var player = load("res://scenes/player/player.tscn").instantiate()
	player.set_script(load("res://scenes/player/xiaoyi_map_player.gd"))
	room.add_child(player)
	player.position = Vector2(300,300)
	player.set_physics_process(false)
	var visual = load("res://tests/manual/b_combat/xiaoyi_aim_visual.gd").new()
	visual.name = "XiaoyiCombatVisual"
	player.get_node("Facing").add_child(visual)
	visual.set_physics_process(false)
	player.pulse_gun.configure_space(Rect2(0,0,800,800),func(_e): return false)
	click(player)
	assert(player.pulse_gun.state == player.pulse_gun.State.IDLE)
	player.learn_pulse()
	player.update_combat_mode()
	visual._show_frame()
	assert(player.inspection_remaining > 0 and player.attack_mode == 2)
	assert(visual.arm_nodes[0].visible)
	assert(visual.arm_nodes[0].get_node("Art").texture == visual.arm_textures[0])
	player.advance_pose_time(1.3)
	player.update_combat_mode()
	visual.update_animation(0.3,Vector2.ZERO,false)
	assert(player.attack_mode == 2 and player.inspection_remaining == 0)
	assert(visual.arm_nodes[0].get_node("Art").texture == visual.arm_textures[0])
	# Fire normally with no enemy present at the existing spider-web target.
	click(player)
	assert(player.attack_mode == 1 and player.pulse_gun.state == player.pulse_gun.State.CHARGING)
	visual.update_animation(0.3,Vector2.ZERO,false)
	var direction: Vector2 = player.mouse_facing
	var start: Vector2 = player.get_shot_origin(1).position
	var web = load("res://scenes/levels/abdomen/breakable_web.gd").new()
	web.environment = room
	web.background_region = Rect2(0,0,10,10)
	room.add_child(web)
	web.position = start+direction*70
	await physics_frame
	await physics_frame
	player.pulse_gun.advance_time(0.8,player.global_position,direction)
	player.pulse_gun.advance_time(0.12,player.global_position,direction)
	assert(web.broken)
	await process_frame
	assert(room.released == 1)
	player.advance_pose_time(0.1)
	player.pulse_gun.cancel()
	player.advance_pose_time(1.9)
	player.update_combat_mode()
	assert(player.attack_mode == 1)
	player.advance_pose_time(0.11)
	player.update_combat_mode()
	assert(player.attack_mode == 2 and player.selected_mode == 1)
	player.scatter_unlocked = true
	assert(player.set_attack_mode(3))
	assert(player.attack_mode == 2 and player.selected_mode == 3)
	click(player)
	assert(player.attack_mode == 3 and get_nodes_in_group("b_scatter_pellets").size() == 3)
	player.restore_player(player.position,3,["pulse_gun"])
	assert(player.inspection_remaining == 0 and player.attack_mode == 2)
	room.queue_free()
	await process_frame
	print("Exploration attacks: module appearance, inspection, web reaction, 2s holster and remembered scatter: PASS")
	quit()
