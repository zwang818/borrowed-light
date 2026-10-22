extends Node2D

const PLAYER = preload("res://ab_test/combat_snapshot/player.tscn")
const CLEANER = preload("res://scenes/enemies/cleaner/cleaner.tscn")
const SKIN = preload("res://ab_test/combat_skin.gd")
const ROBOT = preload("res://assets/sprites/title/title_robot.svg")
const PICKUP_DISTANCE := 40.0
var player: CharacterBody2D
var cleaners: Array[CharacterBody2D] = []
var pickup: Node2D
var robot: Sprite2D
var spawn_position: Vector2
var camera: Camera2D
var acquired := false
var combat_audio: Node
var background_music: AudioStreamPlayer

func _enter_tree() -> void:
	var bindings := {&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT], &"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN]}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	if not InputMap.has_action(&"shoot"):
		InputMap.add_action(&"shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"shoot", click)

func _ready() -> void:
	spawn_position = $Map/Markers/PlayerSpawn.global_position
	player = PLAYER.instantiate()
	player.position = spawn_position
	player.pulse_gun_equipped = false
	$Actors.add_child(player)
	player.get_node("Facing/Body").hide()
	player.get_node("Facing/DirectionIndicator").hide()
	robot = Sprite2D.new()
	robot.texture = ROBOT
	robot.scale = Vector2.ONE * 0.30
	robot.position = Vector2(0, -5)
	player.get_node("Facing").add_child(robot)
	var gun = player.pulse_gun
	gun.get_node("Barrel").hide()
	var gun_skin := SKIN.new()
	gun.add_child(gun_skin)
	gun.move_child(gun_skin, 0)
	gun.configure_space($Map.get_meta("map_bounds"), _enemy_readable)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * 1.6
	player.add_child(camera)
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()
	for marker in $Map/Markers.get_children():
		match marker.object_type:
			"spawn":
				if marker.object_id == "p1_player_spawn":
					marker.hide()
			"weapon":
				if marker.content_id == "pulse_gun":
					pickup = Node2D.new()
					pickup.position = marker.global_position
					$Actors.add_child(pickup)
					var ring := Polygon2D.new()
					ring.polygon = PackedVector2Array([Vector2(-24, 0), Vector2(0, -24), Vector2(24, 0), Vector2(0, 24)])
					ring.color = Color(0.3, 0.85, 0.9, 0.18)
					pickup.add_child(ring)
					var model := SKIN.new()
					model.position.x = 12
					model.scale = Vector2.ONE * 1.5
					pickup.add_child(model)
					marker.hide()
			"cleaner":
				var enemy = CLEANER.instantiate()
				enemy.position = marker.global_position
				enemy.entity_id = StringName(marker.object_id)
				# Short patrol stays in each combat clearing, away from the pickup throat.
				enemy.patrol_offsets = PackedVector2Array([Vector2.ZERO, Vector2(-48, 0)])
				$Actors.add_child(enemy)
				enemy.configure(player, _enemy_readable, _protocol_active)
				enemy.get_node("Facing/Body").hide()
				var model := SKIN.new()
				model.kind = "cleaner"
				enemy.get_node("Facing").add_child(model)
				cleaners.append(enemy)
				marker.hide()

	combat_audio = preload("res://ab_test/combat_audio.gd").new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)
	background_music = preload("res://ab_test/music/background_music.gd").new()
	background_music.name = "BackgroundMusic"
	add_child(background_music)

# Full-bright AB fixture. C's lighting/room-state integration is deliberately absent.
func _enemy_readable(enemy: Node2D) -> bool:
	var screen := get_viewport().get_canvas_transform() * enemy.global_position
	return get_viewport_rect().grow(-20).has_point(screen)

func _protocol_active() -> bool:
	return player.has_protocol

func can_pick_up() -> bool:
	if acquired or player.is_dead or player.global_position.distance_to(pickup.global_position) > PICKUP_DISTANCE:
		return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, pickup.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func try_pick_up() -> bool:
	if not can_pick_up():
		return false
	acquired = true
	player.pulse_gun_equipped = true
	player.pulse_gun.show()
	pickup.hide()
	return true

func retry() -> void:
	combat_audio.resetting = true
	combat_audio.stop_all()
	player.restore_player(spawn_position, player.max_health, [&"pulse_gun"] if acquired else [])
	for enemy in cleaners:
		enemy.restore_combat_state({"entity_id": enemy.entity_id, "health": enemy.max_health})
	combat_audio.reset_audio()
	background_music.restart()
	camera.force_update_scroll()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			try_pick_up()
		elif event.physical_keycode == KEY_R:
			retry()

func _process(_delta: float) -> void:
	# Keep the title-inspired body upright; the weapon alone follows aim.
	robot.global_rotation = 0
	robot.global_position = player.global_position + Vector2(0, -5)
	var alive := 0
	for enemy in cleaners:
		if enemy.health > 0:
			alive += 1
	var status := "未获得武器 · 无攻击能力"
	if acquired:
		status = "脉冲枪就绪 · 左键蓄力"
		if player.pulse_gun.state == player.pulse_gun.State.CHARGING:
			status = "蓄力中 · 结束时确定瞄准方向"
		elif player.pulse_gun.state == player.pulse_gun.State.FIRING:
			status = "激光发射中"
	elif can_pick_up():
		status = "按 E 拾取脉冲枪"
	if player.is_dead:
		status = "小一已倒下 · 按 R 重试（保留已获得的枪）"
	$HUD/Panel/Status.text = "  AB 腹腔战斗测试 · 全亮  \n  WASD 移动 / E 拾取 / 左键蓄力 / R 重试  \n  小一 %d / %d   清扫者剩余 %d / 3  \n  %s  " % [player.health, player.max_health, alive, status]
