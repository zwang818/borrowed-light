extends "res://scenes/gameplay/abdomen_level.gd"

const BOSS_ACTOR := preload("res://tests/manual/b_combat/parallel_cleaner/boss.gd")
const TEST_PULSE := preload("res://tests/manual/b_combat/parallel_cleaner/test_pulse.gd")
const PULSE_SCENE := preload("res://tests/manual/b_combat/muzzle_pulse_gun.tscn")
const PLAYTEST_ENTRY := Vector2(640, 679)
const FUSION_POINT := Vector2(774, 476)
const SHAKE_TIME := 0.18
const SHAKE_AMOUNT := 3.0
const FATAL_HIT_FEEDBACK_TIME := 0.23
var prototype_ready := false
var boss: BOSS_ACTOR
var boss_beat := false
var wrecks: Array[Sprite2D] = []
var recovery_lines: Array[Line2D] = []
var wreck_starts := PackedVector2Array()
@export_range(0.8, 1.0, 0.05) var boss_art_scale := 0.85
var combat_debug := false
var shake_base := Vector2.ZERO
var shake_axis := Vector2.RIGHT
var shake_left := 0.0
var shake_duration := SHAKE_TIME
var shake_strength := SHAKE_AMOUNT

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
	shake_base = camera.offset
	notify_bg.offset_top = 15
	notify_bg.offset_bottom = 61
	notify_label.add_theme_font_size_override("font_size", 19)
	total_enemies += 1
	blueprint_known = true
	pulse_learned = true
	player.learn_pulse()
	player.collision_mask |= BOSS_ACTOR.CHASSIS_LAYER
	player.collision_layer |= BOSS_ACTOR.PLAYER_FEET_LAYER
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

func _on_player_died() -> void:
	if is_instance_valid(boss) and boss.applying_feedback_hit:
		var attacker := boss
		attacker.holding_fatal_feedback = true
		await get_tree().create_timer(FATAL_HIT_FEEDBACK_TIME, false, true).timeout
		if is_instance_valid(attacker) and boss == attacker and player.is_dead:
			_open_death_menu()
		return
	_open_death_menu()

func _open_death_menu() -> void:
	_clear_shake()
	if is_instance_valid(boss):
		boss.cancel_preview_actions()
		if boss.phase not in [BOSS_ACTOR.Phase.ASSEMBLE, BOSS_ACTOR.Phase.OFFLINE]:
			boss._switch(BOSS_ACTOR.Phase.RECOVER, 0.0)
		boss.queue_redraw()
	robot_visual.show()
	super._on_player_died()

func _remaining_cleaners() -> int:
	# Reserve the pending phase before any death callback can open the gate.
	return super._remaining_cleaners() + int(not boss_beat and not exit_cleaners.is_empty())

func _terminal_prompt() -> String:
	if is_instance_valid(boss) and not boss_beat:
		return "终端锁定 · 维护系统接管"
	return super._terminal_prompt()

func _on_enemy_died(id: StringName) -> void:
	super._on_enemy_died(id)
	if prototype_ready and id in EXIT_CLEANER_IDS and not boss_beat and not is_instance_valid(boss):
		if exit_cleaners.size() == 2 and exit_cleaners[0].health <= 0 and exit_cleaners[1].health <= 0:
			_begin_fusion()

func _begin_fusion() -> void:
	boss = BOSS_ACTOR.new()
	boss.name = "ParallelCleaner"
	boss.target = player
	boss.visual_scale = boss_art_scale
	boss.combat_debug = combat_debug
	boss.guard_point = FUSION_POINT
	var machine: Node2D = map.get_node("Walls/ExitMachine")
	boss.machine_bounds = Rect2(machine.to_global(Vector2.ZERO), machine.to_global(machine.size) - machine.to_global(Vector2.ZERO))
	boss.position = to_local(FUSION_POINT)
	add_child(boss)
	boss.body_sprite.hide()
	boss.defeated.connect(_on_fusion_defeated)
	boss.slammed.connect(_on_slammed)
	boss.throw_landed.connect(_on_throw_landed)
	for i in range(exit_cleaners.size()):
		var cleaner := exit_cleaners[i]
		var model: Node2D = cleaner.get_node("CleanerModel")
		var wreck := Sprite2D.new()
		wreck.texture = model.pieces[15]
		wreck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wreck.scale = Vector2(model.frame_scale, model.frame_scale * 0.76)
		wreck.offset = Vector2(0, -wreck.texture.get_height() * 0.38)
		wreck.rotation = -0.22 if i == 0 else 0.13
		wreck.flip_h = i == 1
		wreck.modulate = Color(0.61, 0.59, 0.52)
		add_child(wreck)
		wreck.global_position = cleaner.global_position
		wrecks.append(wreck)
		wreck_starts.append(wreck.global_position)
		var cable := Line2D.new()
		cable.width = 2.0
		cable.default_color = Color(0.66, 0.49, 0.30, 0.8)
		add_child(cable)
		recovery_lines.append(cable)
		cleaner.hide()
	_show_notification("清扫单元全部离线 · 机体列为高危 · 启动并联处置", 2.45)

func _on_fusion_defeated() -> void:
	if boss_beat:
		return
	boss_beat = true
	_clear_shake()
	super._on_enemy_died(&"parallel_cleaner")
	_show_notification("并联清扫者已停机 · 终端区开放（口令 0417）", 3.7)

func _process(delta: float) -> void:
	super._process(delta)
	if not prototype_ready or get_tree().paused or not is_instance_valid(boss):
		return
	_advance_shake(delta)
	robot_visual.visible = not boss.grab_visual.override_player()
	if wrecks.is_empty():
		return
	var closing := clampf((1.38 - boss.left) / 0.91, 0.0, 1.0) if boss.phase == BOSS_ACTOR.Phase.ASSEMBLE else 1.0
	for i in range(wrecks.size()):
		var docking := FUSION_POINT + Vector2(-21 if i == 0 else 17, 3)
		wrecks[i].global_position = wreck_starts[i].lerp(docking, smoothstep(0.0, 1.0, closing))
		recovery_lines[i].points = PackedVector2Array([to_local(wrecks[i].global_position), to_local(docking)])
	if closing >= 0.83:
		boss.body_sprite.show()
		_clear_wrecks()

func _on_slammed(at: Vector2) -> void:
	_start_shake(boss.global_position.direction_to(at), SHAKE_AMOUNT, SHAKE_TIME)

func _on_throw_landed(direction: Vector2) -> void:
	_start_shake(direction, 2.0, 0.12)

func _start_shake(direction: Vector2, amount: float, duration: float) -> void:
	shake_axis = direction
	shake_left = duration
	shake_duration = duration
	shake_strength = amount
	camera.offset = shake_base + shake_axis * shake_strength

func _advance_shake(delta: float) -> void:
	if shake_left <= 0.0:
		return
	shake_left = maxf(0.0, shake_left - delta)
	if shake_left <= 0.00001:
		_clear_shake()
		return
	var remaining := shake_left / shake_duration
	camera.offset = shake_base + shake_axis * shake_strength * remaining * remaining * cos((1.0 - remaining) * TAU * 1.7)

func _clear_shake() -> void:
	shake_left = 0.0
	camera.offset = shake_base

func _clear_wrecks() -> void:
	for wreck in wrecks:
		wreck.queue_free()
	for cable in recovery_lines:
		cable.queue_free()
	wrecks.clear()
	recovery_lines.clear()
	wreck_starts.clear()

func _retry_level() -> void:
	_clear_shake()
	if is_instance_valid(boss):
		boss.cancel_preview_actions()
		remove_child(boss)
		boss.queue_free()
		boss = null
	_clear_wrecks()
	boss_beat = false
	is_level_complete = false
	for silk in get_tree().get_nodes_in_group("b_cleaner_webs"):
		silk.queue_free()
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
