class_name VisibilitySystem
extends Node
## 可见性查询系统（游戏规则层，不替代灯光表现）
## 对应 Bible VISION-04、04_physics 第 4 节

## 查询结果枚举
enum Visibility {
	UNKNOWN,      ## 未探索（黑暗）
	ILLUMINATED,  ## 有效照亮但可能未在当前视野（用于静态区域）
	VISIBLE,      ## 当前可见：照亮 + 视线无遮挡 + 同一房间
}

## 世界碰撞层（用于视线检测）
const LAYER_WORLD: int = 1

var _player: Node2D = null
var _player_light_radius: float = 160.0  ## 5T @ 32px/T = 160px（临时默认）
var _room_lights: Dictionary = {}  ## { room_id: Array[LightInfo] }
var _world_space: PhysicsDirectSpaceState2D = null


class LightInfo:
	var position: Vector2
	var radius: float
	var enabled: bool = true
	func _init(p: Vector2, r: float, e: bool = true):
		position = p
		radius = r
		enabled = e


func bind_player(player: Node2D) -> void:
	_player = player


func set_player_light_radius(r: float) -> void:
	_player_light_radius = r


func register_room_light(room_id: String, position: Vector2, radius: float, enabled: bool = true) -> void:
	if not _room_lights.has(room_id):
		_room_lights[room_id] = []
	_room_lights[room_id].append(LightInfo.new(position, radius, enabled))


func set_room_light_enabled(room_id: String, light_index: int, enabled: bool) -> void:
	if not _room_lights.has(room_id):
		return
	var lights: Array = _room_lights[room_id]
	if light_index >= 0 and light_index < lights.size():
		lights[light_index].enabled = enabled


func update_world_space(space: PhysicsDirectSpaceState2D) -> void:
	_world_space = space


## 核心查询：某位置是否有效照亮
func is_position_illuminated(world_pos: Vector2, room_id: String) -> bool:
	## 1. 检查是否在玩家光域内
	if _player != null:
		var dist := world_pos.distance_to(_player.global_position)
		if dist <= _player_light_radius:
			if _has_line_of_sight(_player.global_position, world_pos):
				return true

	## 2. 检查房间固定灯
	if _room_lights.has(room_id):
		for light in _room_lights[room_id]:
			if not light.enabled:
				continue
			var dist := world_pos.distance_to(light.position)
			if dist <= light.radius:
				if _has_line_of_sight(light.position, world_pos):
					return true
	return false


## 核心查询：某位置是否当前可见
func get_position_visibility(world_pos: Vector2, room_id: String, current_room_id: String) -> Visibility:
	if room_id != current_room_id:
		## 不同房间：只能根据记忆显示静态轮廓，不算当前可见
		## 此处返回 UNKNOWN，由调用方根据记忆系统决定是否显示轮廓
		return Visibility.UNKNOWN

	if not is_position_illuminated(world_pos, room_id):
		return Visibility.UNKNOWN

	## 同一房间且已照亮：检查玩家到该位置的视线
	if _player != null and _has_line_of_sight(_player.global_position, world_pos):
		return Visibility.VISIBLE

	## 照亮但被遮挡：显示为低亮度轮廓（ILLUMINATED）
	return Visibility.ILLUMINATED


## 敌人发现条件（B 调用）
func can_player_perceive_enemy(enemy_pos: Vector2, enemy_room_id: String, current_room_id: String) -> bool:
	"""玩家可辨认敌人：敌人当前可见且出现在可读范围"""
	if enemy_room_id != current_room_id:
		return false
	var vis := get_position_visibility(enemy_pos, enemy_room_id, current_room_id)
	if vis != Visibility.VISIBLE:
		return false
	## 画面可读范围检查：简化为中心点是否在屏幕矩形内（由调用方补充相机范围）
	return true


## 内部：视线遮挡检测（使用 PhysicsDirectSpaceState2D）
func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	if _world_space == null:
		## 降级：直接算距离，不判断墙后（仅用于无物理空间场景，测试时可能触发）
		return true

	var query := PhysicsRayQueryParameters2D.new()
	query.from = from
	query.to = to
	query.collision_mask = LAYER_WORLD
	query.hit_from_inside = false
	var result := _world_space.intersect_ray(query)
	## 无碰撞 = 视线畅通
	return result.is_empty()


func clear_room_lights(room_id: String) -> void:
	if _room_lights.has(room_id):
		_room_lights[room_id].clear()
