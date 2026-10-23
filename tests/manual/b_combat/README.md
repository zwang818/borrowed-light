# B 战斗测试

在 Godot 打开 `combat_test.tscn`，按 F6 运行当前场景。

- WASD 或方向键移动，空闲时鼠标控制绿色角色箭头朝向。
- 点按左键蓄力 1 秒，结束时按当前鼠标方向在正负 10° 内辅助索敌并锁定，随后发射激光，持续 0.5 秒后结束。蓄力与发射期间仍可移动，起点随玩家移动。
- 激光不反射，遇墙或地图边界停止，遇敌停止，每束对同一敌人只伤害一次。忙碌期间点击不排队，按住不重复，结束后须再次点按。
- 旧弹丸、弹夹和回满已移除。测试场景直接授予脉冲枪；左上角显示测试用蓄力与激光状态，不是正式 HUD。
- 移动方向与朝向独立：鼠标指向右侧时仍可向左或向上移动。
- 橙色固定哨机已接入：3 点耐久，黄色预警 0.75 秒后连发 3 弹；玩家 3 格耐久，受伤无敌 0.8 秒。均为原型值。
- 玩家死亡后停止操作；按 R 可重置双方耐久、位置和攻击残留，仅用于测试。
- 临时灰盒规格：32 px/格，移动速度 160 px/s，圆形实体半径 10 px。
- 场地墙体为碰撞层 1，玩家为层 2、检测层 1；正式集成时与 C 核对。

测试入口仅在运行时注册缺少的 `move_left/right/up/down` 和左键 `shoot` 动作，不写入
`project.godot`。若项目已配置同名动作，则使用项目配置。正式入口必须由 C
提供这些动作或在玩家 Inspector 配置对应动作名；缺少配置会明确报错。

## 手工检查

1. 横向、纵向、斜向移动：斜向总速度与直行一致。
2. 松开移动键立即停止；空闲时移动鼠标，箭头跟随鼠标。
3. 朝右瞄准并向左走，朝向不被移动方向覆盖；蓄力期间随鼠标转向，激光期间保持蓄力结束时锁定的朝向。
4. 持续推向外墙、中央隔墙及右下薄墙，不能穿过；斜推墙面能沿墙滑动。
5. 绕过隔墙两端和转角，确认可正常通行。
6. 窗口缩放后鼠标仍指向同一世界位置；鼠标移到角色中心时保留上一朝向。

自动物理检查：

```sh
godot --headless --path . --script res://tests/manual/b_combat/movement_check.gd
```

## 脉冲枪验收与接口

1. 点按后移动鼠标到另一侧，确认蓄力跟随瞄准、发射采用蓄力结束时方向；移动玩家，确认激光起点随之移动。
2. 持续按住左键只发一束；结束后再次点按可以立即开始下一轮蓄力。
3. 正对或斜对外墙、隔墙和薄墙射击，检查碰墙停止；贴墙时也不能在墙另一侧生成光束。
4. 激光可以击毁橙色哨机；自动测试另用假靶验证直线遮挡及同束去重。

自动检查：`godot --headless --path . --script res://tests/manual/b_combat/pulse_gun_check.gd`。

- 武器提供 `request_fire(direction)`、`advance_time(delta, origin, current_direction)` 和 `cancel()`，由玩家驱动。
- 可读取 `state`、`remaining`、`locked_direction`；公开信号为 `state_changed`、`shot_fired`、`beam_finished`。
- 玩家用 `pulse_gun_equipped` 标记是否已获得枪；默认未获得，由测试场景显式开启。
- 激光检测层 1（世界）和层 3（敌人）；受伤对象提供 `apply_damage(amount)`，激光不伤害玩家。
- 无固定射程上限，地图边界由 configure_space(bounds, visible_query) 注入；单束伤害暂为 1。
- 取消控制或卸下武器清除光束，场景释放也会释放光束。正式房间重试仍待 C 调度。
- 暂停场景树冻结蓄力与激光时长，不按现实时间补算。

## 2026-10-21 音效与渐进激光

蓄力时播放上升音高音效，发射切换激光音，结束或取消停止。光束按到地图边界的距离逐步展开，暂设 0.3 秒，包含在 0.5 秒持续时间内；未显示部分不能造成伤害。可调整 beam_extension_duration。

## 哨机与玩家耐久测试

靠近右上方哨机，保持无遮挡且距离在 320 px 内。黄色瞄准线出现后留有预警时间，躲开其连射方向；每束激光对哨机扣 1 点，3 束可击毁。玩家最多承受 3 次有效命中，同次连射可能因无敌时间只扣 1 格。玩家死亡只发送通知，未自行重载主场景。

该场地为显式全亮测试房间；测试适配器检查画面范围，哨机再检查射程和墙体。正式游戏必须由 C 注入实际可见性，不使用“永远可见”回退。R 重置仅用于此独立入口，满血是测试配置，不是正式检查点规则。

对接接口：

- 玩家：`health_changed(current, maximum)`、`died`、`get_health_snapshot()`、`apply_damage(amount)`、`restore_player(location, checkpoint_health, retained_weapons)`。
- 哨机：`configure(player, visibility_query, projectile_parent)`，其中查询签名为 `(enemy) -> bool`；`apply_damage(amount)`、`get_combat_state()`、`restore_combat_state(snapshot)`；`died(entity_id)`。
- 哨机使用稳定 ID 保存血量；恢复不保存预警、锁定或连射计时。C 调度恢复时还需清理独立弹丸容器。普通哨机失去视线或被击毁不抹去已射出弹丸；房间重置会清空弹丸。
- `scenes/weapons/combat_parameters.gd` 集中维护本轮血量与哨机原型参数。

检查命令：`godot --headless --path . --script res://tests/manual/b_combat/health_sentry_check.gd`。

辅助索敌：运行入口提供可辨认查询；存活敌人注册 combat_enemies 组并提供 get_combat_state()。蓄力结束时优先选择正负 10° 内角度偏差最小且无遮挡的敌人，角度相同时选择较近者。无目标时保持原方向；发射后不追踪。

## 清扫者（2026-10-21）

紫色清扫者位于场地下半部，3 点耐久，巡逻后发现玩家会接近，以 120 世界单位/秒追击，停顿预警 0.65 秒再攻击前方矩形区域，单次伤害 1，攻击后恢复 0.65 秒。黄色范围无伤害，红色范围生效，攻击不跟随玩家转向；从侧面或后方避开。激光可击毁清扫者。

P 仅在测试入口切换协议：清扫者停止追击/攻击并忽略玩家，玩家不能射击，哨机和已有敌方弹丸仍能伤害玩家。正式协议由 C 控制终端与区域，不把 P 当作正式操作。R 恢复玩家、两类敌人及清扫者巡逻基线。

清扫者公开接口：`configure(player, visibility_query, protocol_query)`、`apply_damage(amount)`、`get_combat_state()`、`restore_combat_state(snapshot)`、`health_changed`、`died(entity_id)`。巡逻点为相对出生位置的 `patrol_offsets`；C 提供真实可辨认和协议查询。未配置会明确报错，不默认永远可见或无协议。

自动检查：`godot --headless --path . --script res://tests/manual/b_combat/cleaner_check.gd`。
