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
var scatter_approach = preload("res://scenes/gameplay/interaction_point.gd").new()

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
	if get_tree().has_meta("spine_entry"):
		var entry: Dictionary = get_tree().get_meta("spine_entry")
		get_tree().remove_meta("spine_entry")
		save_path = entry.get("path", "")
		player.health = clampi(entry.get("health",player.max_health),1,player.max_health)
	elif get_tree().has_meta("journey_session"):
		var session: Dictionary = get_tree().get_meta("journey_session")
		get_tree().remove_meta("journey_session")
		save_path = session.path
	if not save_path.is_empty():
		save_data = JOURNEY.read_save(save_path)
		player.scatter_unlocked = save_data.get("scatter_unlocked",false)
	player.restore_player($SpawnPoints/PlayerSpawn.global_position,player.health,[&"pulse_gun"])
	player.update_combat_mode()
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
	entry_progress = 1.0
	entry_ready = true

func _process(delta: float) -> void:
	_update_camera()
	_refresh_scatter_response(delta)
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
	if not is_instance_valid(scatter_prompt):
		return
	scatter_station.hide()
	scatter_prompt.hide()
	if scatter_approach.is_inside_tree():
		return
	add_child(scatter_approach)
	scatter_approach.global_position = scatter_station.global_position
	scatter_approach.cue = scatter_approach.Cue.SEAM
	scatter_approach.cue_offset = Vector2(-6, -21)
	scatter_prompt.position = to_local(scatter_station.global_position) + Vector2(-66, -66)
	scatter_prompt.add_theme_font_size_override("font_size", 13)
	scatter_prompt.add_theme_color_override("font_color", Color("c5decd"))
	scatter_prompt.add_theme_color_override("font_outline_color", Color("14201e"))
	scatter_prompt.add_theme_constant_override("outline_size", 3)
	scatter_prompt.text = "E · 装配右臂散弹"

func _refresh_scatter_response(delta: float) -> void:
	if not scatter_approach.is_inside_tree():
		return
	var player = $SpawnPoints/PlayerSpawn/Player
	var active: bool = not player.scatter_unlocked and not player.is_dead and player.controls_enabled and not player.has_protocol
	scatter_approach.visible = active
	scatter_approach.update_approach(player.global_position, active and _can_use_scatter_station(), player.velocity.length_squared() < 1.0, delta)
	scatter_prompt.visible = active and scatter_approach.prompt_ready

func _toggle_pause() -> void:
	menus.toggle_pause()

func _retry() -> void:
	menus.close_and_resume()
	reset_test_combat()
	$BackgroundMusic.stop()
	_set_art(true)

func _save_progress() -> bool:
	if save_path.is_empty():
		notice.text = "请从标题开始旅程后保存。"
		return false
	save_data["first_level_cleared"] = true
	save_data["scatter_unlocked"] = $SpawnPoints/PlayerSpawn/Player.scatter_unlocked
	var result := JOURNEY.write_save(save_path,save_data)
	notice.text = "旅程已保存，读档后从脊柱入口继续。" if result == OK else "保存失败，请检查磁盘空间。"
	return result == OK

func _return_title() -> void:
	if not save_path.is_empty() and not _save_progress(): return
	menus.close_and_resume()
	var loading := preload("res://scenes/ui/intro_cutscene/entry_loading.gd").new()
	loading.name = "EntryLoading"
	get_tree().root.add_child(loading)
	loading.begin("res://scenes/main.tscn")
