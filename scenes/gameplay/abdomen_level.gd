extends Node2D
## 腹腔关卡运行场景：组装地图、玩家、敌人、交互对象
## P1 最小可玩：出生 → 拿枪 → 打清扫者 → 终端开门 → 出口完成
## C 模块集成：引导 HUD、终端门禁、房间重试、场景切换、空间记忆

const ROBOT_TEXTURE := preload("res://assets/sprites/title/title_robot.svg")
const COMBAT_SKIN := preload("res://scenes/gameplay/combat_skin.gd")

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CLEANER_SCENE := preload("res://scenes/enemies/cleaner/cleaner.tscn")
const SENTRY_SCENE := preload("res://scenes/enemies/sentry/sentry.tscn")

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
	"arrow_hide_dist": 40.0,
	"welcome_duration": 4.0,
	"notify_default": 2.0,
	"level_complete_wait": 3.0,
	"fade_duration": 0.5,
	"t_welcome": "关卡开始！靠近枪架拾取脉冲枪",
	"t_weapon_get": "获得脉冲枪！点按左键蓄力射击",
	"t_terminal_ok": "终端已激活，大门开启",
	"t_all_enemies_down": "所有敌人已清除，前往终端",
	"t_retry": "已重试，沿指引前往枪架拾取脉冲枪",
	"t_died": "你死了……2秒后重试",
	"t_level_complete": "样板完成",
	"t_weapon_prompt": "脉冲枪 - 靠近拾取",
	"t_terminal_prompt": "[E] 操作终端",
	"t_controls": "[WASD] 移动  [鼠标] 瞄准  [左键] 射击\n[E] 交互  [Esc] 暂停",
}

@onready var map := $AbdomenGraybox as Node2D
@onready var bullets_parent := $Bullets as Node2D
@onready var interactables_parent := $Interactables as Node2D
@onready var camera := $Camera2D as Camera2D

var robot_visual: Sprite2D
var player: CharacterBody2D
var enemies: Array[Node] = []
var interactables: Array[Node] = []
var is_level_complete := false
var nearest_interactable: Node = null

enum Objective { GET_WEAPON, KILL_ENEMIES, ACTIVATE_TERMINAL, REACH_EXIT }
var current_objective: int = Objective.GET_WEAPON
var total_enemies: int = 0
var dead_enemies: int = 0
var terminal_activated := false
var weapon_pickup: Node = null
var terminal: Node = null
var final_exit: Node = null
var explored_positions: Array[Vector2] = []
var last_memory_record_time: float = 0.0

## HUD 节点
var hud_canvas: CanvasLayer
var objective_label: Label
var guide_bg: ColorRect      ## 中上方引导面板背景
var guide_label: Label       ## 中上方引导文字（方向+距离+提示）
var controls_label: Label
var controls_bg: ColorRect
var interact_label: Label
var interact_bg: ColorRect
var notify_label: Label
var notify_bg: ColorRect
var hp_bar: ColorRect
var hp_bg: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_update_objective()
	_show_welcome()

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if is_instance_valid(robot_visual):
		robot_visual.global_rotation = 0
		robot_visual.global_position = player.global_position + Vector2(0, -5)
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
	if event.is_action_pressed("interact") and not get_tree().paused:
		_try_interact()
	if event.is_action_pressed("pause"):
		_toggle_pause()

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

## ---------- 开场引导 ----------

func _show_welcome() -> void:
	_show_notification(C.t_welcome, C.welcome_duration)

## ---------- HUD 系统（最简化版） ----------

func _setup_hud() -> void:
	hud_canvas = CanvasLayer.new()
	add_child(hud_canvas)

	## === 顶部：任务目标 ===
	var obj_bg := ColorRect.new()
	obj_bg.color = C.panel_bg
	obj_bg.position = Vector2(0, 0)
	obj_bg.size = Vector2(1152, 48)
	hud_canvas.add_child(obj_bg)

	objective_label = Label.new()
	objective_label.position = Vector2(0, 8)
	objective_label.size = Vector2(1152, 36)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 20)
	objective_label.add_theme_color_override("font_color", C.text_gold)
	objective_label.text = ""
	hud_canvas.add_child(objective_label)

	## === 中上方：引导面板（方向+距离+提示）===
	guide_bg = ColorRect.new()
	guide_bg.color = Color(0, 0, 0, 0.7)
	guide_bg.position = Vector2(20, 180)
	guide_bg.size = Vector2(300, 100)
	guide_bg.visible = true
	hud_canvas.add_child(guide_bg)

	guide_label = Label.new()
	guide_label.position = Vector2(20, 180)
	guide_label.size = Vector2(300, 100)
	guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guide_label.add_theme_font_size_override("font_size", 18)
	guide_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	guide_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	guide_label.add_theme_constant_override("outline_size", 5)
	guide_label.text = "引导加载中..."
	guide_label.visible = true
	hud_canvas.add_child(guide_label)

	## === 左下角：操作提示 + 血条 ===
	controls_bg = ColorRect.new()
	controls_bg.color = Color(0, 0, 0, 0.65)
	controls_bg.position = Vector2(8, 500)
	controls_bg.size = Vector2(300, 140)
	controls_bg.visible = true
	hud_canvas.add_child(controls_bg)

	controls_label = Label.new()
	controls_label.position = Vector2(16, 510)
	controls_label.size = Vector2(280, 70)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	controls_label.add_theme_font_size_override("font_size", 14)
	controls_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	controls_label.text = C.t_controls
	controls_label.visible = true
	hud_canvas.add_child(controls_label)

	## 血条背景
	hp_bg = ColorRect.new()
	hp_bg.color = C.hp_empty
	hp_bg.position = Vector2(16, 590)
	hp_bg.size = Vector2(184, 20)
	hud_canvas.add_child(hp_bg)

	## 血条前景
	hp_bar = ColorRect.new()
	hp_bar.color = C.hp_full
	hp_bar.position = Vector2(16, 590)
	hp_bar.size = Vector2(184, 20)
	hud_canvas.add_child(hp_bar)

	## 血量文字
	var hp_text := Label.new()
	hp_text.position = Vector2(16, 590)
	hp_text.size = Vector2(184, 20)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 12)
	hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hp_text.text = "HP 100 / 100"
	hp_text.name = "HpText"
	hud_canvas.add_child(hp_text)

	## === 中央偏下：交互提示 ===
	interact_bg = ColorRect.new()
	interact_bg.color = C.panel_bg
	interact_bg.position = Vector2(376, 450)
	interact_bg.size = Vector2(400, 36)
	interact_bg.visible = false
	hud_canvas.add_child(interact_bg)

	interact_label = Label.new()
	interact_label.position = Vector2(376, 450)
	interact_label.size = Vector2(400, 36)
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interact_label.add_theme_font_size_override("font_size", 18)
	interact_label.add_theme_color_override("font_color", C.text_green)
	interact_label.text = ""
	hud_canvas.add_child(interact_label)

	## === 屏幕正中央：浮动通知 ===
	notify_bg = ColorRect.new()
	notify_bg.color = C.panel_bg
	notify_bg.position = Vector2(276, 300)
	notify_bg.size = Vector2(600, 48)
	notify_bg.visible = false
	hud_canvas.add_child(notify_bg)

	notify_label = Label.new()
	notify_label.position = Vector2(276, 300)
	notify_label.size = Vector2(600, 48)
	notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notify_label.add_theme_font_size_override("font_size", 24)
	notify_label.add_theme_color_override("font_color", C.text_notify)
	notify_label.text = ""
	hud_canvas.add_child(notify_label)

	print("[HUD] 所有节点已创建，guide_bg.visible=", guide_bg.visible, " controls_bg.visible=", controls_bg.visible)

## ---------- HUD 更新 ----------

func _update_objective() -> void:
	match current_objective:
		Objective.GET_WEAPON:
			objective_label.text = "当前目标：拾取脉冲枪"
		Objective.KILL_ENEMIES:
			var remaining: int = total_enemies - dead_enemies
			objective_label.text = "当前目标：击败清扫者（剩余 %d）" % remaining
		Objective.ACTIVATE_TERMINAL:
			objective_label.text = "当前目标：操作终端开启大门 ↑"
		Objective.REACH_EXIT:
			objective_label.text = "当前目标：前往出口 ↑"

func _update_hud() -> void:
	_update_hp_bar()
	_update_guide_panel()
	_update_world_prompts()

func _update_hp_bar() -> void:
	var max_hp: float = 100.0
	var hp: float = 100.0
	if player != null and is_instance_valid(player):
		if "max_health" in player:
			max_hp = float(player.max_health)
		elif "max_hp" in player:
			max_hp = float(player.max_hp)
		if "health" in player:
			hp = float(player.health)
		elif "hp" in player:
			hp = float(player.hp)
		elif "current_health" in player:
			hp = float(player.current_health)
	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	hp_bar.size.x = int(184 * ratio)
	var hp_text := hud_canvas.get_node_or_null("HpText")
	if hp_text != null:
		hp_text.text = "HP %d / %d" % [int(hp), int(max_hp)]

func _update_guide_panel() -> void:
	## 中上方面板：始终显示，内容根据目标动态更新
	if player == null or player.is_dead:
		guide_label.text = "等待玩家..."
		guide_bg.visible = true
		guide_label.visible = true
		return

	var target := _get_current_target()
	if target == null or not is_instance_valid(target):
		guide_label.text = "目标未找到\n请检查地图标记"
		guide_bg.visible = true
		guide_label.visible = true
		return

	var diff: Vector2 = target.global_position - player.global_position
	var dist: float = diff.length()

	## 计算方向
	var angle: float = diff.angle()
	var dir_text := ""
	if angle > -0.785 and angle <= 0.785:
		dir_text = "右 →"
	elif angle > 0.785 and angle <= 2.356:
		dir_text = "下 ↓"
	elif angle > 2.356 or angle <= -2.356:
		dir_text = "左 ←"
	else:
		dir_text = "上 ↑"

	## 组合文字：方向 + 距离 + 提示
	var guide_text := ""
	if dist < C.arrow_hide_dist:
		guide_text = "目标就在附近！\n"
	else:
		guide_text = "目标方向: %s\n距离: %.0f\n" % [dir_text, dist]
	
	if current_objective == Objective.GET_WEAPON:
		guide_text += "靠近枪架拾取脉冲枪"
	elif current_objective == Objective.KILL_ENEMIES:
		guide_text += "击败清扫者"
	elif current_objective == Objective.ACTIVATE_TERMINAL:
		guide_text += "操作终端开启大门"
	elif current_objective == Objective.REACH_EXIT:
		guide_text += "前往出口完成关卡"

	guide_label.text = guide_text
	guide_bg.visible = true
	guide_label.visible = true

func _get_current_target() -> Node:
	match current_objective:
		Objective.GET_WEAPON:
			return weapon_pickup
		Objective.ACTIVATE_TERMINAL:
			return terminal
		Objective.REACH_EXIT:
			return final_exit
		Objective.KILL_ENEMIES:
			return _get_nearest_alive_enemy()
	return null

func _get_nearest_alive_enemy() -> Node:
	var nearest: Node = null
	var nearest_dist: float = 999999.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("get_combat_state"):
			var state: Dictionary = enemy.get_combat_state()
			if not state.get("alive", true):
				continue
		var dist: float = player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _update_world_prompts() -> void:
	## 武器提示
	if weapon_pickup != null and is_instance_valid(weapon_pickup):
		var w_dist: float = player.global_position.distance_to(weapon_pickup.global_position)
		var w_prompt := weapon_pickup.get_node_or_null("PromptLabel")
		if w_prompt != null:
			w_prompt.visible = w_dist < C.weapon_prompt_range

	## 终端提示
	var show_screen_prompt := false
	if nearest_interactable != null and is_instance_valid(nearest_interactable):
		if nearest_interactable.has_meta("is_terminal") and not nearest_interactable.get_meta("activated"):
			show_screen_prompt = true
			var t_prompt := nearest_interactable.get_node_or_null("PromptLabel")
			if t_prompt != null:
				t_prompt.text = _terminal_prompt()
				t_prompt.visible = true

	## 隐藏其他终端提示
	for obj in interactables:
		if not is_instance_valid(obj) or obj == nearest_interactable:
			continue
		if obj.has_meta("is_terminal") and not obj.get_meta("activated"):
			var t_prompt := obj.get_node_or_null("PromptLabel")
			if t_prompt != null:
				t_prompt.visible = false

	## 屏幕中央交互提示
	if show_screen_prompt:
		interact_label.text = _terminal_prompt()
		interact_label.visible = true
		interact_bg.visible = true
	else:
		interact_label.visible = false
		interact_bg.visible = false

## ---------- 通知系统 ----------

func _show_notification(text: String, duration: float = C.notify_default) -> void:
	notify_label.text = text
	notify_label.visible = true
	notify_bg.visible = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(notify_label):
		notify_label.visible = false
	if is_instance_valid(notify_bg):
		notify_bg.visible = false

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
			cleaner.global_position = pos
			cleaner.entity_id = StringName(marker.object_id)
			cleaner.name = marker.object_id
			add_child(cleaner)
			cleaner.get_node("Facing/Body").hide()
			var cleaner_model := COMBAT_SKIN.new()
			cleaner_model.name = "CleanerModel"
			cleaner_model.kind = "cleaner"
			cleaner.get_node("Facing").add_child(cleaner_model)
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

func _add_weapon_pickup(pos: Vector2, weapon_id: String) -> Node:
	var area := Area2D.new()
	area.name = "WeaponPickup_" + weapon_id
	area.position = pos
	area.collision_layer = 64
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	# The rack remains solid. Extend pickup to its edge so the display is reachable.
	var rectangle := RectangleShape2D.new()
	rectangle.size = map.get_node("Walls/GunRackBase").size + Vector2(16, 16)
	shape.shape = rectangle
	area.add_child(shape)
	var vis := COMBAT_SKIN.new()
	vis.name = "GunModel"
	vis.position.x = 12
	vis.scale = Vector2.ONE * 1.5
	area.add_child(vis)
	## 拾取提示
	var prompt_label := Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = C.t_weapon_prompt
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt_label.add_theme_constant_override("outline_size", 5)
	prompt_label.position = Vector2(-70, -45)
	prompt_label.size = Vector2(140, 28)
	prompt_label.visible = false
	area.add_child(prompt_label)
	area.set_meta("is_weapon", true)
	area.body_entered.connect(func(body): _on_weapon_entered(body, weapon_id, area))
	interactables_parent.add_child(area)
	interactables.append(area)
	return area

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
	## 绿色方块 + 脉冲
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([-10, -10, 10, -10, 10, 10, -10, 10])
	vis.color = Color(0.2, 0.8, 0.4, 0.7)
	area.add_child(vis)
	var tween := create_tween().set_loops()
	tween.tween_property(vis, "scale", Vector2(1.2, 1.2), 0.6)
	tween.tween_property(vis, "scale", Vector2(1.0, 1.0), 0.6)
	## 黄色提示背景 + 文字
	var prompt_panel := ColorRect.new()
	prompt_panel.name = "PromptPanel"
	prompt_panel.color = C.panel_yellow
	prompt_panel.position = Vector2(-65, -52)
	prompt_panel.size = Vector2(130, 26)
	prompt_panel.visible = false
	area.add_child(prompt_panel)
	var prompt_label := Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = C.t_terminal_prompt
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	prompt_label.position = Vector2(-65, -52)
	prompt_label.size = Vector2(130, 26)
	prompt_label.visible = false
	area.add_child(prompt_label)
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
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([-32, -16, 32, -16, 32, 16, -32, 16])
	vis.color = Color(0.6, 0.4, 0.2, 0.9)
	body.add_child(vis)
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
	robot_visual = Sprite2D.new()
	robot_visual.name = "RobotModel"
	robot_visual.texture = ROBOT_TEXTURE
	robot_visual.scale = Vector2.ONE * 0.30
	robot_visual.position = Vector2(0, -5)
	player.get_node("Facing").add_child(robot_visual)
	player.pulse_gun.get_node("Barrel").hide()
	var held_gun := COMBAT_SKIN.new()
	held_gun.name = "HeldGunModel"
	player.pulse_gun.add_child(held_gun)
	player.pulse_gun.move_child(held_gun, 0)
	player.pulse_gun.configure_space(map_bounds, _enemy_visible_query)
	player.died.connect(_on_player_died)

func _configure_enemies() -> void:
	for enemy in enemies:
		if enemy.has_method("configure"):
			if enemy is StaticBody2D:
				enemy.configure(player, _enemy_visible_query, bullets_parent)
			else:
				enemy.configure(player, _enemy_visible_query, _in_protocol_query)
		enemy.died.connect(_on_enemy_died)

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
	if player == null or player.is_dead:
		nearest_interactable = null
		return
	var nearest: Node = null
	var nearest_dist: float = C.interaction_range
	for obj in interactables:
		if not is_instance_valid(obj):
			continue
		var dist: float = player.global_position.distance_to(obj.global_position)
		if dist < nearest_dist:
			if obj is Area2D or obj is StaticBody2D:
				nearest = obj
				nearest_dist = dist
	nearest_interactable = nearest

func _remaining_cleaners() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.get_script() == preload("res://scenes/enemies/cleaner/cleaner.gd"):
			if enemy.get_combat_state().alive:
				count += 1
	return count

func _terminal_prompt() -> String:
	var remaining := _remaining_cleaners()
	return "终端锁定：剩余 %d 台清扫者" % remaining if remaining > 0 else C.t_terminal_prompt

func _try_interact() -> void:
	if player.is_dead or get_tree().paused:
		return
	_update_interaction()
	if nearest_interactable == null:
		return
	if nearest_interactable.has_meta("is_terminal") and not nearest_interactable.get_meta("activated"):
		if _remaining_cleaners() > 0:
			_show_notification(_terminal_prompt(), 1.5)
			return
		nearest_interactable.set_meta("activated", true)
		terminal_activated = true
		var linked: Array = nearest_interactable.get_meta("linked_ids", [])
		for door_id in linked:
			_open_door(door_id)
		for child in nearest_interactable.get_children():
			if child is Polygon2D:
				child.color = Color(0.5, 0.5, 0.5, 0.5)
		_play_terminal_sound()
		_show_notification(C.t_terminal_ok, C.notify_default)
		current_objective = Objective.REACH_EXIT
		_update_objective()

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
	var vis: Polygon2D = null
	for child in door.get_children():
		if child is Polygon2D:
			vis = child
			break
	if vis == null:
		return
	var final_color := Color(0.3, 0.8, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(vis, "color", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(vis, "color", final_color, 0.15)
	tween.tween_property(vis, "color", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(vis, "color", final_color, 0.15)

## ---------- 事件回调 ----------

func _on_weapon_entered(body: Node, _weapon_id: String, area: Area2D) -> void:
	if body == player and not player.is_dead and not player.pulse_gun_equipped and not area.is_queued_for_deletion():
		player.pulse_gun_equipped = true
		area.queue_free()
		_show_notification(C.t_weapon_get, 2.5)
		current_objective = Objective.KILL_ENEMIES
		_update_objective()

func _on_exit_entered(body: Node, exit_id: String) -> void:
	if body != player or is_level_complete:
		return
	for obj in interactables_parent.get_children():
		if obj.has_meta("exit_id") and obj.get_meta("exit_id") == exit_id:
			if obj.get_meta("is_final_exit", false):
				is_level_complete = true
				_show_level_complete()
			break

func _return_weapon_to_rack() -> void:
	player.pulse_gun_equipped = false
	player.pulse_gun.cancel()
	player.pulse_gun.hide()
	if not is_instance_valid(weapon_pickup) or weapon_pickup.is_queued_for_deletion():
		# Discard freed pickup references so repeated deaths do not grow the list.
		interactables = interactables.filter(func(obj): return is_instance_valid(obj) and not obj.is_queued_for_deletion())
		weapon_pickup = _add_weapon_pickup(_weapon_display_position(), "pulse_gun")
	current_objective = Objective.GET_WEAPON
	_update_objective()

func _on_player_died() -> void:
	_return_weapon_to_rack()
	_show_notification(C.t_died, 2.0)
	await get_tree().create_timer(2.0).timeout
	_retry_level()

func _on_enemy_died(_entity_id: StringName) -> void:
	dead_enemies += 1
	var remaining: int = total_enemies - dead_enemies
	_show_notification("清扫者被击败（剩余 %d）" % remaining, 1.5)
	_update_objective()
	if remaining <= 0 and current_objective == Objective.KILL_ENEMIES:
		current_objective = Objective.ACTIVATE_TERMINAL
		_update_objective()
		_show_notification(C.t_all_enemies_down, 2.5)

## ---------- 查询函数 ----------

func _enemy_visible_query(enemy: Node) -> bool:
	var bounds: Rect2 = map.get_meta("map_bounds", Rect2())
	return bounds.has_point(enemy.global_position)

func _in_protocol_query() -> bool:
	return false

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
	var spawn_pos: Vector2 = _find_spawn_position()
	
	player.restore_player(spawn_pos, player.max_health, [])
	_return_weapon_to_rack()
	current_objective = Objective.GET_WEAPON
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
			for child in obj.get_children():
				if child is Polygon2D:
					child.color = Color(0.6, 0.4, 0.2, 0.9)
	dead_enemies = 0
	_update_objective()
	_show_notification(C.t_retry, 2.0)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("get_combat_state") and enemy.has_method("restore_combat_state"):
			var snap: Dictionary = enemy.get_combat_state()
			snap.health = enemy.max_health
			snap.alive = true
			enemy.restore_combat_state(snap)

func _find_spawn_position() -> Vector2:
	var markers := map.get_node_or_null("Markers")
	if markers == null:
		return Vector2.ZERO
	for marker in markers.get_children():
		if marker is Marker2D and marker.object_type == "spawn":
			return marker.global_position
	return Vector2.ZERO

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
