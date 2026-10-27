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
