# 《借光》公共接口约定 v0.1

> 本文件由 C 维护，对应 P0-02。  
> 变更需提出更新，由 C 统一整理后同步相关模块。

## 1. 输入动作（Input Map）

| 动作名 | 按键 | 说明 |
| --- | --- | --- |
| `move_left` | A / ← | 水平移动；斜向需归一化 |
| `move_right` | D / → | 同上 |
| `move_up` | W / ↑ | 同上 |
| `move_down` | S / ↓ | 同上 |
| `shoot` | 鼠标左键 | 按住按冷却连续射击（P1 暂定） |
| `interact` | E | 交互请求，由公共协调层消费 |
| `toggle_map` | M | 打开/关闭记忆地图界面 |
| `pause` | Esc | 暂停菜单 |

## 2. 碰撞层（2D Physics）

| 层号 | 名称 | 对象 | 掩码建议 |
| --- | --- | --- | --- |
| 1 | `world` | 墙、关闭的实体门、不可通行结构 | 所有实体层检测 |
| 2 | `player_body` | 玩家实体 | 检测 1,5,6,7,8 |
| 3 | `enemy_body` | 敌人/Boss 实体 | 检测 1,4,7,8 |
| 4 | `player_projectile` | 玩家弹丸 | 检测 1,3 |
| 5 | `enemy_projectile` | 敌方弹丸 | 检测 1,2 |
| 6 | `interactable` | 终端、日志、拾取物交互区 | 由玩家 Area2D 检测 |
| 7 | `hazard` | 伤害区域 | 检测 2,3 |
| 8 | `room_trigger` | 房间出入口、协议区、探索触发区 | 检测 2 |

## 3. 房间描述（A 提供 → C 读取）

```gdscript
class_name RoomData
extends Resource

@export var room_id: String          # 例：abdomen_room_01
@export var display_name: String     # 展示名（可选）
@export var areas: Array[RoomArea]   # 探索区域列表
@export var spawn_point: Vector2     # 出生点（地图局部坐标）
@export var objects: Array[RoomObject]  # 对象配置
@export var exits: Array[RoomExit]   # 出口配置
```

- 坐标统一为地图局部坐标（像素或瓦片格，由 A 在灰盒阶段统一）。
- `room_id` 全局唯一；复制房间场景后必须查重。
- `objects` 中每个条目包含：`id`（稳定 ID）、`type`（枚举：`door`, `terminal`, `pickup`, `light`, `enemy_spawn`, `log`）、`position`（Vector2）、`config`（Dictionary，对象专属参数）。
- `exits` 包含：`exit_id`（本地唯一）、`target_room_id`（目标房间）、`target_entry_id`（目标入口标记）。

## 4. 玩家状态接口（B 提供）

### 信号
- `health_changed(current: int, maximum: int)` — 耐久变化
- `player_died()` — 玩家死亡；只发一次

### 方法
- `get_health_snapshot() -> Dictionary` — 返回 `{current: int, maximum: int}`
- `restore_at(position: Vector2, health: int, weapons: Array[String])` — 由 C 调用恢复
- `set_combat_active(active: bool)` — C 调用以冻结/恢复战斗输入

## 5. 可见性查询（C 提供）

```gdscript
# VisibilitySystem
func is_position_illuminated(pos: Vector2, room_id: String) -> bool
func is_position_visible(pos: Vector2, room_id: String) -> bool
func get_visible_entities(room_id: String) -> Array[String]  # 对象 ID 列表
```

- `illuminated`：处于主角光域或已启用固定灯的有效覆盖内，且光源到位置无实体墙/关闭门阻挡。
- `visible`：illuminated + 玩家到该位置的视线无遮挡 + 同一房间。
- B 的敌人叠加自身检测距离和协议过滤，不重复计算灯光。

## 6. 空间记忆事件（C → D）

### 信号（由 RoomManager 或 ExplorationMemory 发出）
- `exploration_updated(room_id: String, explored_cells: Array[Vector2i])`
- `memory_map_ready(snapshot: ExplorationSnapshot)` — 供地图界面读取

## 7. 交互系统（C 协调）

- 输入：`interact` 动作只发请求。
- C 的 `InteractionCoordinator` 校验：范围、遮挡、状态。
- 执行对象逻辑后，对象发信号：`interaction_completed(object_id: String, result: Dictionary)`。
- D 读取当前交互提示：`InteractionCoordinator.get_current_prompt() -> Dictionary {target_id, action_text, available}`。

## 8. 房间生命周期信号（C 发出）

- `room_entered(room_id: String)`
- `room_exited(room_id: String)`
- `room_checkpoint_saved(room_id: String)` — 进入房间时建立基线
- `room_submitted(room_id: String)` — 成功跨房间后提交
- `room_reset_to_checkpoint(room_id: String)` — 死亡回滚

## 9. 暂停与模态输入

- D 发请求 → C 的 `GameFlow` 冻结/恢复世界。
- 冻结范围：敌人、弹丸、机关、伤害计时；UI 继续接收输入。
- 模态窗口打开时，输入不穿透到游戏（不能同时触发攻击或交互）。
