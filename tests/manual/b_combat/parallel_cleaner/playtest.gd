extends "res://scenes/gameplay/abdomen_boss_level.gd"

const TEST_PULSE := preload("res://tests/manual/b_combat/parallel_cleaner/test_pulse.gd")
const PULSE_SCENE := preload("res://tests/manual/b_combat/muzzle_pulse_gun.tscn")
const PLAYTEST_ENTRY := Vector2(640, 679)
var prototype_ready := false


func _configure_player() -> void:
	var parent: Node = player.pulse_gun.get_parent()
	var prior: Node = player.pulse_gun
	parent.remove_child(prior)
	prior.free()
	var gun := PULSE_SCENE.instantiate()
	gun.set_script(TEST_PULSE)
	gun.name = "PulseGun"
	gun.muzzle_owner = player
	player.pulse_gun = gun
	parent.add_child(gun)
	await super._configure_player()

func _ready() -> void:
	await super._ready()
	game_menus.bind_achievement_journey("parallel_cleaner_playtest")
	notify_bg.offset_top = 15
	notify_bg.offset_bottom = 61
	notify_label.add_theme_font_size_override("font_size", 19)
	blueprint_known = true
	pulse_learned = true
	player.learn_pulse()
	player.global_position = PLAYTEST_ENTRY
	camera.global_position = PLAYTEST_ENTRY
	camera.reset_smoothing()
	current_objective = Objective.KILL_ENEMIES
	for cleaner in enemies:
		if cleaner.is_in_group("cleaners") and not cleaner is EXIT_CLEANER:
			cleaner.apply_damage(cleaner.max_health)
			enemy_baselines[cleaner.entity_id] = cleaner.get_combat_state()
			cleaner.hide()
	prototype_ready = true
	_show_notification("出口战试玩 · 左臂脉冲已装配 · B 合体 · R 重试", 4.6)

func _input(event: InputEvent) -> void:
	if prototype_ready and event is InputEventKey and event.pressed and not event.echo and not get_tree().paused:
		if event.physical_keycode in [KEY_O, KEY_F8]:
			set_combat_debug(not combat_debug)
			_show_notification("Boss 碰撞 / 射线诊断：" + ("开" if combat_debug else "关"), 1.6)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R:
			_retry_level()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_B and not is_instance_valid(boss) and not boss_beat:
			for cleaner in exit_cleaners:
				if cleaner.health > 0:
					cleaner.apply_damage(cleaner.max_health)
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func set_combat_debug(active: bool) -> void:
	combat_debug = active
	player.pulse_gun.trace_debug = active
	if is_instance_valid(boss):
		boss.combat_debug = active
		boss.debug_shapes.queue_redraw()

func _can_begin_fusion_here() -> bool:
	return prototype_ready


func _retry_level() -> void:
	is_level_complete = false
	super._retry_level()
	robot_visual.show()
	dead_enemies = 0
	for enemy in enemies:
		enemy.visible = enemy.health > 0
		if enemy.health <= 0:
			dead_enemies += 1
	player.global_position = PLAYTEST_ENTRY
	camera.global_position = PLAYTEST_ENTRY
	camera.reset_smoothing()

func _show_level_complete() -> void:
	is_level_complete = true
	player.controls_enabled = false
	player.pulse_gun.cancel()
	_show_notification("并联清扫者试玩通关 · R 重试", 9.0)
