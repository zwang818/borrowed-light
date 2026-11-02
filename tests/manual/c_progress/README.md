# C：暂停、重试和成就检查

使用仓库约定的 Godot 4.7.2，在仓库根目录运行：

```sh
godot --headless --editor --import --path .
godot --headless --path . --script res://tests/manual/c_progress/progress_check.gd
godot --headless --path . --script res://tests/manual/c_progress/achievement_check.gd
```

成功时分别输出 `RESTORE CHECKS: PASS`、`ACHIEVEMENT CHECKS: PASS`，失败输出具体条件并以非零状态退出。

这两个脚本继承 SceneTree，是命令行检查入口，不能用 F6 运行。人工游玩使用 `scenes/gameplay/abdomen_level.tscn`（F6）或 `scenes/main.tscn`（F5）。

检查使用真实玩家、敌人、弹丸和菜单，覆盖冻结／恢复、鼠标穿透、死亡选择、基线恢复、标题／开场转场、成就读写、队列、搜索／筛选及中文字体覆盖。测试成就写入独立的 `user://test_c_ui_*.cfg` 并清理；不清空玩家的 `achievements.cfg`。

规则依据、接口、手工复测和未完成项见 [C 模块说明](../../../docs/c_ui_achievements.md)。

## 第一关交互检查（2026-11-02）

`godot --headless --path . --script res://tests/manual/c_progress/interaction_check.gd`

覆盖图纸→制造、取消和过期回调、D 展示替换、终端入口真实碰撞和清场开门、终端与出口分离、死亡保留能力和门禁回滚。使用隔离成就文件，结束清理。接入和人工路线见 `docs/c_level_one_interactions.md`。旧 progress_check 的死亡回枪架断言已按 REV-14 更新为保留能力。

管道检查：`godot --headless --path . --script res://tests/manual/c_progress/duct_check.gd`，使用隔离的 `test_ducts.cfg`，验证解锁、按钮传送、安全落点与重试保留。

成就事件检查：`godot --headless --path . --script res://tests/manual/c_progress/achievement_events_check.gd`。使用独立测试成就文件，覆盖真实击破信号、计数／重试、无伤成功失败及首次通知保存；其他管道与记录成就在各自检查中验证。

C-STORY-01：interaction_check 现通过真实 E 输入打开通讯，验证第一句未跳过、推进中不提前授予图纸、Esc 取消、读完提交，以及没有目标栏／开场导航／“阅读时世界暂停”说明。
