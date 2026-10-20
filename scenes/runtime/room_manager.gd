class_name RoomManager
extends Node
## 房间生命周期管理器：基线、重试、跨房间提交
## 对应 Bible STATE-01、team_plan P1-C

signal room_entered(room_id: String)
signal room_exited(room_id: String)
signal room_checkpoint_saved(room_id: String)
signal room_submitted(room_id: String)
signal room_reset_to_checkpoint(room_id: String)
signal request_player_restore(position: Vector2, health: int, weapons: Array[String])
signal request_world_pause(paused: bool)

## 当前房间数据
var current_room_id: String = ""
var current_room_data: RoomData = null

## 房间运行实例（场景节点）
var current_room_instance: Node = null

## 基线：进入房间时的快照（用于死亡回滚）
var _room_baseline: Dictionary = {}

## 跨房间已提交状态：{ room_id: submitted_snapshot }
var _submitted_states: Dictionary = {}

## 探索记忆（由外部注入或内部创建）
var exploration_memory: ExplorationMemory = null

## 可见性系统
var visibility_system: VisibilitySystem = null

## 玩家引用（由外部注入）
var player: Node = null

## 测试数值（P1 临时默认；来源：Bible 04_physics 原型参数表）
const CHECKPOINT_HEALTH: int = 3  ## OPEN-05：检查点恢复至最大耐久


func _ready() -> void:
	if exploration_memory == null:
		exploration_memory = ExplorationMemory.new()
		add_child(exploration_memory)
	if visibility_system == null:
		visibility_system = VisibilitySystem.new()
		add_child(visibility_system)


## 进入新房间（首次进入或返回已访问房间）
func enter_room(room_data: RoomData) -> void:
	if current_room_instance != null:
		_exit_current_room()

	current_room_data = room_data
	current_room_id = room_data.room_id

	## 检查是否有已提交状态（返回旧房间时）
	var submitted_snap: Dictionary = {}
	if _submitted_states.has(current_room_id):
		submitted_snap = _submitted_states[current_room_id]

	## 实例化房间（简化：直接加载 A 提供的场景或生成灰盒）
	## P1 阶段：房间实例由运行场景按标记生成；此处调用虚拟方法供子类/测试覆盖
	current_room_instance = _instantiate_room(room_data, submitted_snap)
	if current_room_instance != null and not current_room_instance.is_inside_tree():
		add_child(current_room_instance)

	## 设置出生点
	var spawn := room_data.spawn_point
	if player != null:
		player.global_position = spawn
		visibility_system.bind_player(player)

	## 建立基线
	_save_room_baseline()
	room_checkpoint_saved.emit(current_room_id)
	room_entered.emit(current_room_id)


## 请求离开房间（走到出口触发器时）
func request_exit(exit_data: RoomData.RoomExitData) -> bool:
	## 检查目标房间是否合法
	var target_id := exit_data.target_room_id
	if target_id.is_empty():
		push_error("RoomManager: 出口未配置目标房间")
		return false

	## 加载目标房间数据（P1 简化：从 data/rooms/ 目录加载 .tres）
	var target_data := _load_room_data(target_id)
	if target_data == null:
		push_error("RoomManager: 找不到目标房间数据: " + target_id)
		return false

	## 提交当前房间变化
	_submit_current_room()

	## 进入目标房间
	enter_room(target_data)
	return true


## 玩家死亡时由 B 调用（或信号连接）
func on_player_died() -> void:
	if current_room_id.is_empty():
		push_warning("RoomManager: 收到死亡通知但无当前房间")
		return
	## 冻结世界
	request_world_pause.emit(true)
	## 显示死亡/重试界面由 D 处理；此处提供恢复方法供 D 的按钮调用


## 执行重试：恢复到当前房间基线
func perform_retry() -> void:
	if current_room_id.is_empty() or not _room_baseline.has(current_room_id):
		push_error("RoomManager: 无基线可恢复")
		return

	var base: Dictionary = _room_baseline[current_room_id]

	## 1. 恢复房间运行状态（门、灯、敌人）
	_restore_room_from_baseline(base)

	## 2. 恢复玩家（C 调用 B 的恢复接口）
	var spawn: Vector2 = current_room_data.spawn_point
	var weapons: Array[String] = exploration_memory.get_acquired_weapons()
	request_player_restore.emit(spawn, CHECKPOINT_HEALTH, weapons)

	## 3. 恢复探索记忆（保留已探索区域和已读日志）
	if base.has("memory_snapshot"):
		exploration_memory.restore_from_snapshot(base["memory_snapshot"])

	## 4. 清理残留弹丸和攻击区（由 B 清理自身状态）
	## 5. 恢复机关周期（P1 暂不实现完整机关，预留接口）

	room_reset_to_checkpoint.emit(current_room_id)
	request_world_pause.emit(false)


## 保存当前房间基线（进入房间时调用一次）
func _save_room_baseline() -> void:
	var base := {
		"room_id": current_room_id,
		"memory_snapshot": exploration_memory.get_explored_snapshot(),
		"object_states": _capture_object_states(),
	}
	_room_baseline[current_room_id] = base


## 提交当前房间（成功跨房间后）
func _submit_current_room() -> void:
	var submitted := {
		"room_id": current_room_id,
		"memory_snapshot": exploration_memory.get_explored_snapshot(),
		"object_states": _capture_object_states(),
	}
	_submitted_states[current_room_id] = submitted
	room_submitted.emit(current_room_id)


func _exit_current_room() -> void:
	room_exited.emit(current_room_id)
	if current_room_instance != null:
		current_room_instance.queue_free()
		current_room_instance = null
	visibility_system.clear_room_lights(current_room_id)


## 捕获房间内对象状态（门、灯、终端等）
func _capture_object_states() -> Dictionary:
	var states := {}
	if current_room_instance == null:
		return states
	## 遍历房间实例下的交互对象，收集状态
	for child in current_room_instance.get_children():
		if child.has_method("get_persistent_state"):
			states[child.name] = child.get_persistent_state()
	return states


func _restore_room_from_baseline(base: Dictionary) -> void:
	if current_room_instance == null:
		return
	var obj_states: Dictionary = base.get("object_states", {})
	for child in current_room_instance.get_children():
		if child.has_method("restore_persistent_state") and obj_states.has(child.name):
			child.restore_persistent_state(obj_states[child.name])


## 虚拟方法：实例化房间（P1 灰盒阶段可覆盖）
func _instantiate_room(room_data: RoomData, submitted_state: Dictionary) -> Node:
	## P1 最小实现：返回一个空 Node2D 作为容器；
	## 正式集成时由子类或运行场景按 room_data 生成实际内容。
	var container := Node2D.new()
	container.name = "Room_" + room_data.room_id
	return container


## 加载房间数据资源
func _load_room_data(room_id: String) -> RoomData:
	var path := "res://data/rooms/" + room_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("RoomManager: 房间资源不存在: " + path)
		return null
	return load(path) as RoomData


## 获取当前房间的交互提示（供 D 显示）
func get_current_interaction_prompt() -> Dictionary:
	## P1 简化：由当前面向的交互对象自行提供
	## 此处返回空，实际由 InteractionCoordinator 补充
	return {"target_id": "", "action_text": "", "available": false}
