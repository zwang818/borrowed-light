# 腹腔成就手册（2026-11-02，C-ACH-02）

用户要求首次解锁通知、更多趣味成就、打破全部蛛网后获得“接受失败的 man”。当前共 11 项，无奖励、数值强化或结局分支。

| 稳定 ID | 成就名称 | 实际条件 |
| --- | --- | --- |
| `first_weapon` | 借来一束光 | 首次完成脉冲机械臂制造 |
| `first_terminal` | 重新连接 | 首次激活终端 |
| `first_clear` | 清理完成 | 首次击败房间内全部敌人 |
| `first_exit` | 继续前行 | 首次抵达样板出口 |
| `first_web` | 友好邻居？ | 首次击破一处室内蛛网 |
| `web_sweeper` | 接受失败的 man | 在一次房间挑战中清除全部 10 处室内蛛网；墙外装饰网不计 |
| `first_retry` | 问题不大，重启一下 | 玩家死亡后选择重试；主动重试不算 |
| `workshop_reader` | 我是谁？说明书呢 | 完成小房间操作台记录交互；取消不算 |
| `duct_traveler` | 这班地铁有点窄 | 首次成功通过管道传送；打开菜单、取消、被阻挡不算 |
| `duct_network` | 地下交通管理员 | 解锁腹腔全部三个管道口 |
| `clean_clear` | 保修期内 | 本次房间挑战开始后没有扣过耐久，击败全部清扫者 |

## 首次通知与兼容

沿用 `user://achievements.cfg` 的 `[achievements]` 布尔键和原有四项稳定 ID。加载原有记录不弹窗，重复满足条件不再排队；首次新增成就弹出右下角消息，连续完成依次显示，通知不阻挡输入、不暂停游戏，跨场景仍显示。通知文字支持换行，不引入 Steam SDK。不会清空用户已有成就，也不增加奖励或改变伤害。

手册显示全部未解锁名称、条件和趣味短句，支持名称／条件／趣味文案／分类词搜索，及全部／未解锁／已解锁筛选。已完成数仅统计这 11 项，与故事真相无关。

## 蛛网计数与房间重试

复用 A 已有的脉冲激光击破、蛛丝碎裂和蜘蛛逃跑效果。`breakable_web.gd` 新增 `broken_once(web)` 信号，只在实际由完整变为击破时发出一次；零伤害和重复伤害不发出。C 只订阅 `background_region` 为空的 10 处室内目标。

墙外背景仍有数百片装饰性蛛网，其中许多不能从可走区域射到，**不把它们作为全清条件**。室内目标全部可被当前机械臂的真实脉冲击中，已有地图检查现按新版发射口计算射线。没有修改墙体、武器伤害、击中延迟或蜘蛛行为。

手册的蛛网进度从实际 `web.broken` 统计，`0 / 10` 到 `10 / 10`；重试恢复蛛网时清零本轮部分进度，不允许反复打同一张网凑满。已解锁成就永久保留本机，重试不会移除。管道进度按本局已解锁入口统计，沿用管道在同一关卡实例内保留的规则。

无伤条件记录本次挑战实际耐久下降，不只检查清场时是否满血。失败后重试会开启新一次无伤挑战；主动重试同样开始新挑战，但不授予死亡重试成就。

## 接口与验证

- `game_menus.gd`：`unlock_achievement(id) -> bool`；新增 `set_achievement_progress(id, current, maximum)`，进度为本次场景快照，不写进游戏存档，不独立判定解锁。
- `abdomen_level.gd`：订阅蛛网击破、真实耐久变化，并消费制造、终端、记录、重试、管道和战斗完成事件。
- A 共享接点仅为蛛网的一次性信号；A 的旧检查更新到 B 最新发射口，且使用隔离成就文件，避免验证写入玩家成就。
- 新文案继续使用有 OFL 许可的 Noto Sans SC 子集，来源、字符数及哈希见字体来源 JSON；没有新增图像或声音素材。

Windows / Godot 4.7.2 已通过：

```sh
godot --headless --path . --script res://tests/manual/c_progress/achievement_check.gd
godot --headless --path . --script res://tests/manual/c_progress/achievement_events_check.gd
godot --headless --path . --script res://tests/manual/c_progress/interaction_check.gd
godot --headless --path . --script res://tests/manual/c_progress/duct_check.gd
godot --headless --path . --script res://tests/manual/a_map/web_break_check.gd
```

覆盖首次／重复／重载通知、手册条件与趣味文案搜索、实时进度、9/10 不提前解锁、10/10 解锁、重试清部分计数而保留已解锁项、背景网排除、无伤成功与失败、实际管道／记录事件、10 张网真实脉冲命中与蜘蛛暂停／清理。实际窗口预览检查了手册和“接受失败的 man”弹窗。预览通过定位镜头和驱动事件展示，不代表已完成非作者完整徒步通关。其他平台及队友人工复测待处理。
