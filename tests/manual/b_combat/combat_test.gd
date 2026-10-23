extends Node2D

## Test-only bindings, installed before the Player enters the tree.
## Shared project Input Map remains owned by the integration module.
func _enter_tree() -> void:
	var bindings := {
		&"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP],
		&"move_down": [KEY_S, KEY_DOWN],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for physical_key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = physical_key
			InputMap.action_add_event(action, event)
	if not InputMap.has_action(&"shoot"):
		InputMap.add_action(&"shoot")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"shoot", event)


func _ready() -> void:
	$SpawnPoints/CleanerSpawn/Cleaner.configure($SpawnPoints/PlayerSpawn/Player, _test_enemy_readable, _test_protocol_active)
	$SpawnPoints/PlayerSpawn/Player/Facing/PulseGun.configure_space(Rect2(0, 0, 960, 640), _test_enemy_readable)
	$SpawnPoints/SentrySpawn/Sentry.configure($SpawnPoints/PlayerSpawn/Player, _test_enemy_readable, $EnemyProjectiles)


# Explicit full-bright test adapter, not C's lighting/room-memory implementation.
# Sentry independently verifies distance and wall LOS after this screen check.
func _test_enemy_readable(enemy: Node2D) -> bool:
	var screen_position := get_viewport().get_canvas_transform() * enemy.global_position
	return get_viewport_rect().grow(-20.0).has_point(screen_position)


func _test_protocol_active() -> bool:
	return $SpawnPoints/PlayerSpawn/Player.has_protocol


func _unhandled_input(event: InputEvent) -> void:
	# Debug-only protocol injection, not the production terminal interaction.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P:
		var player := $SpawnPoints/PlayerSpawn/Player
		player.set_protocol_active(not player.has_protocol)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		reset_test_combat()
		get_viewport().set_input_as_handled()


func reset_test_combat() -> void:
	$CombatAudio.resetting = true
	$CombatAudio.stop_all()
	$SpawnPoints/CleanerSpawn/Cleaner.restore_combat_state({"entity_id": &"cleaner_test_01", "health": $SpawnPoints/CleanerSpawn/Cleaner.max_health})
	for bullet in $EnemyProjectiles.get_children():
		bullet.spent = true
		bullet.queue_free()
	$SpawnPoints/SentrySpawn/Sentry.restore_combat_state({"entity_id": &"sentry_test_01", "health": $SpawnPoints/SentrySpawn/Sentry.max_health})
	$SpawnPoints/PlayerSpawn/Player.restore_player($SpawnPoints/PlayerSpawn.global_position, $SpawnPoints/PlayerSpawn/Player.max_health, [&"pulse_gun"])

	$CombatAudio.reset_audio()
	$BackgroundMusic.restart()


func _process(_delta: float) -> void:
	var gun := $SpawnPoints/PlayerSpawn/Player/Facing/PulseGun
	var status := "就绪 · 点按左键蓄力"
	if gun.state == gun.State.CHARGING:
		status = "蓄力中可瞄准 · 剩余 %.1f 秒" % gun.remaining
	elif gun.state == gun.State.FIRING:
		status = "激光 · 剩余 %.1f 秒" % gun.remaining
	var player := $SpawnPoints/PlayerSpawn/Player
	var sentry := $SpawnPoints/SentrySpawn/Sentry
	$TestOverlay/WeaponStatus.text = "全亮战斗测试 · WASD 移动 / 左键蓄力 / R 重置 / P 测试协议\n玩家：%d / %d · 哨机：%d / %d\n脉冲枪：%s%s" % [
		player.health, player.max_health, sentry.health, sentry.max_health, status,
		"\n已死亡 · 按 R 测试恢复" if player.is_dead else ("\n协议测试开启：清扫者忽略你，玩家不能攻击" if player.has_protocol else "")
	]
