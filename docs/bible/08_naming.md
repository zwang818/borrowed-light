# 08 · Naming（命名与术语）

> 统一 Bible v2.3 · 2026-10-27 · 当前执行版本。强制规则、建议方案和待定项分别标注。

[返回总览](_index.md) · [待定与决策](99_decisions.md)

## 1. 强制命名与兼容边界

### ENG-03 · 命名和兼容

新工程文件小写英文 `snake_case`，节点与类 `PascalCase`，函数和变量 `snake_case`，常量 `UPPER_SNAKE_CASE`。布尔含义明确，信号表达事件，时间用秒，距离用统一世界单位。玩家文案使用中文。文档中的中文标题不受工程文件命名限制。

稳定 ID 复制后必须查重；更名必须同步引用与必要迁移，不能直接改字符串破坏进度。文件移动、Autoload、输入动作、碰撞层、公共资源和接口变化必须检查调用方，并说明影响。不能随意删除别人的改动、重新初始化仓库或大范围重排无关文件。

## 2. 文件与目录

| 类型 | 规则 | 示例 |
| --- | --- | --- |
| 目录 | 小写 `snake_case` | `core_guardian/` |
| 场景 | 小写 `snake_case.tscn` | `repair_terminal.tscn` |
| 脚本 | 与负责的场景或职责同名 | `repair_terminal.gd` |
| 配置资源 | 对象名或用途名 | `pulse_gun.tres` |
| 图片 | 对象、动作、必要方向 | `player_walk_down.png` |
| 音频 | 类型前缀加事件 | `sfx_player_hurt.wav` |
| 文档 | 既定章节号与名称 | `03_rules.md` |

不用空格、中文路径或 `final_final2` 等版本后缀管理正式资产；迭代记录交给版本控制。不要仅靠大小写区别两个文件。

## 3. 节点与代码

| 对象 | 规则 | 示例 |
| --- | --- | --- |
| 节点 | `PascalCase`，按职责命名 | `Player`、`InteractionArea`、`Muzzle` |
| 类名 | `PascalCase` | `RepairTerminal` |
| 函数与变量 | `snake_case` | `apply_damage()`、`current_health` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_HEALTH` |
| 枚举类型 | `PascalCase` | `AttackState` |
| 枚举成员 | `UPPER_SNAKE_CASE` | `WINDUP`、`RECOVERY` |
| 信号 | 已发生的事件 | `health_changed`、`weapon_acquired`、`boss_defeated` |
| 布尔值 | 清楚表达判断 | `is_dead`、`can_attack`、`has_protocol` |

避免 `data1`、`thing`、`temp2` 等长期含糊命名。信号参数和调用函数使用一致单位，例如时间统一秒、距离统一引擎世界单位。

## 4. 稳定 ID

| 类别 | 示例 | 规则 |
| --- | --- | --- |
| 关卡 | `abdomen` | 场景逻辑名，不绑定展示标题 |
| 房间 | `abdomen_room_01` | 关卡前缀加唯一编号 |
| 探索区域 | `abdomen_room_01_area_01` | 不与房间 ID 混用 |
| 终端 | `abdomen_terminal_01` | 同关卡内不重复 |
| 门 | `abdomen_door_01` | 开门条件引用稳定 ID |
| 日志 | `log_core_interface` | 按内容含义命名 |
| 对话 | `dlg_deity_return_request` | 按叙事事件命名 |
| 检查点 | `checkpoint_core_entry` | 明确位置或用途 |
| 内置攻击能力 | `pulse_gun`、`scatter_tool` | 旧稳定 ID 保留；分别表示脉冲激光与散射臂形态，不再代表可拾取枪械 |

改显示名称不需要改 ID。复制门、终端、房间场景后检查是否产生重复 ID。已被日志或进度引用的 ID 不随意重命名。

## 5. 统一术语

| 中文 | 工程用语建议 | 定义 |
| --- | --- | --- |
| 照明 | `lighting` | 画面光源与明暗效果 |
| 当前可见 | `visible` | 当前范围内且无遮挡 |
| 已探索 | `explored` | 本局已记录的静态区域 |
| 空间记忆 | `exploration_memory` | 保存已探索区域，不是实时雷达 |
| 维护协议 | `maintenance_protocol` | 指定区域低级识别权限 |
| 重试点 | `checkpoint` | 死亡返回的位置与恢复规则 |
| 房间重置 | `room_reset` | 恢复房间运行状态 |
| 自我改造 | `self_modification` | 神明引导下完成结构调整与能力学习 |
| 学习记忆 | `learned` | 已掌握的能力知识，本局死亡保留 |
| 能力校准 | `calibrated` | 首次进化时的校准完成状态；若保留此字段，死亡不清零，不用于强制重播教学 |
| 意识同步 | `consciousness_sync` | 最终剧情事件 |

“虚体”仅是维护协议的视觉俗称，代码不以 `ghost` 暗示穿墙或物理无敌。“记忆”不能同时指探索记录、日志和所有游戏存档而不加区分。

## 6. 文案约定

- 玩家目标使用行动语句，如“恢复核心通道供电”。
- 交互统一采用“按键 · 动作”，如“E · 阅读记录”。
- 神明表达柔和好奇，维护系统表达简短、功能化。
- 内部制作文字可说明控制权迁移，玩家界面遵循隐藏线索原则。
- 代码注释解释为什么这样处理，避免仅复述函数名。
