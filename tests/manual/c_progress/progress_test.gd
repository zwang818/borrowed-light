extends Node2D
## C 模块测试入口：验证房间数据、可见性、交互、基线与跨房间提交
## 运行方式：在 Godot 中打开本场景，按 F6（运行当前场景）
## 验收项：P1-C 最小闭环、P1-Q02/Q06 相关分支

@onready var room_manager: RoomManager = $RoomManager
@onready var label: Label = $CanvasLayer/Label
@onready var room_container: Node2D = $RoomContainer

var _test_player: Node2D
var _interaction_coordinator: InteractionCoordinator
var _terminal: RepairTerminal
var _door: Door


func _ready() -> void:
	## 创建最小测试替身玩家
	_test_player = _create_test_player()
	add_child(_test_player)

	## 绑定 RoomManager
	room_manager.player = _test_player
	room_manager.visibility_system.update_world_space(get_world_2d().direct_space_state)

	## 创建交互协调器
	_interaction_coordinator = InteractionCoordinator.new()
	_interaction_coordinator.bind_player(_test_player)
	_interaction_coordinator.bind_visibility_system(room_manager.visibility_system)
	add_child(_interaction_coordinator)
	_interaction_coordinator.interaction_prompt_changed.connect(_on_prompt_changed)

	## 构建并进入测试房间
	var room1 := _build_test_room_data("test_room_01", Vector2(200, 300))
	room_manager.enter_room(room1)

	## 在房间容器内放置终端和门（模拟 A 的地图摆放 + C 的运行生成）
	_place_terminal(Vector2(400, 300), "test_room_01_terminal_01", "test_room_01_door_01")
	_place_door(Vector2(700, 300), "test_room_01_door_01")

	## 注册固定灯
	room_manager.visibility_system.register_room_light("test_room_01", Vector2(400, 300), 120.0, true)

	## 绑定终端信号
	_terminal.activated.connect(_on_terminal_activated)

	_update_label("测试入口已就绪\n当前房间: test_room_01\n前往终端（中央）按 E 操作")


func _process(_delta: float) -> void:
	## 更新物理空间引用
	if room_manager != null and room_manager.visibility_system != null:
		room_manager.visibility_system.update_world_space(get_world_2d().direct_space_state)

	## 测试玩家移动（最小替身，无碰撞）
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0:
		_test_player.position += input_dir.normalized() * 200.0 * _delta

	## 模拟死亡重试测试（按 Enter）
	if Input.is_action_just_pressed("ui_accept"):
		_simulate_death_and_retry()


func _on_terminal_activated(terminal_id: String) -> void:
	_update_label("终端已激活: " + terminal_id + "\n门已打开，固定灯已恢复")


func _on_prompt_changed(prompt: Dictionary) -> void:
	var prompt_text := ""
	if prompt.get("available", false):
		prompt_text = "[E] " + prompt.get("action_text", "交互")
	$CanvasLayer/Instructions.text = "操作：WASD 移动 | E 交互终端 | Enter 模拟死亡重试 | Esc 暂停\n" + prompt_text


func _simulate_death_and_retry() -> void:
	## 先模拟玩家获得武器和读日志
	room_manager.exploration_memory.add_weapon("pulse_gun")
	room_manager.exploration_memory.mark_log_read("log_test_01")
	## 标记一些探索区域
	room_manager.exploration_memory.mark_area_explored("test_room_01", "test_room_01_area_01")

	## 执行重试
	room_manager.perform_retry()
	_update_label("已执行重试\n"
		+ "玩家回到出生点\n"
		+ "门灯回基线（若未提交）\n"
		+ "已探索区域数: " + str(room_manager.exploration_memory.get_explored_area_ids("test_room_01").size()) + "\n"
		+ "已读日志: " + str(room_manager.exploration_memory._read_logs.size()) + "\n"
		+ "持有武器: " + str(room_manager.exploration_memory.get_acquired_weapons()))


func _create_test_player() -> Node2D:
	var p := Node2D.new()
	p.name = "TestPlayer"
	p.position = Vector2(200, 300)

	## 可视化：蓝色方块
	var sprite := ColorRect.new()
	sprite.color = Color(0.3, 0.6, 1.0)
	sprite.size = Vector2(24, 24)
	sprite.position = Vector2(-12, -12)
	p.add_child(sprite)

	## 玩家灯光范围可视化
	var light := PointLight2D.new()
	light.energy = 0.4
	light.texture = _make_circle_texture(160)
	light.blend_mode = Light2D.BLEND_MODE_ADD
	p.add_child(light)

	return p


func _place_terminal(pos: Vector2, t_id: String, target_door: String) -> void:
	_terminal = RepairTerminal.new()
	_terminal.name = "RepairTerminal"
	_terminal.terminal_id = t_id
	_terminal.target_door_id = target_door
	_terminal.position = pos
	room_container.add_child(_terminal)

	## 可视化：绿色方块 + 交互区域
	var vis := ColorRect.new()
	vis.color = Color(0.2, 0.8, 0.4)
	vis.size = Vector2(32, 32)
	vis.position = Vector2(-16, -16)
	_terminal.add_child(vis)

	var area := Area2D.new()
	area.collision_layer = 64  ## interactable
	area.collision_mask = 0
	_terminal.add_child(area)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	area.add_child(shape)


func _place_door(pos: Vector2, d_id: String) -> void:
	_door = Door.new()
	_door.name = "Door"
	_door.door_id = d_id
	_door.position = pos
	room_container.add_child(_door)

	## 可视化：棕色矩形 + 碰撞
	var vis := ColorRect.new()
	vis.color = Color(0.6, 0.4, 0.2)
	vis.size = Vector2(32, 96)
	vis.position = Vector2(-16, -48)
	_door.add_child(vis)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 96)
	col.shape = rect
	_door.add_child(col)


func _build_test_room_data(room_id: String, spawn: Vector2) -> RoomData:
	var data := RoomData.new()
	data.room_id = room_id
	data.spawn_point = spawn

	var area := RoomData.ExplorationArea.new()
	area.area_id = room_id + "_area_01"
	area.bounds = Rect2(0, 0, 800, 600)
	data.exploration_areas.append(area)

	var terminal := RoomData.RoomObjectData.new()
	terminal.object_id = room_id + "_terminal_01"
	terminal.object_type = RoomData.RoomObjectData.ObjectType.TERMINAL
	terminal.position = Vector2(400, 300)
	data.objects.append(terminal)

	var door := RoomData.RoomObjectData.new()
	door.object_id = room_id + "_door_01"
	door.object_type = RoomData.RoomObjectData.ObjectType.DOOR
	door.position = Vector2(700, 300)
	data.objects.append(door)

	return data


func _make_circle_texture(radius: int) -> Texture2D:
	var img := Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2i(radius, radius)
	for x in range(radius * 2):
		for y in range(radius * 2):
			var d := Vector2i(x, y).distance_to(center)
			if d <= radius:
				var a := 1.0 - (d / radius)
				img.set_pixel(x, y, Color(1, 1, 1, a * 0.5))
	return ImageTexture.create_from_image(img)


func _update_label(text: String) -> void:
	if label != null:
		label.text = text
