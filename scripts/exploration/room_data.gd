class_name RoomData
extends Resource
## 房间静态配置数据（A 提供，C 读取）
## 对应 Bible 接口：房间描述

@export var room_id: String = ""
@export var display_name: String = ""
@export var spawn_point: Vector2 = Vector2.ZERO

## 探索区域：预划分网格或子区域，用于可见性与记忆
@export var exploration_areas: Array[ExplorationArea] = []

## 房间内的对象配置（门、终端、拾取物、灯、敌人出生点、日志）
@export var objects: Array[RoomObjectData] = []

## 出口配置
@export var exits: Array[RoomExitData] = []


class ExplorationArea:
	extends Resource
	@export var area_id: String = ""  ## 例：abdomen_room_01_area_01
	@export var bounds: Rect2 = Rect2()  ## 局部坐标边界
	@export var neighbors: Array[String] = []  ## 相邻区域 ID（用于遮挡判断优化）


class RoomObjectData:
	extends Resource
	@export var object_id: String = ""  ## 稳定 ID，全局唯一
	@export var object_type: ObjectType = ObjectType.DOOR
	@export var position: Vector2 = Vector2.ZERO
	@export var config: Dictionary = {}  ## 对象专属参数

	enum ObjectType {
		DOOR,
		TERMINAL,
		PICKUP,
		LIGHT,
		ENEMY_SPAWN,
		LOG
	}


class RoomExitData:
	extends Resource
	@export var exit_id: String = ""  ## 本地唯一
	@export var position: Vector2 = Vector2.ZERO
	@export var target_room_id: String = ""  ## 目标房间 room_id
	@export var target_entry_id: String = ""  ## 目标入口标记（对应目标房间入口区域）
