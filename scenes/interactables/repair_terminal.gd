class_name RepairTerminal
extends Node2D
## 维修终端：交互后门开灯亮
## 对应 Bible PROTOCOL-01（P1 暂不实现完整协议，只做终端→门→灯链）

signal activated(terminal_id: String)

@export var terminal_id: String = ""
@export var target_door_id: String = ""  ## 控制哪扇门
@export var target_light_ids: Array[String] = []  ## 同时恢复哪些固定灯
@export var interaction_text: String = "操作终端"

var is_activated: bool = false


func interact() -> void:
	if is_activated:
		return
	is_activated = true
	activated.emit(terminal_id)
	_apply_effects()


func _apply_effects() -> void:
	## 打开门
	if not target_door_id.is_empty():
		var door := _find_door(target_door_id)
		if door != null:
			door.open()

	## 恢复固定灯（通过 RoomManager 或 VisibilitySystem）
	for light_id in target_light_ids:
		## P1 简化：灯的效果通过 RoomManager.visibility_system 注册
		## 实际运行时由集成场景组装信号
		pass


func get_prompt() -> Dictionary:
	if is_activated:
		return {"target_id": terminal_id, "action_text": "已激活", "available": false}
	return {"target_id": terminal_id, "action_text": interaction_text, "available": true}


func get_persistent_state() -> Dictionary:
	return {"is_activated": is_activated}


func restore_persistent_state(state: Dictionary) -> void:
	is_activated = state.get("is_activated", false)
	if is_activated:
		_apply_effects()


func _find_door(door_id: String) -> Door:
	## 在房间容器内查找门（P1 简化实现）
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is Door and child.door_id == door_id:
			return child
	return null
