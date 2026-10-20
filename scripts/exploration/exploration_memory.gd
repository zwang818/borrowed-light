class_name ExplorationMemory
extends Node
## 空间记忆系统：记录本局已探索区域与已读日志
## 对应 Bible VISION-01/02、STATE-01

signal exploration_updated(room_id: String, explored_area_ids: Array[String])
signal log_read(log_id: String)

## 已探索区域：{ room_id: Set(area_id) }
var _explored: Dictionary = {}

## 已读日志 ID
var _read_logs: Array[String] = []

## 已获取武器 ID
var _acquired_weapons: Array[String] = []

## 终端已激活记录（不随死亡回滚）
var _activated_terminals: Array[String] = []


func reset_session() -> void:
	"""新游戏时重置整局记忆"""
	_explored.clear()
	_read_logs.clear()
	_acquired_weapons.clear()
	_activated_terminals.clear()


func mark_area_explored(room_id: String, area_id: String) -> void:
	if not _explored.has(room_id):
		_explored[room_id] = {}
	var areas: Dictionary = _explored[room_id]
	if not areas.has(area_id):
		areas[area_id] = true
		exploration_updated.emit(room_id, get_explored_area_ids(room_id))


func is_area_explored(room_id: String, area_id: String) -> bool:
	if not _explored.has(room_id):
		return false
	return _explored[room_id].has(area_id)


func get_explored_area_ids(room_id: String) -> Array[String]:
	if not _explored.has(room_id):
		return []
	var out: Array[String] = []
	for k in _explored[room_id].keys():
		out.append(k)
	return out


func get_explored_snapshot() -> Dictionary:
	"""返回可序列化的快照，用于跨房间提交或调试"""
	var snap := {
		"explored": {},
		"read_logs": _read_logs.duplicate(),
		"acquired_weapons": _acquired_weapons.duplicate(),
		"activated_terminals": _activated_terminals.duplicate(),
	}
	for room_id in _explored.keys():
		snap["explored"][room_id] = _explored[room_id].keys()
	return snap


func restore_from_snapshot(snap: Dictionary) -> void:
	"""从快照恢复（用于死亡重试后保留记忆）"""
	_explored.clear()
	if snap.has("explored"):
		for room_id in snap["explored"].keys():
			_explored[room_id] = {}
			for area_id in snap["explored"][room_id]:
				_explored[room_id][area_id] = true
	if snap.has("read_logs"):
		_read_logs = snap["read_logs"].duplicate()
	if snap.has("acquired_weapons"):
		_acquired_weapons = snap["acquired_weapons"].duplicate()
	if snap.has("activated_terminals"):
		_activated_terminals = snap["activated_terminals"].duplicate()


## 日志
func mark_log_read(log_id: String) -> void:
	if not _read_logs.has(log_id):
		_read_logs.append(log_id)
		log_read.emit(log_id)


func is_log_read(log_id: String) -> bool:
	return _read_logs.has(log_id)


## 武器
func add_weapon(weapon_id: String) -> void:
	if not _acquired_weapons.has(weapon_id):
		_acquired_weapons.append(weapon_id)


func has_weapon(weapon_id: String) -> bool:
	return _acquired_weapons.has(weapon_id)


func get_acquired_weapons() -> Array[String]:
	return _acquired_weapons.duplicate()


## 终端
func mark_terminal_activated(terminal_id: String) -> void:
	if not _activated_terminals.has(terminal_id):
		_activated_terminals.append(terminal_id)


func is_terminal_activated(terminal_id: String) -> bool:
	return _activated_terminals.has(terminal_id)
