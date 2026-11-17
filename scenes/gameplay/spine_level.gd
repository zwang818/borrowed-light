extends "res://tests/manual/b_combat/spine_combat_test.gd"
## Production wrapper shares the approved geometry and combat, not debug controls.
const JOURNEY = preload("res://scenes/gameplay/journey_save.gd")
var entry_ready := false
var entry_progress := 0.0
var menus
var health_display
var save_path := ""
var save_data: Dictionary = {}
var notice: Label

func is_entry_ready() -> bool:
	return entry_ready

func get_entry_progress() -> float:
	return entry_progress

func _enter_tree() -> void:
	super._enter_tree()
	$SpawnPoints/PlayerSpawn/Player.set_script(preload("res://scenes/player/xiaoyi_journey_player.gd"))

func _ready() -> void:
	await super._ready()
	entry_progress = 0.75
	_set_art(true)
	$TestOverlay.hide()
	$BackgroundMusic.stop()
	$BackgroundMusic.set_process(false)
	var player = $SpawnPoints/PlayerSpawn/Player
	var arriving := get_tree().has_meta("spine_entry")
	if arriving:
		var entry: Dictionary = get_tree().get_meta("spine_entry")
		get_tree().remove_meta("spine_entry")
		save_path = entry.get("path", "")
		save_data = JOURNEY.read_save(save_path) if not save_path.is_empty() else {}
		player.health = clampi(entry.get("health",player.max_health),1,player.max_health)
	elif get_tree().has_meta("journey_session"):
		var session: Dictionary = get_tree().get_meta("journey_session")
		get_tree().remove_meta("journey_session")
		save_path = session.path
		save_data = session.get("data", {})
	player.scatter_unlocked = save_data.get("scatter_unlocked", false)
	player.restore_player($SpawnPoints/PlayerSpawn.global_position,player.health,[&"pulse_gun"])
	player.update_combat_mode()
	if not arriving and save_data.has("snapshot"):
		_restore_room_snapshot(player, save_data.snapshot)
	_update_camera()
	$Camera2D.reset_smoothing()
	var hud := CanvasLayer.new()
	add_child(hud)
	health_display = preload("res://scenes/gameplay/health_hearts.gd").new()
	health_display.theme = preload("res://scenes/gameplay/gameplay_ui_theme.tres")
	health_display.position = Vector2(20,20)
	health_display.size = Vector2(252,82)
	hud.add_child(health_display)
	notice = Label.new()
	notice.theme = health_display.theme
	notice.position = Vector2(24,110)
	hud.add_child(notice)
	menus = preload("res://scenes/gameplay/game_menus.gd").new()
	add_child(menus)
	menus.retry_requested.connect(_retry)
	menus.title_requested.connect(_return_title)
	menus.save_requested.connect(func():
		_save_progress()
		menus.close_and_resume())
	player.died.connect(func(): menus.show_death())
	var pause_input := preload("res://scenes/gameplay/pause_input.gd").new()
	pause_input.target = self
	pause_input.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_input)
	if not save_path.is_empty():
		var window_close := preload("res://scenes/gameplay/journey_window_close.gd").new()
		window_close.save_before_exit = func() -> bool: return _save_progress(false)
		add_child(window_close)
	if arriving and not save_path.is_empty():
		_save_progress(false)
	entry_progress = 1.0
	entry_ready = true
	if not get_tree().root.has_node("EntryLoading"):
		on_entry_revealed()

func on_entry_revealed() -> void:
	if $SpawnPoints/PlayerSpawn/Player.is_dead:
		menus.show_death()

func _process(_delta: float) -> void:
	_update_camera()
	_update_scatter_prompt()
	var player = $SpawnPoints/PlayerSpawn/Player
	if health_display != null:
		health_display.set_health(player.health,player.max_health)

func _unhandled_input(_event: InputEvent) -> void:
	pass # No protocol injection, reset hotkey, zoom or overview in gameplay.

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if try_unlock_scatter():
			_save_progress()
			get_viewport().set_input_as_handled()

func _update_scatter_prompt() -> void:
	if not is_instance_valid(scatter_prompt): return
	var player = $SpawnPoints/PlayerSpawn/Player
	scatter_station.hide()
	scatter_prompt.visible = not player.scatter_unlocked and _can_use_scatter_station()
	scatter_prompt.text = "E · 装配右臂散弹"

func _toggle_pause() -> void:
	menus.toggle_pause()

func _retry() -> void:
	menus.close_and_resume()
	reset_test_combat()
	$BackgroundMusic.stop()
	_set_art(true)

func _capture_room_snapshot(player: Node2D) -> Dictionary:
	var snapshot := JOURNEY.SNAPSHOT.capture(self, player, enemies, $EnemyProjectiles)
	var seam_phases := []
	for seam in electric_seams:
		seam_phases.append(seam.seconds)
	snapshot["room"] = {"doors_open": doors_open, "seam_phases": seam_phases,
		"entrance_hazards": entrance_hazards.capture_journey_state()}
	return snapshot

func _restore_room_snapshot(player: Node2D, snapshot: Dictionary) -> void:
	var state: Dictionary = snapshot.room
	doors_open = state.get("doors_open", true) == true
	for door in doors:
		door.set_open(doors_open)
	JOURNEY.SNAPSHOT.restore(player, enemies, $EnemyProjectiles, snapshot)
	var phases = state.get("seam_phases")
	if phases is Array:
		for i in range(mini(phases.size(), electric_seams.size())):
			var seam = electric_seams[i]
			if JOURNEY.SNAPSHOT.number(phases[i]):
				seam.seconds = fposmod(phases[i], seam.PERIOD)
				seam.last_frame = int(seam.seconds * 14)
				seam.previous = player.global_position
				seam.queue_redraw()
	var hazards = state.get("entrance_hazards")
	if hazards is Dictionary:
		entrance_hazards.restore_journey_state(hazards)

func _save_progress(show_result: bool = true) -> bool:
	if save_path.is_empty():
		notice.text = "请从标题开始旅程后保存。"
		return false
	save_data["first_level_cleared"] = true
	var player := $SpawnPoints/PlayerSpawn/Player
	save_data["scatter_unlocked"] = player.scatter_unlocked
	save_data["snapshot"] = _capture_room_snapshot(player)
	var result := JOURNEY.write_save(save_path, save_data, JOURNEY.SPINE)
	if result != OK:
		notice.text = "存档失败，请检查磁盘空间或文件权限。"
	elif show_result:
		notice.text = "旅程已保存。"
	return result == OK

func _return_title() -> void:
	if not save_path.is_empty() and not _save_progress(): return
	menus.close_and_resume()
	var loading := preload("res://scenes/ui/intro_cutscene/entry_loading.gd").new()
	loading.name = "EntryLoading"
	get_tree().root.add_child(loading)
	loading.begin("res://scenes/main.tscn")
