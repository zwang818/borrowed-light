class_name InteractionCoordinator
extends Node
## 交互协调器：统一消费 E 键请求，校验范围与遮挡，再执行对象逻辑
## 对应 Bible 交互系统约定、team_plan P1-C

signal interaction_prompt_changed(prompt: Dictionary)
signal interaction_executed(object_id: String, result: Dictionary)

@export var interaction_range: float = 40.0  ## 1.25T @ 32px = 40px（临时默认）

var _player: Node2D = null
var _current_target: Node = null
var _visibility_system: VisibilitySystem = null


func bind_player(player: Node2D) -> void:
	_player = player


func bind_visibility_system(vs: VisibilitySystem) -> void:
	_visibility_system = vs


func _process(_delta: float) -> void:
	if _player == null:
		return
	_update_nearest_target()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_request_interaction()


func _update_nearest_target() -> void:
	var nearest: Node = null
	var nearest_dist := interaction_range

	## 在当前房间容器内查找可交互对象
	var room_container := _get_room_container()
	if room_container == null:
		return

	for child in room_container.get_children():
		if not child.has_method("interact"):
			continue
		var dist := _player.global_position.distance_to(child.global_position)
		if dist < nearest_dist:
			## 简单视线校验：交互不要求 full visible，但要求无实体墙完全挡住
			if _is_reachable(child.global_position):
				nearest = child
				nearest_dist = dist

	if nearest != _current_target:
		_current_target = nearest
		_emit_prompt()


func _request_interaction() -> void:
	if _current_target == null:
		return
	if not _current_target.has_method("interact"):
		return

	## 再次校验距离
	var dist := _player.global_position.distance_to(_current_target.global_position)
	if dist > interaction_range:
		return

	_current_target.interact()
	interaction_executed.emit(_current_target.name, {"success": true})
	_emit_prompt()  ## 交互后提示可能变化


func _emit_prompt() -> void:
	if _current_target == null:
		interaction_prompt_changed.emit({"target_id": "", "action_text": "", "available": false})
		return

	if _current_target.has_method("get_prompt"):
		var prompt: Dictionary = _current_target.get_prompt()
		interaction_prompt_changed.emit(prompt)
	else:
		interaction_prompt_changed.emit({"target_id": _current_target.name, "action_text": "交互", "available": true})


func _is_reachable(target_pos: Vector2) -> bool:
	## P1 简化：只要有物理空间就做射线检测；否则默认可达
	if _visibility_system == null or _visibility_system._world_space == null:
		return true
	return _visibility_system._has_line_of_sight(_player.global_position, target_pos)


func _get_room_container() -> Node:
	## 通过 RoomManager 获取当前房间实例
	var rm := get_parent()
	if rm is RoomManager:
		return rm.current_room_instance
	return null
