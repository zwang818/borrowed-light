extends Node2D
## 腹腔关卡运行场景：组装地图、玩家、敌人、交互对象
## First-level C flow: blueprint → workbench → combat → terminal → exit
## C 模块集成：引导 HUD、终端门禁、房间重试、场景切换、空间记忆

signal interaction_requested(content_id: StringName, payload: Dictionary, token: int)
signal interaction_finished(token: int, completed: bool)
## D may connect this signal and complete/cancel via finish_interaction(token, bool).
const POINT_SCRIPT := preload("res://scenes/gameplay/interaction_point.gd")
const SHEET_SCRIPT := preload("res://scenes/gameplay/interaction_sheet.gd")
const FACILITY_SCRIPT := preload("res://scenes/gameplay/facility_visual.gd")
const DUCT_VISUAL := preload("res://scenes/gameplay/duct_visual.gd")
const HEALTH_SCRIPT := preload("res://scenes/gameplay/health_hearts.gd")
const TERMINAL_REQUEST := &"terminal_access"
const TERMINAL_CODE := "0417"
const TERMINAL_CLUES := {&"pulse_blueprint": "04", &"workshop_origin": "17"}

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CLEANER_SCENE := preload("res://scenes/enemies/cleaner/cleaner.tscn")
const SENTRY_SCENE := preload("res://scenes/enemies/sentry/sentry.tscn")
const PAUSE_INPUT_SCRIPT := preload("res://scenes/gameplay/pause_input.gd")
const GAME_MENUS_SCRIPT := preload("res://scenes/gameplay/game_menus.gd")
const UI_THEME := preload("res://scenes/gameplay/gameplay_ui_theme.tres")
const PULSE_BLUEPRINT_TEXTURE := preload("res://assets/sprites/ui/pulse_arm_blueprint.svg")

## ---------- 常量配置 ----------

const C := {
	"panel_bg": Color(0, 0, 0, 0.65),
	"panel_bg_light": Color(0, 0, 0, 0.5),
	"panel_yellow": Color(0.8, 0.6, 0.1, 0.8),
	"text_gold": Color(1, 0.95, 0.8, 1),
	"text_white": Color(1, 1, 1, 1),
	"text_green": Color(0.3, 1.0, 0.5, 1),
	"text_notify": Color(1, 0.85, 0.4, 1),
	"text_arrow": Color(1, 0.8, 0.2, 1),
	"text_dist": Color(0.9, 0.9, 0.9, 0.9),
	"hp_full": Color(0.9, 0.2, 0.2, 1),
	"hp_empty": Color(0.3, 0.1, 0.1, 1),
	"interaction_range": 48.0,
	"weapon_prompt_range": 120.0,
	"welcome_duration": 4.0,
	"notify_default": 2.0,
	"level_complete_wait": 3.0,
	"fade_duration": 0.5,

	"t_weapon_get": "脉冲模块已接入",
	"t_terminal_ok": "小一：门开了。",
	"t_all_enemies_down": "神明：警报停了……那台终端应该能响应你了。",
	"t_retry": "房间已重试",
	"t_level_complete": "样板完成",
	"t_weapon_prompt": "脉冲枪 - 靠近拾取",
	"t_terminal_prompt": "[E] 操作终端",
}

@onready var map := $AbdomenGraybox as Node2D
@onready var bullets_parent := $Bullets as Node2D
@onready var interactables_parent := $Interactables as Node2D
@onready var camera := $Camera2D as Camera2D

var robot_visual: Node2D
var player: CharacterBody2D
var enemies: Array[Node] = []
var interactables: Array[Node] = []
var is_level_complete := false
var nearest_interactable: Node = null

enum Objective { GET_WEAPON, KILL_ENEMIES, ACTIVATE_TERMINAL, REACH_EXIT, CRAFT_ARM }
var current_objective: int = Objective.GET_WEAPON
var total_enemies: int = 0
var dead_enemies: int = 0
var terminal_activated := false
var weapon_pickup: Node = null
var terminal: Node = null
var final_exit: Node = null
var explored_positions: Array[Vector2] = []
var last_memory_record_time: float = 0.0
@export var achievement_save_path := "user://achievements.cfg"
var game_menus
var enemy_baselines: Dictionary = {}
var door_tweens: Array[Tween] = []
var notification_revision := 0
var blueprint_known := false
var pulse_learned := false
var workshop_seen := false
var terminal_clues: Dictionary = {}
var pending_interaction: StringName = &""
var interaction_token := 0
var interaction_sheet
var terminal_gate: StaticBody2D
var health_display: Control
var interaction_points: Dictionary = {}
var ducts: Dictionary = {}
var unlocked_ducts: Dictionary = {}
var achievement_webs: Array[Node] = []
var room_damage_taken := false
var achievement_last_health := 0

## HUD 节点
var hud_canvas: CanvasLayer
var interact_label: Label
var interact_bg: Panel
var notify_label: Label
var notify_bg: Panel
var blueprint_hint: TextureRect
var blueprint_hint_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var pause_input := Node.new()
	pause_input.name = "PauseInput"
	pause_input.set_script(PAUSE_INPUT_SCRIPT)
	pause_input.set("target", self)
	pause_input.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_input)
	print("[C-MODULE] abdomen_level.gd 已加载 - v4")
	# Main-level rack: 2 x 2 tiles (32 px each), preserving its display center.
	var rack = map.get_node("Walls/GunRackBase")
	var rack_center: Vector2 = rack.position + rack.size * 0.5
	rack.size = Vector2(64, 64)
	rack.position = rack_center - rack.size * 0.5
	_spawn_from_markers()
	_configure_player()
	_configure_enemies()
	_configure_camera()
	_setup_hud()
	game_menus = GAME_MENUS_SCRIPT.new()
	game_menus.name = "GameMenus"
	game_menus.achievement_save_path = achievement_save_path
	add_child(game_menus)
	game_menus.retry_requested.connect(_retry_level)
	game_menus.title_requested.connect(_return_to_title)
	interaction_sheet = SHEET_SCRIPT.new()
	add_child(interaction_sheet)
	interaction_sheet.finished.connect(finish_interaction)
	interaction_sheet.destination_selected.connect(_travel_duct)
	interaction_sheet.code_submitted.connect(_submit_terminal_code)
	_setup_story_points()
	_setup_terminal_gate()
	_setup_ducts()
	_setup_achievement_events()

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if is_instance_valid(robot_visual):
		robot_visual.global_rotation = 0
		robot_visual.global_position = player.global_position
	_update_interaction()
	_update_hud()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if player != null and not player.is_dead:
		camera.global_position = player.global_position
		last_memory_record_time += delta
		if last_memory_record_time >= 0.5:
			last_memory_record_time = 0.0
			_record_exploration(player.global_position)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not get_tree().paused and not is_level_complete:
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			_try_interact()

## ---------- 空间记忆 ----------

func _record_exploration(pos: Vector2) -> void:
	var grid_pos := Vector2i(int(pos.x / 64), int(pos.y / 64))
	var already: bool = false
	for p in explored_positions:
		if Vector2i(int(p.x / 64), int(p.y / 64)) == grid_pos:
			already = true
			break
	if not already:
		explored_positions.append(pos)

func get_exploration_ratio() -> float:
	var map_bounds: Rect2 = map.get_meta("map_bounds", Rect2())
	if map_bounds.size.x <= 0 or map_bounds.size.y <= 0:
		return 0.0
	var total_cells: float = (map_bounds.size.x / 64.0) * (map_bounds.size.y / 64.0)
	return minf(explored_positions.size() / total_cells, 1.0)

## ---------- Gameplay HUD ----------

func _setup_hud() -> void:
	hud_canvas = CanvasLayer.new()
	add_child(hud_canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI_THEME
	hud_canvas.add_child(root)
	health_display = HEALTH_SCRIPT.new()
	health_display.name = "HealthDisplay"
	health_display.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_display.offset_left = 16
	health_display.offset_top = -98
	health_display.offset_right = 268
	health_display.offset_bottom = -16
	root.add_child(health_display)
	player.health_changed.connect(func(value: int, maximum: int): health_display.set_health(float(value), float(maximum)))
	_update_hp_bar()
	interact_bg = Panel.new()
	interact_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interact_bg.offset_left = -330
	interact_bg.offset_right = 330
	interact_bg.offset_top = -96
	interact_bg.offset_bottom = -34
	interact_bg.add_theme_stylebox_override("panel", _make_hud_panel_style(Color("78a7aa"), Color("101d25", 0.96)))
	root.add_child(interact_bg)
	interact_label = Label.new()
	interact_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interact_label.offset_left = 18
	interact_label.offset_right = -18
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interact_label.add_theme_color_override("font_color", Color("d8e7e2"))
	interact_label.add_theme_color_override("font_outline_color", Color("071117", 0.95))
	interact_label.add_theme_constant_override("outline_size", 1)
	interact_label.add_theme_color_override("font_shadow_color", Color("02070a", 0.9))
	interact_label.add_theme_constant_override("shadow_offset_x", 1)
	interact_label.add_theme_constant_override("shadow_offset_y", 2)
	interact_label.add_theme_font_size_override("font_size", 19)
	interact_bg.add_child(interact_label)
	_add_hud_panel_reflection(interact_bg, Color("101d25", 0.96))
	notify_bg = Panel.new()
	notify_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notify_bg.offset_left = -390
	notify_bg.offset_right = 390
	notify_bg.offset_top = 72
	notify_bg.offset_bottom = 134
	notify_bg.add_theme_stylebox_override("panel", _make_hud_panel_style(Color("c59a55"), Color("100f0d", 0.94)))
	root.add_child(notify_bg)
	notify_label = Label.new()
	notify_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notify_label.offset_left = 24
	notify_label.offset_right = -24
	notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notify_label.add_theme_color_override("font_color", Color("f0d7a0"))
	notify_label.add_theme_color_override("font_outline_color", Color("070909", 0.95))
	notify_label.add_theme_constant_override("outline_size", 1)
	notify_label.add_theme_color_override("font_shadow_color", Color("000000", 0.95))
	notify_label.add_theme_constant_override("shadow_offset_x", 1)
	notify_label.add_theme_constant_override("shadow_offset_y", 2)
	notify_label.add_theme_font_size_override("font_size", 23)
	notify_bg.add_child(notify_label)
	_add_hud_panel_reflection(notify_bg, Color("100f0d", 0.94))
	blueprint_hint = TextureRect.new()
	blueprint_hint.name = "PulseArmBlueprintHint"
	blueprint_hint.texture = PULSE_BLUEPRINT_TEXTURE
	blueprint_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blueprint_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	blueprint_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	blueprint_hint.offset_left = 100
	blueprint_hint.offset_right = 500
	blueprint_hint.offset_top = -150
	blueprint_hint.offset_bottom = 100
	blueprint_hint.modulate = Color(1, 1, 1, 0.78)
	blueprint_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(blueprint_hint)
	blueprint_hint.hide()
	interact_bg.hide()
	notify_bg.hide()
	for control in root.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_hud_panel_style(accent: Color, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = fill.lerp(accent, 0.62).lightened(0.12)
	style.set_border_width_all(5)
	style.border_width_top = 7
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 11
	style.shadow_offset = Vector2(0, 5)
	return style

func _add_hud_panel_reflection(panel: Panel, fill: Color) -> void:
	var bright_metal := fill.lerp(Color("e7e7d7"), 0.72)
	var top_glint_color := bright_metal
	top_glint_color.a = 0.52
	var side_glint_color := bright_metal
	side_glint_color.a = 0.24
	var top_glint := ColorRect.new()
	top_glint.anchor_left = 0.0
	top_glint.anchor_right = 1.0
	top_glint.offset_left = 8
	top_glint.offset_right = -12
	top_glint.offset_top = 3
	top_glint.offset_bottom = 5
	top_glint.color = top_glint_color
	top_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_glint)
	var left_glint := ColorRect.new()
	left_glint.anchor_bottom = 1.0
	left_glint.offset_left = 4
	left_glint.offset_right = 6
	left_glint.offset_top = 8
	left_glint.offset_bottom = -12
	left_glint.color = side_glint_color
	left_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(left_glint)
	var lower_shadow := ColorRect.new()
	lower_shadow.anchor_left = 0.0
	lower_shadow.anchor_right = 1.0
	lower_shadow.anchor_top = 1.0
	lower_shadow.anchor_bottom = 1.0
	lower_shadow.offset_left = 9
	lower_shadow.offset_right = -13
	lower_shadow.offset_top = -5
	lower_shadow.offset_bottom = -3
	lower_shadow.color = fill.darkened(0.35)
	lower_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lower_shadow)

## ---------- HUD 更新 ----------

func _update_hud() -> void:
	_update_hp_bar()
	_update_world_prompts()


func _update_hp_bar() -> void:
	health_display.set_health(float(player.health), float(player.max_health))

func _update_world_prompts() -> void:
	# One contextual screen prompt. No duplicate labels above world objects.
	terminal.get_node("FacilityVisual").set_status(terminal_gate.get_meta("is_open", false), nearest_interactable == terminal, terminal_activated)
	var terminal_marker = terminal.get_node("InteractionMarker")
	terminal_marker.focused = nearest_interactable == terminal and not terminal_activated
	terminal_marker.set_status(true, terminal_gate.get_meta("is_open", false) and not terminal_activated, terminal_activated)
	for obj in interactables:
		if not is_instance_valid(obj):
			continue
		var label := obj.get_node_or_null("PromptLabel")
		if label != null:
			label.hide()
		if obj.get_script() == POINT_SCRIPT:
			obj.focused = obj == nearest_interactable
			var available: bool = obj.interaction_id != &"pulse_workbench" or (blueprint_known and not pulse_learned)
			var completed: bool = (obj.interaction_id == &"pulse_blueprint" and blueprint_known) or (obj.interaction_id == &"pulse_workbench" and pulse_learned) or (obj.interaction_id == &"workshop_origin" and workshop_seen)
			if ducts.has(obj.interaction_id):
				completed = unlocked_ducts.has(obj.interaction_id)
				obj.visible = not completed
			obj.set_status(player.global_position.distance_to(obj.global_position) < 120, available, completed)
	if not is_instance_valid(nearest_interactable) and not terminal_gate.get_meta("is_open", false) and player.global_position.distance_to(terminal_gate.global_position) < 120:
		interact_bg.show()
		interact_label.show()
		interact_label.text = "终端区域入口锁定 · 剩余 %d 台清扫者" % _remaining_cleaners()
		return
	interact_bg.visible = is_instance_valid(nearest_interactable)
	interact_label.visible = interact_bg.visible
	if not interact_bg.visible:
		return
	if nearest_interactable.has_meta("is_terminal"):
		interact_label.text = _terminal_prompt()
	else:
		interact_label.text = _point_prompt(nearest_interactable.interaction_id)

## ---------- 通知系统 ----------

func _show_notification(text: String, duration: float = C.notify_default) -> void:
	notification_revision += 1
	var revision := notification_revision
	notify_label.text = text
	notify_label.visible = true
	notify_bg.visible = true
	await get_tree().create_timer(duration, false).timeout
	if revision != notification_revision:
		return
	if is_instance_valid(notify_label):
		notify_label.visible = false
	if is_instance_valid(notify_bg):
		notify_bg.visible = false

func _show_blueprint_hint() -> void:
	if not is_instance_valid(blueprint_hint):
		return
	if blueprint_hint_tween and blueprint_hint_tween.is_running():
		blueprint_hint_tween.kill()
	blueprint_hint.modulate.a = 0.78
	blueprint_hint.show()
	blueprint_hint_tween = create_tween()
	blueprint_hint_tween.tween_interval(1.5)
	blueprint_hint_tween.tween_property(blueprint_hint, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	blueprint_hint_tween.tween_callback(blueprint_hint.hide)

## ---------- 标记生成系统 ----------

func _spawn_from_markers() -> void:
	var markers := map.get_node_or_null("Markers")
	if markers == null:
		push_error("AbdomenLevel: 找不到 Markers 节点")
		return
	for marker in markers.get_children():
		if marker is Marker2D:
			_match_marker(marker)

func _match_marker(marker: Marker2D) -> void:
	var otype: String = marker.object_type
	var pos: Vector2 = marker.global_position
	match otype:
		"spawn":
			if player == null:
				player = PLAYER_SCENE.instantiate()
				player.set_script(preload("res://scenes/player/xiaoyi_field_player.gd"))
				player.global_position = pos
				player.pulse_gun_equipped = false
				add_child(player)
		"weapon":
			if marker.content_id == "pulse_gun":
				marker.global_position = _weapon_display_position()
				marker.hide()
				weapon_pickup = _add_weapon_pickup(marker.global_position, marker.content_id)
		"cleaner":
			var cleaner := CLEANER_SCENE.instantiate()
			cleaner.set_script(preload("res://tests/manual/b_combat/web_cleaner.gd"))
			cleaner.global_position = pos
			cleaner.entity_id = StringName(marker.object_id)
			cleaner.name = marker.object_id
			add_child(cleaner)
			cleaner.get_node("Facing/Body").hide()
			var cleaner_model := preload("res://tests/manual/b_combat/web_cleaner_visual.gd").new()
			cleaner_model.name = "CleanerModel"
			cleaner_model.match_hurtbox = true
			cleaner.add_child(cleaner_model)
			marker.hide()
			enemies.append(cleaner)
			total_enemies += 1
		"sentry":
			var sentry := SENTRY_SCENE.instantiate()
			sentry.global_position = pos
			sentry.entity_id = StringName(marker.object_id)
			sentry.name = marker.object_id
			add_child(sentry)
			enemies.append(sentry)
			total_enemies += 1
		"terminal":
			terminal = _add_terminal(pos, marker.object_id, marker.linked_ids)
		"door":
			_add_door(pos, marker.object_id)
		"exit":
			var is_final: bool = marker.target_room_id == "p1_landing_01"
			var exit_node := _add_exit(pos, marker.object_id, marker.target_room_id, is_final)
			if is_final:
				final_exit = exit_node

## ---------- 运行时对象工厂 ----------

func _weapon_display_position() -> Vector2:
	var rack = map.get_node("Walls/GunRackBase")
	return rack.to_global(rack.size * 0.5)

func _add_weapon_pickup(_pos: Vector2, _weapon_id: String) -> Node:
	var rack = map.get_node("Walls/GunRackBase")
	return _add_story_point(&"pulse_blueprint", rack.to_global(Vector2(rack.size.x * 0.5, rack.size.y + 4)))

func _add_terminal(pos: Vector2, term_id: String, linked: Array) -> Node:
	var area := Area2D.new()
	area.name = "Terminal_" + term_id
	area.position = pos
	area.collision_layer = 64
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	area.add_child(shape)
	var visual := FACILITY_SCRIPT.new()
	visual.name = "FacilityVisual"
	visual.kind = "terminal"
	area.add_child(visual)
	# Presentation only: the Area2D remains the sole terminal interaction target.
	var marker := POINT_SCRIPT.new()
	marker.name = "InteractionMarker"
	marker.position = Vector2(0, 26)
	area.add_child(marker)
	area.set_meta("terminal_id", term_id)
	area.set_meta("linked_ids", linked)
	area.set_meta("is_terminal", true)
	area.set_meta("activated", false)
	interactables_parent.add_child(area)
	interactables.append(area)
	return area

func _add_door(pos: Vector2, door_id: String) -> void:
	var body := StaticBody2D.new()
	body.name = "Door_" + door_id
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 32)
	shape.shape = rect
	body.add_child(shape)
	var visual := FACILITY_SCRIPT.new()
	visual.name = "FacilityVisual"
	visual.dimensions = rect.size
	body.add_child(visual)
	body.set_meta("door_id", door_id)
	body.set_meta("is_open", false)
	body.set_meta("is_door", true)
	interactables_parent.add_child(body)
	interactables.append(body)

func _add_exit(pos: Vector2, exit_id: String, target_room: String, is_final: bool = false) -> Node:
	var area := Area2D.new()
	area.name = "Exit_" + exit_id
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 32)
	shape.shape = rect
	area.add_child(shape)
	area.set_meta("exit_id", exit_id)
	area.set_meta("target_room", target_room)
	area.set_meta("is_exit", true)
	area.set_meta("is_final_exit", is_final)
	area.body_entered.connect(func(body): _on_exit_entered(body, exit_id))
	interactables_parent.add_child(area)
	return area

## ---------- 配置 ----------

func _configure_player() -> void:
	if player == null:
		push_error("AbdomenLevel: 未生成玩家")
		return
	var map_bounds: Rect2 = map.get_meta("map_bounds", Rect2(128, 32, 1120, 2688))
	player.get_node("Facing/Body").hide()
	player.get_node("Facing/DirectionIndicator").hide()
	robot_visual = preload("res://tests/manual/b_combat/xiaoyi_graybox_visual.gd").new()
	robot_visual.name = "XiaoyiCombatVisual"
	robot_visual.display_height = 60.0
	robot_visual.enhanced_gait = true
	robot_visual.face_firing_beam = true
	player.get_node("Facing").add_child(robot_visual)
	var hurtbox := preload("res://tests/manual/b_combat/player_model_hurtbox.gd").new()
	hurtbox.name = "PlayerModelHurtbox"
	player.add_child(hurtbox)
	player.pulse_gun.configure_space(map_bounds, _enemy_visible_query)
	player.died.connect(_on_player_died)

func _configure_enemies() -> void:
	for enemy in enemies:
		if enemy.has_method("configure"):
			if enemy is StaticBody2D:
				enemy.configure(player, _enemy_visible_query, bullets_parent)
			else:
				enemy.configure(player, _cleaner_visible_query, _in_protocol_query)
		enemy.died.connect(_on_enemy_died)
		enemy_baselines[enemy.entity_id] = enemy.get_combat_state().duplicate(true)

func _configure_camera() -> void:
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	var bounds: Rect2 = map.get_meta("map_bounds", Rect2())
	camera.limit_left = int(bounds.position.x) - 64
	camera.limit_top = int(bounds.position.y) - 64
	camera.limit_right = int(bounds.end.x) + 64
	camera.limit_bottom = int(bounds.end.y) + 64
	camera.make_current()

## ---------- 交互系统 ----------

func _update_interaction() -> void:
	nearest_interactable = null
	if player == null or player.is_dead or get_tree().paused:
		return
	var nearest_dist: float = C.interaction_range
	for obj in interactables:
		if not is_instance_valid(obj):
			continue
		if not obj.has_meta("is_terminal") and obj.get_script() != POINT_SCRIPT:
			continue
		if obj.has_meta("is_terminal") and not terminal_gate.get_meta("is_open", false):
			continue
		var dist: float = player.global_position.distance_to(obj.global_position)
		if dist >= nearest_dist:
			continue
		var query := PhysicsRayQueryParameters2D.create(player.global_position, obj.global_position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			continue
		nearest_interactable = obj
		nearest_dist = dist

func _remaining_cleaners() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_in_group("cleaners"):
			if enemy.get_combat_state().alive:
				count += 1
	return count

func _terminal_prompt() -> String:
	var remaining := _remaining_cleaners()
	if terminal_activated:
		return "终端已激活 · 出口门已开启"
	return "终端锁定 · 剩余 %d 台清扫者" % remaining if remaining > 0 else "[E] 接入终端"

func _try_interact() -> void:
	if player.is_dead or get_tree().paused:
		return
	_update_interaction()
	if nearest_interactable == null:
		return
	if nearest_interactable.get_script() == POINT_SCRIPT:
		if ducts.has(nearest_interactable.interaction_id):
			_request_duct(nearest_interactable.interaction_id)
		else:
			_request_story(nearest_interactable.interaction_id)
		return
	if nearest_interactable.has_meta("is_terminal") and not nearest_interactable.get_meta("activated"):
		if _remaining_cleaners() > 0:
			_show_notification(_terminal_prompt(), 1.5)
			return
		_request_terminal_code()

func _can_use_terminal() -> bool:
	if player.is_dead or terminal_activated or _remaining_cleaners() > 0 or not terminal_gate.get_meta("is_open", false):
		return false
	if player.global_position.distance_to(terminal.global_position) >= C.interaction_range:
		return false
	var query := PhysicsRayQueryParameters2D.create(player.global_position, terminal.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _request_terminal_code() -> void:
	if not pending_interaction.is_empty() or not _can_use_terminal():
		return
	interaction_token += 1
	pending_interaction = TERMINAL_REQUEST
	get_tree().paused = true
	# Functional input belongs to C; D's story presenter never grants authorization.
	interaction_sheet.present(interaction_token, {
		"title": "出口维护终端", "category": "访问验证", "badge": "等待口令",
		"summary": "请输入四位维护口令。\n原始口令分段保存在图纸与制造室记录中。",
		"confirm": "验证口令", "input_mode": "terminal_code"})

func _submit_terminal_code(token: int, code: String) -> void:
	if token != interaction_token or pending_interaction != TERMINAL_REQUEST:
		return
	if not _can_use_terminal():
		finish_interaction(token, false)
		return
	if code.length() != 4 or not code.is_valid_int() or code != TERMINAL_CODE:
		interaction_sheet.show_code_error(token)
		return
	terminal.set_meta("activated", true)
	terminal_activated = true
	for door_id in terminal.get_meta("linked_ids", []):
		_open_door(door_id)
	for child in terminal.get_children():
		if child is Polygon2D:
			child.color = Color(0.5, 0.5, 0.5, 0.5)
	_play_terminal_sound()
	game_menus.unlock_achievement("first_terminal")
	_show_notification(C.t_terminal_ok, C.notify_default)
	current_objective = Objective.REACH_EXIT
	finish_interaction(token, true)

func _play_terminal_sound() -> void:
	# Optional existing sound is absent in this checkout; do not add a new effect.
	if not ResourceLoader.exists("res://assets/audio/repair.wav"):
		return
	var audio := AudioStreamPlayer.new()
	var stream := load("res://assets/audio/repair.wav")
	if stream != null:
		audio.stream = stream
		audio.bus = "SFX"
		add_child(audio)
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

func _open_door(door_id: String) -> void:
	for obj in interactables:
		if not is_instance_valid(obj):
			continue
		if obj.has_meta("door_id") and obj.get_meta("door_id") == door_id:
			obj.set_meta("is_open", true)
			obj.collision_layer = 0
			_door_flash_animation(obj)

func _door_flash_animation(door: Node) -> void:
	var visual = door.get_node("FacilityVisual")
	visual.set_status(true)
	var tween := create_tween()
	door_tweens.append(tween)
	tween.tween_property(visual, "open_amount", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## ---------- 事件回调 ----------

func _on_exit_entered(body: Node, exit_id: String) -> void:
	if body.has_method("get_damage_receiver"):
		body = body.get_damage_receiver()
	if body != player or player.is_dead or get_tree().paused or is_level_complete:
		return
	for obj in interactables_parent.get_children():
		if obj.has_meta("exit_id") and obj.get_meta("exit_id") == exit_id:
			if obj.get_meta("is_final_exit", false) and terminal_activated:
				is_level_complete = true
				game_menus.unlock_achievement("first_exit")
				_show_level_complete()
			break

func _on_player_died() -> void:
	_update_hp_bar()
	game_menus.show_death()

func _on_enemy_died(_entity_id: StringName) -> void:
	dead_enemies += 1
	if _remaining_cleaners() == 0:
		_open_door("p1_terminal_access_gate")
	var remaining: int = total_enemies - dead_enemies
	if remaining <= 0:
		game_menus.unlock_achievement("first_clear")
		if not room_damage_taken:
			game_menus.unlock_achievement("clean_clear")
	if remaining <= 0 and current_objective == Objective.KILL_ENEMIES:
		current_objective = Objective.ACTIVATE_TERMINAL
		_show_notification(C.t_all_enemies_down, 2.5)

## ---------- 查询函数 ----------

func _enemy_visible_query(enemy: Node) -> bool:
	var bounds: Rect2 = map.get_meta("map_bounds", Rect2())
	return bounds.has_point(enemy.global_position)

func _cleaner_visible_query(enemy: Node) -> bool:
	return enemy.is_on_screen()

func _in_protocol_query() -> bool:
	return player.has_protocol

## ---------- 关卡完成 / 重试 ----------

func _show_level_complete() -> void:
	await _fade_to_black()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.8)
	panel.position = Vector2(366, 264)
	panel.size = Vector2(420, 120)
	canvas.add_child(panel)
	var label := Label.new()
	label.text = C.t_level_complete
	label.position = Vector2(366, 264)
	label.size = Vector2(420, 120)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
	canvas.add_child(label)
	await get_tree().create_timer(C.level_complete_wait).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _fade_to_black() -> ColorRect:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.anchors_preset = Control.PRESET_FULL_RECT
	canvas.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 1.0, C.fade_duration)
	await tween.finished
	return rect

func _retry_level() -> void:
	var retry_after_death: bool = player.is_dead
	if not pending_interaction.is_empty():
		finish_interaction(interaction_token, false)
	var environment := map.get_node_or_null("Environment")
	if environment != null and environment.has_method("reset_breakable_webs"):
		environment.reset_breakable_webs()
	for tween in door_tweens:
		tween.kill()
	door_tweens.clear()
	for bullet in bullets_parent.get_children():
		bullet.queue_free()
	var spawn_pos: Vector2 = _find_spawn_position()

	player.restore_player(spawn_pos, player.max_health, ["pulse_gun"] if pulse_learned else [])
	current_objective = Objective.KILL_ENEMIES if pulse_learned else (Objective.CRAFT_ARM if blueprint_known else Objective.GET_WEAPON)
	terminal_activated = false
	if is_instance_valid(terminal):
		terminal.set_meta("activated", false)
		for child in terminal.get_children():
			if child is Polygon2D:
				child.color = Color(0.2, 0.8, 0.4, 0.7)
	for obj in interactables:
		if is_instance_valid(obj) and obj.has_meta("is_door"):
			obj.set_meta("is_open", false)
			obj.collision_layer = 1
			var visual = obj.get_node("FacilityVisual")
			visual.set_status(false)
			visual.open_amount = 0.0
	dead_enemies = 0
	_show_notification(C.t_retry, 2.0)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("get_combat_state") and enemy.has_method("restore_combat_state"):
			var snap: Dictionary = enemy_baselines[enemy.entity_id].duplicate(true)
			enemy.restore_combat_state(snap)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	nearest_interactable = null
	game_menus.close_and_resume()
	_update_hud()
	room_damage_taken = false
	achievement_last_health = player.health
	_refresh_web_achievement()
	if retry_after_death:
		game_menus.unlock_achievement("first_retry")

func _find_spawn_position() -> Vector2:
	var markers := map.get_node_or_null("Markers")
	if markers == null:
		return Vector2.ZERO
	for marker in markers.get_children():
		if marker is Marker2D and marker.object_type == "spawn":
			return marker.global_position
	return Vector2.ZERO

func _toggle_pause() -> void:
	if not pending_interaction.is_empty():
		finish_interaction(interaction_token, false)
		return
	if not is_level_complete and is_instance_valid(game_menus):
		game_menus.toggle_pause()

## ---------- C interaction contract for D ----------

func _add_story_point(id: StringName, pos: Vector2) -> Node2D:
	var point := POINT_SCRIPT.new()
	point.name = String(id)
	point.interaction_id = id
	point.position = pos
	interactables_parent.add_child(point)
	interactables.append(point)
	interaction_points[id] = point
	return point

func _setup_story_points() -> void:
	# Attach to existing furniture without modifying A's map or its collision.
	var base = map.get_node("Walls/AssemblyBase")
	_add_story_point(&"pulse_workbench", base.to_global(Vector2(base.size.x * 0.5, base.size.y + 4)))
	var bench = map.get_node("Walls/WorkshopBench")
	_add_story_point(&"workshop_origin", bench.to_global(Vector2(bench.size.x * 0.5, bench.size.y + 4)))

func _point_prompt(id: StringName) -> String:
	if ducts.has(id):
		return "[E] 打开管道 · " + ducts[id].title if unlocked_ducts.has(id) else "[E] 解锁管道 · " + ducts[id].title
	match id:
		&"pulse_blueprint":
			return "[E] 查看图纸" if not blueprint_known else "[E] 回听通讯"
		&"pulse_workbench":
			if pulse_learned:
				return "脉冲机械臂已制造完成"
			return "[E] 接入制造台" if blueprint_known else "[E] 查看制造台"
		&"workshop_origin":
			return "[E] 查看操作台记录" if not workshop_seen else "[E] 重读操作台记录"
	return ""

func get_interaction_state() -> Dictionary:
	return {"blueprint_known": blueprint_known, "pulse_learned": pulse_learned,
		"workshop_seen": workshop_seen, "terminal_activated": terminal_activated,
		"terminal_clues": terminal_clues.duplicate()}

func _request_story(id: StringName) -> void:
	if not pending_interaction.is_empty() or not interaction_points.has(id):
		return
	if id == &"pulse_workbench" and (not blueprint_known or pulse_learned):
		_show_notification("脉冲模块已经装配完成。" if pulse_learned else "这台设备似乎还在等待一份图纸。")
		if not blueprint_known and not pulse_learned:
			_show_blueprint_hint()
		return
	var payloads := {
		&"pulse_blueprint": {"title": "图纸台的通讯", "summary": "", "confirm": "结束通话", "category": "通讯", "pulse_character_preview": true, "dialogue": [
			{"speaker": "小一", "text": "这上面画的……是我的手臂？"},
			{"speaker": "神明", "text": "是我为你预留的战斗模块。只是，还没来得及替你装上。"},
			{"speaker": "神明", "text": "你醒来时，左手边有一台制造设备。带着这份图纸回去，它能帮你完成装配。"},
			{"speaker": "小一", "text": "我记得那台机器。我去试试。"},
			{"speaker": "小一", "text": "图纸页脚还有一行字：维护口令前段，04。"},
			{"speaker": "神明", "text": "我把它拆开留在了不同的记录里。那些旧设备，仍然认得这个口令。"}]},
		&"pulse_workbench": {"title": "接入制造台", "summary": "", "confirm": "完成装配", "category": "通讯", "dialogue": [
			{"speaker": "小一", "text": "图纸和接口对上了。"},
			{"speaker": "神明", "text": "把模块接入左臂。它会先蓄力，再释放一道脉冲。"},
			{"speaker": "神明", "text": "试着按下鼠标左键。前面有维护单元，小心些。"}]},
		&"workshop_origin": {"title": "操作台的记录", "summary": "", "confirm": "结束通话", "category": "通讯", "dialogue": [
			{"speaker": "小一", "text": "这里的接口，和我身上的一样。"},
			{"speaker": "神明", "text": "这里……就是我制造你的地方。"},
			{"speaker": "小一", "text": "记录末尾写着：维护口令后段，17。原来，这些记录也是留给我的。"}]},
	}
	pending_interaction = id
	interaction_token += 1
	var payload: Dictionary = payloads[id].duplicate(true)
	payload["state"] = get_interaction_state()
	payload["replay"] = (id == &"pulse_blueprint" and blueprint_known) or (id == &"workshop_origin" and workshop_seen)
	get_tree().paused = true
	# A connected presenter owns the whole display. No automatic success fallback.
	if interaction_requested.get_connections().is_empty():
		interaction_sheet.present(interaction_token, payload)
	else:
		interaction_requested.emit(id, payload, interaction_token)

func finish_interaction(token: int, completed: bool) -> void:
	if token != interaction_token or pending_interaction.is_empty():
		return
	var id := pending_interaction
	# A generic story-completed callback must never bypass the password check.
	if id == TERMINAL_REQUEST:
		completed = completed and terminal_activated
	pending_interaction = &""
	interaction_sheet.dismiss()
	if ducts.has(id):
		ducts[id].visual.set_open(false)
		if completed and not unlocked_ducts.has(id):
			unlocked_ducts[id] = true
			ducts[id].visual.set_unlocked(true)
			game_menus.set_achievement_progress("duct_network", unlocked_ducts.size(), ducts.size())
			if unlocked_ducts.size() == ducts.size():
				game_menus.unlock_achievement("duct_network")
			_show_notification("管道已解锁，可与其他已解锁管道联通")
	if completed:
		if TERMINAL_CLUES.has(id):
			terminal_clues[id] = TERMINAL_CLUES[id]
		match id:
			&"pulse_blueprint":
				blueprint_known = true
				if not pulse_learned:
					current_objective = Objective.CRAFT_ARM
			&"pulse_workbench":
				pulse_learned = true
				player.learn_pulse()
				game_menus.unlock_achievement("first_weapon")
				current_objective = Objective.ACTIVATE_TERMINAL if _remaining_cleaners() == 0 else Objective.KILL_ENEMIES
				_show_notification(C.t_weapon_get, 2.5)
			&"workshop_origin":
				workshop_seen = true
				game_menus.unlock_achievement("workshop_reader")
	# Finish this event before enabling the world again (prevents input leaking).
	interaction_finished.emit(token, completed)
	_resume_story.call_deferred()

func _resume_story() -> void:
	if pending_interaction.is_empty() and game_menus.page == game_menus.Page.CLOSED:
		get_tree().paused = false

func _setup_terminal_gate() -> void:
	# Local enclosure inside C's runtime: the terminal cannot be reached sideways.
	var origin: Vector2 = terminal.position
	for wall in [Rect2(-80, -72, 16, 128), Rect2(64, -72, 16, 128), Rect2(-64, -80, 128, 16)]:
		var body := StaticBody2D.new()
		body.position = origin + wall.get_center()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = wall.size
		shape.shape = rectangle
		body.add_child(shape)
		var visual := FACILITY_SCRIPT.new()
		visual.kind = "wall"
		visual.dimensions = wall.size
		body.add_child(visual)
		interactables_parent.add_child(body)
	_add_door(origin + Vector2(0, 48), "p1_terminal_access_gate")
	terminal_gate = interactables[-1]
	var gate_shape: CollisionShape2D = terminal_gate.get_child(0)
	gate_shape.shape.size = Vector2(144, 16)
	terminal_gate.get_node("FacilityVisual").dimensions = Vector2(144, 16)

func _return_to_title() -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		get_tree().paused = true
		push_error("无法返回标题：%s" % error_string(error))

## ---------- Discovered duct shortcuts ----------

func _setup_ducts() -> void:
	for config in [
		[&"duct_arrival", "ArrivalHatch", "出生区管道"],
		[&"duct_weapon", "WeaponHatch", "图纸区管道"],
		[&"duct_exit", "ExitHatch", "终端区管道"],
	]:
		var decal = map.get_node("Environment/FloorDecals/" + config[1])
		var point := POINT_SCRIPT.new()
		point.interaction_id = config[0]
		point.position = decal.to_global(decal.size * 0.5)
		point.name = String(config[0])
		interactables_parent.add_child(point)
		interactables.append(point)
		var visual := DUCT_VISUAL.new()
		visual.dimensions = decal.size
		visual.position = point.position
		interactables_parent.add_child(visual)
		decal.hide()
		ducts[config[0]] = {"title": config[2], "point": point, "visual": visual}

func _request_duct(id: StringName) -> void:
	if not pending_interaction.is_empty() or not ducts.has(id):
		return
	interaction_token += 1
	pending_interaction = id
	var payload := {"title": ducts[id].title, "category": "维护管道", "location": "腹腔维护通路", "replay": false,
		"summary": "解锁当前管道口后，可与其他已解锁的管道口互相传送。", "confirm": "解锁管道", "next_step": "每个管道口需要到达后单独解锁"}
	if unlocked_ducts.has(id):
		var choices: Array = []
		for target in ducts:
			if target != id and unlocked_ducts.has(target):
				choices.append({"id": target, "title": "前往 · " + ducts[target].title})
		payload["choices"] = choices
		payload["disable_confirm"] = true
		payload["confirm"] = "请选择目的地" if not choices.is_empty() else "暂无已联通的目的地"
		payload["summary"] = "选择已解锁的管道口前往。" if not choices.is_empty() else "当前管道已解锁。到达其他管道口并解锁后，即可联通。"
		payload["next_step"] = "Esc 关闭井盖并返回"
	payload["badge"] = "已解锁" if unlocked_ducts.has(id) else "未解锁"
	get_tree().paused = true
	if unlocked_ducts.has(id):
		ducts[id].visual.set_open(true)
	interaction_sheet.present(interaction_token, payload)

func _duct_landing(id: StringName) -> Variant:
	var center: Vector2 = ducts[id].point.global_position
	var exit_offset := Vector2(0, ducts[id].visual.dimensions.y * 0.5 + 12)
	for offset in [exit_offset, Vector2.ZERO, Vector2(36, 0), Vector2(-36, 0), Vector2(0, -36), Vector2(36, 36), Vector2(-36, 36)]:
		var candidate: Vector2 = center + offset
		var on_floor := false
		for floor_node in map.get_node("Floors").get_children():
			if Rect2(Vector2.ZERO, floor_node.size).has_point(floor_node.to_local(candidate)):
				on_floor = true
				break
		if not on_floor:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = player.get_node("CollisionShape2D").shape
		query.transform = Transform2D(0, candidate)
		query.collision_mask = 1 | 4
		query.exclude = [player.get_rid()]
		if player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return null

func _travel_duct(token: int, target: StringName) -> void:
	if token != interaction_token or player.is_dead or not ducts.has(pending_interaction):
		return
	if not ducts.has(target) or target == pending_interaction or not unlocked_ducts.has(pending_interaction) or not unlocked_ducts.has(target):
		return
	var destination = _duct_landing(target)
	if destination == null:
		_show_notification("目的地暂时被阻挡，请稍后再试")
		return
	player.pulse_gun.cancel()
	player.velocity = Vector2.ZERO
	player.global_position = destination
	game_menus.unlock_achievement("duct_traveler")
	camera.global_position = destination
	camera.reset_smoothing()
	finish_interaction(token, false)
	ducts[target].visual.set_open(true)
	_close_arrival_duct(target)
	_show_notification("已抵达 · " + ducts[target].title)

func _close_arrival_duct(id: StringName) -> void:
	await get_tree().create_timer(0.6, false).timeout
	if pending_interaction != id:
		ducts[id].visual.set_open(false)

## Achievement events consume actual game state; no rewards or enemy counters change.
func _setup_achievement_events() -> void:
	achievement_last_health = player.health
	player.health_changed.connect(_achievement_health_changed)
	for web in map.get_node("Environment").webs:
		# Only A's reachable placed targets, not the hundreds of background patches.
		if not web.background_region.has_area():
			achievement_webs.append(web)
			web.broken_once.connect(_on_achievement_web_broken)
	_refresh_web_achievement()
	game_menus.set_achievement_progress("duct_network", unlocked_ducts.size(), ducts.size())

func _achievement_health_changed(health: int, _maximum: int) -> void:
	if health < achievement_last_health:
		room_damage_taken = true
	achievement_last_health = health

func _on_achievement_web_broken(_web: Area2D) -> void:
	game_menus.unlock_achievement("first_web")
	_refresh_web_achievement()

func _refresh_web_achievement() -> void:
	var broken_count := 0
	for web in achievement_webs:
		if is_instance_valid(web) and web.broken:
			broken_count += 1
	game_menus.set_achievement_progress("web_sweeper", broken_count, achievement_webs.size())
	if not achievement_webs.is_empty() and broken_count == achievement_webs.size():
		game_menus.unlock_achievement("web_sweeper")
