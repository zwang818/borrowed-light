extends "res://tests/manual/b_combat/combat_test.gd"
## B-only 1:1 wrapper of A's spine terrain. No story/charging-device rules.
var enemies: Array[Node2D] = []
var baselines: Array[Dictionary] = []
var doors: Array[Node2D] = []
var overview := false
var art_enabled := false
var doors_open := true
var follow_zoom := 0.9
var electric_seams: Array[Node2D] = []
var scatter_prompt: Label
var scatter_station: Polygon2D
@onready var map: Node2D = $Map

func _ready() -> void:
	# Isolate A terrain/decorative layers from B combat rendering.
	map.z_index = -100
	$EnemyProjectiles.z_index = 12
	for path in ["Floor","Grid","Walls"]:
		get_node(path).free()
	var sentry_markers: Array[Node2D] = []
	var cleaner_markers: Array[Node2D] = []
	for marker in map.get_node("Markers").get_children():
		marker.show_guide = false
		if marker.object_type == "sentry": sentry_markers.append(marker)
		if marker.object_type == "cleaner": cleaner_markers.append(marker)
		if marker.object_type == "door": _make_door(marker)
	$SpawnPoints/PlayerSpawn.global_position = map.get_node("Markers/PlayerSpawn").global_position
	$SpawnPoints/SentrySpawn.global_position = sentry_markers[0].global_position
	$SpawnPoints/CleanerSpawn.global_position = cleaner_markers[0].global_position
	super._ready()
	_register_enemy($SpawnPoints/SentrySpawn/Sentry)
	_register_enemy($SpawnPoints/CleanerSpawn/Cleaner)
	for i in range(1,sentry_markers.size()):
		var unit = preload("res://scenes/enemies/sentry/sentry.tscn").instantiate()
		unit.set_script(preload("res://tests/manual/b_combat/floating_sentry.gd"))
		unit.entity_id = sentry_markers[i].object_id
		unit.position = sentry_markers[i].position
		add_child(unit)
		unit.configure($SpawnPoints/PlayerSpawn/Player,_test_enemy_readable,$EnemyProjectiles)
		_register_enemy(unit)
	for i in range(1,cleaner_markers.size()):
		var unit = preload("res://scenes/enemies/cleaner/cleaner.tscn").instantiate()
		unit.set_script(preload("res://tests/manual/b_combat/web_cleaner.gd"))
		unit.entity_id = cleaner_markers[i].object_id
		unit.position = cleaner_markers[i].position
		add_child(unit)
		var visual = preload("res://tests/manual/b_combat/web_cleaner_visual.gd").new()
		visual.name = "CleanerVisual"
		visual.match_hurtbox = true
		unit.add_child(visual)
		unit.configure($SpawnPoints/PlayerSpawn/Player,_cleaner_on_screen,_test_protocol_active)
		_register_enemy(unit)
	var player = $SpawnPoints/PlayerSpawn/Player
	player.scatter_unlocked = false
	player.selected_mode = player.AttackMode.LASER
	player.update_combat_mode()
	_build_scatter_station()
	player.z_index = 10
	player.pulse_gun.z_index = 5
	player.pulse_gun.configure_space(map.get_meta("map_bounds"),_test_enemy_readable)
	map.get_node("Reservations").hide()
	_set_art(false)
	_install_electric_seams(map.get_node("SpineArt"))
	_update_camera()

func _register_enemy(unit: Node2D) -> void:
	unit.persistent_projectiles = true
	if unit is StaticBody2D:
		unit.alternating_attacks = true
		unit.screen_detection = true
		unit.visibility_query = _sentry_on_screen
	unit.z_index = 10
	enemies.append(unit)
	baselines.append({"position":unit.global_position,"state":unit.get_combat_state().duplicate(true)})

func _make_door(marker: Node2D) -> void:
	var door = preload("res://tests/manual/a_map/preview_door.gd").new()
	door.position = marker.position
	door.rotation = marker.rotation
	door.size = marker.footprint
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	body.add_child(shape)
	door.add_child(body)
	var occluder := LightOccluder2D.new()
	occluder.name = "Occluder"
	door.add_child(occluder)
	add_child(door)
	door.set_open(true)
	doors.append(door)

func _set_art(value: bool) -> void:
	art_enabled = value
	map.get_node("SpineArt").set_art_enabled(value)
	map.set_depth_enabled(value)

func _test_enemy_readable(enemy: Node2D) -> bool:
	return not overview and super._test_enemy_readable(enemy)

func _sentry_on_screen(enemy: Node2D) -> bool:
	return not overview and enemy.is_model_on_screen()

func _cleaner_on_screen(enemy: Node2D) -> bool:
	return not overview and enemy.is_on_screen()

func _update_camera() -> void:
	if overview:
		var bounds: Rect2 = map.get_meta("map_bounds")
		var size := get_viewport_rect().size-Vector2(48,180)
		$Camera2D.zoom = Vector2.ONE*minf(size.x/bounds.size.x,size.y/bounds.size.y)
		$Camera2D.position = bounds.get_center()
	else:
		$Camera2D.zoom = Vector2.ONE*follow_zoom
		$Camera2D.position = $SpawnPoints/PlayerSpawn/Player.global_position+Vector2(120,-56)

func _process(_delta: float) -> void:
	_update_scatter_prompt()
	_update_camera()
	var player = $SpawnPoints/PlayerSpawn/Player
	var alive := 0
	for enemy in enemies:
		if enemy.health > 0: alive += 1
	$TestOverlay/WeaponStatus.text = "B · 脊柱等比例战斗灰盒（地图1:1）\nWASD移动 / Shift疾走 / 1激光 / 2散弹 / 左键攻击\n滚轮缩放 / Tab全图 / F美术切换 / O测试开关门 / P协议 / R全部重置\n生命 %d/%d · 敌人 %d/%d · 门%s%s" % [player.health,player.max_health,alive,enemies.size(),"开启" if doors_open else "关闭"," · 已死亡，请按R" if player.is_dead else ""]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_E:
			if try_unlock_scatter(): get_viewport().set_input_as_handled()
		KEY_TAB: overview = not overview
		KEY_F: _set_art(not art_enabled)
		KEY_O:
			if doors_open:
				for door in doors:
					for actor in [ $SpawnPoints/PlayerSpawn/Player ]+enemies:
						if Rect2(-door.size/2,door.size).grow(24).has_point(door.to_local(actor.global_position)): return
			doors_open = not doors_open
			for door in doors: door.set_open(doors_open)

func reset_test_combat() -> void:
	$SpawnPoints/PlayerSpawn/Player/Facing/XiaoyiCombatVisual.trail.clear()
	$CombatAudio.resetting = true
	$CombatAudio.stop_all()
	for bullet in $EnemyProjectiles.get_children():
		bullet.spent = true
		bullet.queue_free()
	for i in range(enemies.size()):
		enemies[i].global_position = baselines[i].position
		enemies[i].restore_combat_state(baselines[i].state)
	$SpawnPoints/PlayerSpawn/Player.restore_player($SpawnPoints/PlayerSpawn.global_position,3,[&"pulse_gun"])
	for seam in electric_seams: seam.reset_cycle()
	doors_open = true
	for door in doors: door.set_open(true)
	$CombatAudio.reset_audio()
	$BackgroundMusic.restart()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not overview:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			follow_zoom = minf(1.5,follow_zoom+0.1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			follow_zoom = maxf(0.5,follow_zoom-0.1)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _build_scatter_station() -> void:
	var anchor: Vector2 = map.get_node("Markers/ScatterEvolution").global_position
	scatter_station = Polygon2D.new()
	scatter_station.polygon = PackedVector2Array([Vector2(-16,-12),Vector2(16,-12),Vector2(16,12),Vector2(-16,12)])
	scatter_station.color = Color(0.3,0.75,0.85)
	scatter_station.position = anchor
	scatter_station.z_index = 5
	add_child(scatter_station)
	scatter_prompt = Label.new()
	scatter_prompt.add_theme_font_override("font",preload("res://assets/fonts/noto_sans_sc_gameplay_ui.ttf"))
	scatter_prompt.position = anchor+Vector2(-100,-48)
	scatter_prompt.z_index = 30
	scatter_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scatter_prompt)
	_update_scatter_prompt()

func _can_use_scatter_station() -> bool:
	var player = $SpawnPoints/PlayerSpawn/Player
	if overview or player.is_dead or not player.controls_enabled or player.has_protocol: return false
	var anchor: Vector2 = map.get_node("Markers/ScatterEvolution").global_position
	if player.global_position.distance_to(anchor)>80: return false
	var query := PhysicsRayQueryParameters2D.create(player.global_position,anchor,1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func try_unlock_scatter() -> bool:
	var player = $SpawnPoints/PlayerSpawn/Player
	if player.scatter_unlocked or not _can_use_scatter_station(): return false
	if player.pulse_gun.state != player.pulse_gun.State.IDLE: return false
	player.scatter_unlocked = true
	player.set_attack_mode(player.AttackMode.SCATTER)
	player.holster_remaining = player.HOLSTER_DELAY
	player.update_combat_mode()
	player.get_node("Facing/XiaoyiCombatVisual")._show_frame()
	_update_scatter_prompt()
	return true

func _update_scatter_prompt() -> void:
	if not is_instance_valid(scatter_prompt): return
	var unlocked: bool = $SpawnPoints/PlayerSpawn/Player.scatter_unlocked
	scatter_station.visible = not art_enabled
	scatter_station.color = Color(0.4,0.7,0.45) if unlocked else Color(0.3,0.75,0.85)
	scatter_prompt.visible = not overview
	scatter_prompt.text = "右臂散弹已装配" if unlocked else ("E · 装配右臂散弹（临时测试）" if _can_use_scatter_station() else "散弹装配点（靠近按 E）")

func _install_electric_seams(parent: Node) -> void:
	for child in parent.get_children():
		if child.get_script() == preload("res://scenes/levels/spine/spine_fixture.gd") and child.kind == "seam":
			child.arc_preview = false
			child.set_process(false)
			child.queue_redraw()
			var hazard = preload("res://tests/manual/b_combat/spine_electric_seam.gd").new()
			hazard.player = $SpawnPoints/PlayerSpawn/Player
			hazard.room = self
			hazard.span = child.span
			hazard.transform = child.global_transform
			hazard.z_index = 6
			add_child(hazard)
			electric_seams.append(hazard)
		_install_electric_seams(child)
