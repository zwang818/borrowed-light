extends "res://scenes/gameplay/abdomen_level.gd"

const BOSS_ACTOR := preload("res://scenes/enemies/parallel_cleaner/boss.gd")
const AUDIO_PREFERENCES := preload("res://scenes/ui/user_settings.gd")
const FOOTSTEPS := preload("res://scenes/gameplay/abdomen_footsteps.gd")
const MUSIC_VOLUME_DB := -7.0
const DIALOGUE_MUSIC_VOLUME_DB := -15.0
const BOSS_MUSIC_VOLUME_DB := -8.5
const SILENT_MUSIC_VOLUME_DB := -80.0
const BOSS_STATE_KEY := "parallel_cleaner"
const FUSION_POINT := Vector2(774, 476)
const BOSS_ENTRANCE_SIZE := Vector2(132, 16)
const SHAKE_TIME := 0.18
const SHAKE_AMOUNT := 3.0
const SHAKE_SAMPLE_RATE := 60.0
const FATAL_HIT_FEEDBACK_TIME := 0.23

@export_range(0.8, 1.0, 0.05) var boss_art_scale := 0.85
@export_range(1, 10) var clearance_damage := 2
@export var seal_boss_room := true

@onready var boss_entrance := $BossEntrance as Marker2D
@onready var boss_retry_point := $BossRetryPoint as Marker2D
@onready var abdomen_music: AudioStreamPlayer = $AbdomenMusic
@onready var boss_music: AudioStreamPlayer = $BossMusic

var music_fade: Tween
var boss_music_fade: Tween
var boss_music_active := false
var footsteps: FOOTSTEPS
var boss: BOSS_ACTOR
var boss_beat := false
var boss_resume: Dictionary = {}
var boss_gate: StaticBody2D
var retry_at_boss_gate := false
var combat_debug := false
var wrecks: Array[Sprite2D] = []
var recovery_lines: Array[Line2D] = []
var wreck_starts := PackedVector2Array()
var shake_base := Vector2.ZERO
var shake_axis := Vector2.RIGHT
var shake_left := 0.0
var shake_duration := SHAKE_TIME
var shake_strength := SHAKE_AMOUNT
var shake_offsets := PackedVector2Array()


func _ready() -> void:
	await super._ready()
	shake_base = camera.offset
	if scene_file_path == JOURNEY_SAVE.SCENE:
		abdomen_voice.visibility_changed.connect(_update_music_mix)
		footsteps = FOOTSTEPS.new()
		footsteps.name = "XiaoyiFootsteps"
		footsteps.player = player
		add_child(footsteps)


func on_entry_revealed() -> void:
	super.on_entry_revealed()
	if scene_file_path != JOURNEY_SAVE.SCENE or abdomen_music.playing:
		return
	if AudioServer.get_bus_index(AUDIO_PREFERENCES.MUSIC_BUS) < 0:
		AUDIO_PREFERENCES.apply_audio(AUDIO_PREFERENCES.read_preferences())
	abdomen_music.bus = AUDIO_PREFERENCES.MUSIC_BUS
	boss_music.bus = AUDIO_PREFERENCES.MUSIC_BUS
	abdomen_music.volume_db = MUSIC_VOLUME_DB
	abdomen_music.play()
	_set_boss_music(is_instance_valid(boss) and not boss_beat and not player.is_dead)


func _update_music_mix() -> void:
	if is_instance_valid(music_fade):
		music_fade.kill()
	var target_db := DIALOGUE_MUSIC_VOLUME_DB if abdomen_voice.visible else MUSIC_VOLUME_DB
	if boss_music_active:
		target_db = SILENT_MUSIC_VOLUME_DB
	music_fade = abdomen_music.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_fade.tween_property(abdomen_music, "volume_db", target_db, 0.22)


func _set_boss_music(active: bool) -> void:
	if is_instance_valid(footsteps):
		footsteps.set_boss_battle(active)
	if scene_file_path != JOURNEY_SAVE.SCENE or not abdomen_music.playing or active == boss_music_active:
		return
	boss_music_active = active
	if is_instance_valid(boss_music_fade):
		boss_music_fade.kill()
	if active:
		boss_music.volume_db = BOSS_MUSIC_VOLUME_DB
		boss_music.play()
	else:
		boss_music_fade = boss_music.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		boss_music_fade.tween_property(boss_music, "volume_db", SILENT_MUSIC_VOLUME_DB, 0.65)
		boss_music_fade.tween_callback(boss_music.stop)
	_update_music_mix()


func _show_level_complete() -> void:
	super._show_level_complete()
	if is_level_complete:
		abdomen_music.stream_paused = true
		boss_music.stop()


func _configure_player() -> void:
	await super._configure_player()
	if exit_cleaners.size() == 2:
		player.collision_mask |= BOSS_ACTOR.CHASSIS_LAYER
		player.collision_layer |= BOSS_ACTOR.PLAYER_FEET_LAYER


func _configure_enemies() -> void:
	super._configure_enemies()
	total_enemies += int(exit_cleaners.size() == 2)


func _setup_terminal_gate() -> void:
	super._setup_terminal_gate()
	if not seal_boss_room or exit_cleaners.size() != 2:
		return
	boss_gate = _add_door(interactables_parent.to_local(boss_entrance.global_position), "p1_boss_entry_gate")
	# The fight controls this door. Loading outside the room must leave it accessible.
	interactables.erase(boss_gate)
	boss_gate.get_child(0).shape.size = BOSS_ENTRANCE_SIZE
	boss_gate.get_node("FacilityVisual").dimensions = BOSS_ENTRANCE_SIZE
	_set_boss_gate_open(true)


func _set_boss_gate_open(open: bool) -> void:
	if not is_instance_valid(boss_gate):
		return
	boss_gate.collision_layer = 0 if open else BOSS_ACTOR.WORLD
	boss_gate.set_meta("is_open", open)
	var visual = boss_gate.get_node("FacilityVisual")
	visual.set_status(open)
	visual.open_amount = 1.0 if open else 0.0


func _capture_room_snapshot() -> Dictionary:
	var snapshot := super._capture_room_snapshot()
	var progress := boss_resume.duplicate()
	progress["defeated"] = boss_beat
	progress["retry_at_entrance"] = retry_at_boss_gate
	if is_instance_valid(boss) and boss.health > 0:
		var interrupted := boss.phase == BOSS_ACTOR.Phase.CLEARANCE
		progress["health"] = boss.health
		progress["position"] = JOURNEY_SAVE.SNAPSHOT.pack_vector(boss.global_position)
		progress["clearance_pending"] = boss.clearance_pending or interrupted
		progress["clearance_used"] = boss.clearance_used and not interrupted
	snapshot.room[BOSS_STATE_KEY] = progress
	return snapshot


func _restore_room_snapshot(snapshot: Dictionary) -> void:
	var state: Dictionary = snapshot.room
	var progress = state.get(BOSS_STATE_KEY)
	boss_beat = state.get("terminal_activated") == true or first_level_cleared
	if progress is Dictionary:
		boss_beat = boss_beat or progress.get("defeated") == true
		retry_at_boss_gate = (is_instance_valid(boss_gate) and not boss_beat
			and progress.get("retry_at_entrance") == true and snapshot.player.get("health", 1) == 0)
		if not boss_beat and JOURNEY_SAVE.SNAPSHOT.number(progress.get("health")) and int(progress.health) > 0:
			boss_resume = progress.duplicate()
	else:
		var doors = state.get("open_doors")
		# Old saves already past the gate keep their unlocked progression.
		boss_beat = boss_beat or (doors is Dictionary and doors.has("p1_terminal_access_gate"))
	super._restore_room_snapshot(snapshot)
	if boss_beat and exit_cleaners.size() == 2:
		dead_enemies += 1
		for cleaner in exit_cleaners:
			if cleaner.health <= 0:
				cleaner.hide()
	elif not boss_resume.is_empty():
		# Grab bindings and in-flight Boss attacks are restarted with a fresh tell.
		player.pulse_gun.cancel()


func _remaining_cleaners() -> int:
	return super._remaining_cleaners() + int(not boss_beat and exit_cleaners.size() == 2)


func _terminal_prompt() -> String:
	if is_instance_valid(boss) and not boss_beat:
		return "终端锁定 · 并联清扫者仍在运行"
	return super._terminal_prompt()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_try_begin_fusion()


func _on_enemy_died(id: StringName) -> void:
	super._on_enemy_died(id)
	if id in EXIT_CLEANER_IDS:
		_try_begin_fusion()


func _can_begin_fusion_here() -> bool:
	return Geometry2D.is_point_in_polygon(exit_combat_zone.to_local(player.global_position), exit_combat_zone.polygon)


func _try_begin_fusion() -> void:
	if not entry_ready or get_tree().paused or player.is_dead or not player.controls_enabled:
		return
	if boss_beat or is_instance_valid(boss) or exit_cleaners.size() != 2:
		return
	if exit_cleaners[0].health > 0 or exit_cleaners[1].health > 0 or not _can_begin_fusion_here():
		return
	_begin_fusion()


func _begin_fusion() -> void:
	_set_boss_gate_open(false)
	boss = BOSS_ACTOR.new()
	boss.name = "ParallelCleaner"
	boss.target = player
	boss.visual_scale = boss_art_scale
	boss.clearance_damage = clearance_damage
	boss.combat_debug = combat_debug
	boss.configure_arena(exit_combat_zone)
	var machine: Node2D = map.get_node("Walls/ExitMachine")
	boss.machine_bounds = Rect2(machine.to_global(Vector2.ZERO), machine.to_global(machine.size) - machine.to_global(Vector2.ZERO))
	boss.position = to_local(FUSION_POINT)
	add_child(boss)
	_set_boss_music(true)
	boss.defeated.connect(_on_fusion_defeated)
	boss.slammed.connect(_on_slammed)
	boss.clearance.shake_requested.connect(_on_clearance_shake)
	boss.throw_landed.connect(_on_throw_landed)
	if not boss_resume.is_empty():
		_resume_fusion()
		return
	boss.body_sprite.hide()
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

func _resume_fusion() -> void:
	var resume_at := JOURNEY_SAVE.SNAPSHOT.vector(boss_resume.get("position"), FUSION_POINT)
	if boss._chassis_arena().has_point(resume_at) and boss._chassis_is_clear_at(resume_at):
		boss.global_position = resume_at
	boss.health = clampi(int(boss_resume.health), 1, BOSS_ACTOR.MAX_HP)
	boss.clearance_pending = boss_resume.get("clearance_pending") == true
	boss.clearance_used = boss_resume.get("clearance_used") == true
	boss._switch(BOSS_ACTOR.Phase.ASSEMBLE, 0.5)
	for cleaner in exit_cleaners:
		cleaner.hide()
	boss_resume.clear()


func _on_fusion_defeated() -> void:
	if boss_beat:
		return
	boss_beat = true
	_set_boss_music(false)
	boss_resume.clear()
	_set_boss_gate_open(true)
	_clear_shake()
	super._on_enemy_died(&"parallel_cleaner")
	_show_notification("并联清扫者已停机 · 终端区开放" if _remaining_cleaners() == 0 else "并联清扫者已停机", 3.7)


func _on_player_died() -> void:
	if (is_instance_valid(boss_gate) and is_instance_valid(boss) and not boss_beat
			and _can_begin_fusion_here()):
		retry_at_boss_gate = true
	if is_instance_valid(boss) and boss.applying_feedback_hit:
		var attacker := boss
		attacker.holding_fatal_feedback = true
		await get_tree().create_timer(FATAL_HIT_FEEDBACK_TIME, false, true).timeout
		if is_instance_valid(attacker) and boss == attacker and player.is_dead:
			_open_death_menu()
		return
	_open_death_menu()

func _open_death_menu() -> void:
	_set_boss_music(false)
	_clear_shake()
	if is_instance_valid(boss):
		boss.cancel_actions()
		if boss.phase not in [BOSS_ACTOR.Phase.ASSEMBLE, BOSS_ACTOR.Phase.OFFLINE]:
			boss._switch(BOSS_ACTOR.Phase.RECOVER, 0.0)
		boss.queue_redraw()
	robot_visual.show()
	if retry_at_boss_gate:
		_update_hp_bar()
		game_menus.show_death(true, "重试将回到出口房门外")
	else:
		super._on_player_died()

func _process(delta: float) -> void:
	super._process(delta)
	if abdomen_music.stream_paused and not is_level_complete:
		abdomen_music.stream_paused = false
	if not entry_ready or get_tree().paused or not is_instance_valid(boss):
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

func _on_clearance_shake(offsets: PackedVector2Array) -> void:
	if offsets.is_empty():
		_clear_shake()
	else:
		_start_shake(Vector2.ZERO, 0.0, offsets.size() / SHAKE_SAMPLE_RATE, offsets)

func _start_shake(direction: Vector2, amount: float, duration: float, offsets := PackedVector2Array()) -> void:
	shake_axis = direction
	shake_left = duration
	shake_duration = duration
	shake_strength = amount
	shake_offsets = offsets
	_render_shake()

func _advance_shake(delta: float) -> void:
	if shake_left <= 0.0:
		return
	shake_left = maxf(0.0, shake_left - delta)
	if shake_left <= 0.00001:
		_clear_shake()
		return
	_render_shake()

func _render_shake() -> void:
	if not shake_offsets.is_empty():
		var index := floori((shake_duration - shake_left) * SHAKE_SAMPLE_RATE + 0.00001)
		camera.offset = shake_base + shake_offsets[mini(index, shake_offsets.size() - 1)]
		return
	var remaining := shake_left / shake_duration
	camera.offset = shake_base + shake_axis * shake_strength * remaining * remaining * cos((1.0 - remaining) * TAU * 1.7)

func _clear_shake() -> void:
	shake_left = 0.0
	shake_offsets = PackedVector2Array()
	if is_instance_valid(camera):
		camera.offset = shake_base

func _exit_tree() -> void:
	_clear_shake()

func _clear_wrecks() -> void:
	for wreck in wrecks:
		wreck.queue_free()
	for cable in recovery_lines:
		cable.queue_free()
	wrecks.clear()
	recovery_lines.clear()
	wreck_starts.clear()

func _retry_level() -> void:
	_set_boss_music(false)
	_clear_shake()
	if is_instance_valid(boss):
		boss.cancel_actions()
		remove_child(boss)
		boss.queue_free()
		boss = null
	_clear_wrecks()
	boss_resume.clear()
	boss_beat = false
	for silk in get_tree().get_nodes_in_group("b_cleaner_webs"):
		if is_ancestor_of(silk):
			silk.set_physics_process(false)
			silk.queue_free()
	super._retry_level()
	retry_at_boss_gate = false
	_set_boss_gate_open(true)
	robot_visual.show()
	for cleaner in exit_cleaners:
		cleaner.show()


func _retry_spawn() -> Vector2:
	return boss_retry_point.global_position if retry_at_boss_gate else super._retry_spawn()


func _retry_enemy_state(enemy: Node) -> Dictionary:
	return enemy.get_combat_state() if retry_at_boss_gate and enemy.health <= 0 else super._retry_enemy_state(enemy)
