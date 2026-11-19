# C 模块：暂停、房间重试与成就界面

> 2026-11-02 当前交互增量见 [第一关 C 说明](c_level_one_interactions.md)。下方 2026-10-26 的枪架与死亡丢枪描述是历史验证记录，当前按 REV-14 保留已制造能力；成就稳定 ID 不变，`first_weapon` 条件变为首次完成脉冲机械臂制造。

任务：P1-C-UI；负责人：C（本次提交 @lkzzzz219）；状态：待队友复测。
本次范围由用户于 2026-10-26 明确授权，不代表完整 P1 或正式通关流程已经验收。

## 运行与操作

- 整体入口：F5 / `scenes/main.tscn`，标题开始后进入已有开场，再进入腹腔。
- 独立入口：F6 / `scenes/gameplay/abdomen_level.tscn`。
- Esc 打开暂停菜单，按钮依次为「继续游戏」「重试本房间」「成就手册」「返回首页」。
- 暂停菜单中的「重试本房间」从当前关卡出生点重新开始，并重置本关的解谜、敌人、场景装置和获得的能力。第二关返程制造期间使用该按钮会从脊柱入口重开，保留第一关通关记录。重开成功后旅程更新到新的出生状态，本次旅程已解锁的成就保留。
- 成就手册支持名称／完成条件搜索，以及全部、未解锁、已解锁筛选；Esc 返回暂停菜单，再按 Esc 恢复。
- 死亡后世界暂停，等待玩家选择「重试」或「返回首页」。
- 常驻 HUD 只显示当前目标和耐久。方向／距离卡片及 WASD 说明已移除；交互与短通知仍按事件出现。

## 状态与接口

| 文件 | 职责／接口 |
| --- | --- |
| `scenes/gameplay/abdomen_level.gd` | C 运行集成，组装真实角色／敌人；在既有事件回调中解锁成就；调度基线恢复和标题转场 |
| `scenes/gameplay/abdomen_level.tscn` | 根节点 `process_mode = 1`，使世界继承可暂停处理；同时移除失效的地图 UID 引用，继续使用原路径 |
| `scenes/gameplay/pause_input.gd` | 唯一持续监听 Esc 的节点，仅转发 `_toggle_pause()` 并消费该输入 |
| `scenes/gameplay/game_menus.gd` | C 的模态协调层；`toggle_pause()`、`show_death()`、`close_and_resume()`；暂停重开用 `restart_level_requested`，死亡重试用 `retry_requested` |
| `scenes/gameplay/game_menus.gd` | `unlock_achievement(id) -> bool`：只接受定义中的稳定 ID，首次解锁返回 true，重复或无效 ID 返回 false |
| `scenes/gameplay/achievement_toasts.gd` | 根窗口下唯一通知层，跨场景保留队列；`show_achievement(id, definition, completed, total)`；每项显示约 3 秒 |
| `scenes/gameplay/gameplay_ui_theme.tres` | HUD、模态菜单、交互提示和成就通知共用的中文字体主题 |

世界根节点可暂停，Esc 转发、模态菜单和纯 UI 通知保持处理。怪物、玩家、激光、弹丸、终端动画和受伤计时冻结；恢复不补算暂停时间。通知层及其所有 Control 忽略鼠标输入，不遮断游戏点击，也不自行结算战斗。

死亡重试使用当前关卡的复活规则，保留已学能力。暂停菜单重开会重新实例化关卡，场景就绪并保存后才丢弃旧现场。加载或保存失败时，可以返回原暂停菜单。

未改玩家、敌人、武器的公共接口；未改 `project.godot`、Input Map、Autoload、碰撞层、公共 TileSet 或 `scenes/main.tscn`。根窗口通知层由 C 菜单按需创建，并非新增 Autoload。

<a id="abdomen-environment-retry"></a>

## A 环境交互的重试接点（2026-10-27）

用户授权 A 增加第一关可破坏蛛网。`abdomen_level.gd::_retry_level()` 开头查找地图的 `Environment`，存在 `reset_breakable_webs()` 时调用；实现由 `scenes/levels/abdomen/abdomen_webs.gd` 提供。它恢复全部蛛网并清理逃跑蜘蛛，不恢复／重写玩家战斗、敌人快照、门禁或成就。环境节点不存在或没有该方法时跳过，保留原重试流程。

蛛网和蜘蛛不加入 `combat_enemies`，不增加四项成就或清场条件；新环境动画与蜘蛛继承可暂停世界。机械循环的重试相位当前不重置，仅随暂停冻结／恢复，不能写成已完成全机关基线回滚。

当天 macOS 的 `tests/manual/a_map/web_break_check.gd`（实际脉冲命中、环境恢复和计数）及原 `tests/manual/c_progress/progress_check.gd` 均通过。此为 A 增量的本机回归，不替代下方 C 原有 Windows 记录，也不代表其他 C 功能或完整 P1 已跨平台验收。完整变更及复测步骤见 [第一关当天总览](abdomen_map.md#today-scene-update)。

## 成就数据

| 稳定 ID | 名称 | 完成条件 |
| --- | --- | --- |
| `first_weapon` | 借来一束光 | 首次拾取脉冲枪 |
| `first_terminal` | 重新连接 | 首次激活终端 |
| `first_clear` | 清理完成 | 首次击败房间内所有敌人 |
| `first_exit` | 继续前行 | 首次抵达样板出口 |

成就只在游戏运行期间记录。同一趟旅程的关卡切换、重试、返回首页再继续均保留已解锁成就。进入新旅程第一关时清空成就和通知队列，退出游戏后内存记录随进程结束。旧 `user://achievements.cfg` 已停止读写。

通知显示成就名称、完成条件和完成总数；同时解锁按队列顺序展示，不互相覆盖。手册内所有四项均可检索，不存在隐藏剧情条目；未解锁明确显示条件和状态。搜索或筛选无结果时显示空状态。

## 验证入口与真实结果

环境：Windows，Godot `4.7.2.stable.official.ed1daf0bf`，Compatibility。
提交前从暂存树导出干净副本，重新导入资源后运行两个检查入口；未使用原工作区的 `.godot/` 缓存。配置中的主场景也以等价启动命令通过，标题／开场／腹腔连接由检查脚本验证；人工 F5 和跨平台复测留给非作者成员。
在仓库根目录执行，下列 `godot` 替换为本机引擎程序即可：

```sh
godot --headless --editor --import --path .
godot --headless --path . --script res://tests/manual/c_progress/progress_check.gd
godot --headless --path . --script res://tests/manual/c_progress/achievement_check.gd
```

两个脚本分别验证菜单与成就行为。成就检查覆盖内存共享、新旅程清零、重复解锁和旧文件字节校验。

| 检查 | 2026-10-26 结果 |
| --- | --- |
| Godot 导入、GDScript 解析、`git diff --check` | 通过 |
| Esc 暂停／恢复，怪物和弹丸位置、激光和无敌计时、玩家耐久 | 通过：暂停期间不变化，恢复后继续 |
| 真实鼠标事件点击继续，关闭按钮不触发射击 | 通过 |
| 死亡等待选择、重试满耐久、武器回枪架、敌人回基线、清旧弹丸 | 通过 |
| 返回标题、再开始进入开场、开场结束进入腹腔 | 通过 |
| 成就首次／重复／无效 ID，通知顺序与自动消失、跨场景队列 | 通过 |
| 手册完成数量、已／未解锁筛选、条件搜索、空状态、打开时实时更新 | 通过 |
| 成就文件重新加载不重复通知，通知层不拦截鼠标 | 通过 |
| 中文字体关闭系统回退后覆盖当前运行脚本文字 | 通过；使用随仓库提交的 Noto Sans SC 子集 |
| 实际窗口渲染 HUD、暂停菜单、手册及通知 | 1152×648 下检查通过；未发现遮挡角色、缺字或超框 |

人工复测：F5 进入腹腔，拿枪时观察右下角通知；Esc → 成就手册，搜索“出口”并筛选未解锁；靠近清扫者暂停数秒确认世界停止；继续后主动受伤死亡并选择重试，检查门／终端／敌人复位、枪回枪架。

同一趟旅程只为每项成就弹出一次通知。重开旅程后可以再次解锁。

## 素材与剩余范围

面板、菱形符号和布局由项目代码构建，没有第三方图片或 Steam SDK。新增中文字体为 Google Fonts 官方 Noto Sans SC 400 文本子集，原始来源、哈希和字形数量见 `assets/fonts/gameplay_ui_source.json`；许可为仓库现有 `assets/fonts/OFL-NotoSansSC.txt`。详见素材清单与字体说明。

待处理：至少一位非作者成员复测；macOS／Linux 实机检查；完整 P1 的真实可见性、地图／日志、固定灯回滚和双房间成功／失败提交仍未由本次实现。现有 `_enemy_visible_query()` 只检查地图边界，不能将其算作 VISION-04 验收通过。完整流程时长、剧情结尾和四人同提交联合验收也不在本次通过范围。

2026-11-02 后续：旧四项条件列表是历史范围；当前 11 项与本轮蛛网全清等条件以 [成就目录](c_achievement_catalog.md) 为准。
