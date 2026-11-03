# 第一关 C 交互与显示接入（2026-11-02）

任务：P1-C-INTERACT；负责人：林昆泽（C）；状态：待非作者复测。
当前说明反映本次提交的最终行为。依据组长交接与用户后续确认：取消任务指引，改为剧情通讯；终端区域入口在清场后开放；管道逐点解锁；成就与机械心显示按后续要求接入。

## 运行流程与界面

F5 主入口 `scenes/main.tscn` → 标题 → 开场 → 腹腔；可用 F6 单独运行 `scenes/gameplay/abdomen_level.tscn`。

玩家探索到图纸台按 E → 小一／神明逐句通讯 → 回制造台装配机械臂 → 战斗 → 清场开放终端区域 → E 输入维护口令 → 原出口门开启。2026-11-03 增量：图纸室和小房间分别藏有前／后两段口令，玩家通过交互记录获知；不检查已读数量，也不增加常驻指引。

常驻仅有机械心耐久；靠近有效物件才给局部 E 提示。没有目标栏、方向／距离、WASD、开场指路，也不显示“下一步”和“阅读时世界暂停”说明。对话和暂停菜单仍冻结世界，Esc 取消或关闭当前窗口，完成本句／本段不能同时攻击。

三颗像素机械心对应当前 3 HP，数值与形状消费 B 的真实耐久；受伤提亮、1 HP 缓慢脉动、0 HP 空壳和离线、重试恢复，暂停冻结动画。视图支持小数快照的半心，当前伤害仍为原整数规则。

## 固定交互点与 D 接口

坐标为当前无变换腹腔地图中的世界坐标，按 A 的家具下沿计算，未修改地图布局文件。

| 内容 ID | 家具锚点 | 交互位置 | 完成效果 |
| --- | --- | --- | --- |
| `pulse_blueprint` | `Walls/GunRackBase` | `(432, 1924)` | 记录图纸，不授予攻击 |
| `pulse_workbench` | `Walls/AssemblyBase` | `(320, 2500)` | 需要图纸；制造后授予 `pulse_gun` 能力 |
| `workshop_origin` | `Walls/WorkshopBench` | `(1056, 1508)` | 记录已读，允许手动回听 |

交互距离为 48 世界单位并检查实体墙遮挡；应站在家具下沿的可走地面，不以家具中心作为站立位置。

```gdscript
level.interaction_requested.connect(presenter.present)
level.interaction_finished.connect(presenter.close_request)
# present(content_id: StringName, payload: Dictionary, token: int)
# 整段完成：level.finish_interaction(token, true)
# 取消／中断：level.finish_interaction(token, false)
# close_request(token, completed)：关闭对应演出并停止对应配音。
```

- payload 包含 `title`、`summary`、`confirm`、`category`、`state`、`replay`；通讯另提供 `dialogue: Array[Dictionary]`，每句为 `{speaker, text}`。
- 没有展示方时，C 的面板按 E／点击逐句推进，最后确认才提交完成。连接 D 展示方后仅由其展示，不自动判定完成；D 应在整段结束后回调。
- C 发请求前暂停世界，维护唯一有效 token；旧 token、取消后回调、重复回调都不推进。D 展示方需 `PROCESS_MODE_ALWAYS`，接收结束信号清理窗口与声音，消费关闭输入。
- `get_interaction_state()` 提供图纸、已学能力、故事已读与终端状态快照，以及独立复制的 `terminal_clues` 字典；D 不直接改世界字段。
- 当前短稿按用户的“预留战斗模块、带图纸回醒来处左侧制造台”例子接入，并点出既定的小一制造与接口信息；正式对白、美术、配音和音效仍由 D 润色替换。

## 门禁与房间重试

新增 `p1_terminal_access_gate`，在终端下方 48 单位，宽 144、厚 16，配侧面与上沿实体围挡。清场前不能穿门、绕侧面或隔门 E；清场只开放区域入口，终端再开原 `p1_door_01`。最终出口也校验终端状态。

### 维护口令（2026-11-03，C-TERMINAL-01）

以下密码仅供开发和复测，正式游戏不自动显示完整答案：

| 线索内容 ID | 所在房间与载体 | 对白中的线索 |
| --- | --- | --- |
| `pulse_blueprint` | 图纸室，原图纸台 | 图纸页脚：维护口令前段 `04` |
| `workshop_origin` | 小房间，制造室操作台 | 记录末尾：维护口令后段 `17` |

按前后顺序组成 `0417`。沿用原有局部 E 点与逐句对白，图纸和小房间都可再次交互重读，不新增地图节点或方向提示。完整结束对应交互才向 `terminal_clues` 记录该片段；死亡重试保留已读记忆，新关卡实例清空。D 替换对白时应保留两段线索及其顺序，仍调用原 `finish_interaction` 接口。

终端 E 打开数字键盘：支持键盘数字、Enter、鼠标数字键、退格、清空与 Esc 返回。保留开头的零，空／不足四位提示补齐，错误四位提示核对记录，可不限次数重试；无伤害或锁死惩罚。终端只说明原始记录在图纸与制造室中，不显示已拼出的答案或添加任务 HUD。已知密码可直接验证，不把读过故事／日志当作强制收集条件。

功能面板由 C 直接展示，不送入 D 的 `interaction_requested` 演出接口。`interaction_sheet.code_submitted(token, code)` 交由 `_submit_terminal_code` 检查唯一请求 `terminal_access`、当前 token、玩家存活、距离／遮挡、清场和入口状态、准确口令，全部满足才激活、开出口和解锁原 `first_terminal` 成就。通用 `finish_interaction(token, true)` 不授予终端权限；取消、过期或重复提交无效。输入期间沿用长交互暂停，结束后延迟恢复输入。

重试使终端及两道门恢复锁定；清场后可使用记住的口令重新验证，无需重读线索。没有新增跨程序存档、随机密码、收集奖励或外部素材。

重试恢复敌人基线、两道门、终端、环境蛛网，清旧弹丸和门动画；按 REV-14 保留本关已完成的能力学习，不重播已完成教学、不生成实体枪。图纸与已读记录在关卡实例内保留；未读完的交互不授予进度。复活位置与恢复耐久沿用当前实现，没有新增复活点，也未将原满耐久默认值当作 OPEN-05 已裁定。

## 管道互传

| ID | A 的井盖锚点 | 入口中心 | 名称 |
| --- | --- | --- | --- |
| `duct_arrival` | `ArrivalHatch` | `(704, 2552)` | 出生区管道 |
| `duct_weapon` | `WeaponHatch` | `(768, 1952)` | 图纸区管道 |
| `duct_exit` | `ExitHatch` | `(792, 536)` | 终端区管道 |

每个入口到达后 E 确认解锁，再 E 打开井盖与目的地选择；仅列其他已解锁入口。Esc 返回会关井盖，选择目的地才移动。传送取消自身蓄力、清零速度并重置相机平滑，不增加免伤。优先在井盖下沿外侧落地，检查地板、实际玩家碰撞形状及敌人占位；被阻挡时留在原地并提示。到达口短暂打开后关闭。

解锁在本局实例中保留，死亡重试不需重开；返回标题再开始是新一局，没有新增跨程序存档。快捷通路不激活终端、不跳过最终门禁。`interaction_sheet.gd` 的 `destination_selected(token, id)` 和 payload 的 `choices`／`disable_confirm` 仅供 C 功能选择，不送给 D 剧情展示方。旧 token、未知／锁定目标与自传送均拒绝。

## 成就、素材与共享影响

完整 11 项条件见 [成就目录](c_achievement_catalog.md)。首次解锁通知、加载不重播，旧四项 ID 与 `user://achievements.cfg` 兼容；全清统计实际可击破的 10 处室内蛛网，不要求清理数百片墙外装饰网。

B 的玩家、小一动画、机械臂和战斗接口直接复用；A 的共享接点仅给 `breakable_web.gd` 加两行一次性 `broken_once(web)` 信号与发送。地图检查同步 B 新发射口并隔离成就保存，未改伤害、蛛网物理或蜘蛛行为。

门与终端使用内置 image_gen 生成的透明 PNG，完整提示词及哈希见 [素材说明](../assets/sprites/interactables/README.md)。Godot 消费端拆分门片做开合、终端叠加状态，构成 2D 可动模型，不包含 3D 网格；原 PNG 保留。围挡与管道盖复用 A 图集，按 A 的颗粒基准换算。新 UI 与机械心由 Godot 绘制；中文字体 Noto Sans SC 子集的来源、字符数与 SHA 见 `assets/fonts/gameplay_ui_source.json`，许可继续用 SIL OFL。

`project.godot`、Input Map、Autoload、碰撞层定义、公共 TileSet、`scenes/main.tscn` 与 A 的布局场景均未修改。公共文档由 C 同步；没有代发群消息。

## 验证与人工复测

Windows / Godot 4.7.2 / Compatibility：

```sh
godot --headless --editor --import --path .
godot --headless --path . --script res://tests/manual/c_progress/interaction_check.gd
godot --headless --path . --script res://tests/manual/c_progress/terminal_password_check.gd
godot --headless --path . --script res://tests/manual/c_progress/progress_check.gd
godot --headless --path . --script res://tests/manual/c_progress/duct_check.gd
godot --headless --path . --script res://tests/manual/c_progress/achievement_check.gd
godot --headless --path . --script res://tests/manual/c_progress/achievement_events_check.gd
godot --headless --path . --script res://tests/manual/a_map/web_break_check.gd
```

本地检查已通过，并在提交前从暂存树导出干净副本重验；验证结果以 PR 为准。旧 `tests/manual/gameplay/presentation_check.gd` 入口复用新交互检查，替代旧自动拾枪／死亡丢枪断言；旧终端检查继续单独保留。

覆盖真实 E 打开且不跳首句、完整推进／取消、D 展示替换、墙体与门的真实碰撞、管道双向／阻挡／旧回调、死亡保留学习与世界回滚、机械心、成就与真实脉冲破网。配置主场景由命令行启动；没有人工按键 F5 验收。实际窗口 1152×648 检查了场景设施、无目标 HUD、逐句通讯、管道菜单与成就；截图使用镜头定位和驱动事件，不作为完整徒步通关证明。

人工复测：F5 进入腹腔，探索图纸台按 E 阅读神明通讯及口令前段，回制造台装配，进入小房间阅读后段；清三台清扫者观察入口开放，终端先输入错误口令再输入正确口令，确认只有验证成功才开出口；逐点解锁管道往返；破室内网观察成就；死亡后确认能力／已读线索保留、世界恢复。

2026-11-03 C-TERMINAL-01：Windows / Godot 4.7.2 下资源导入、`terminal_password_check`、`interaction_check`、`progress_check`、`duct_check`、`achievement_check`、`achievement_events_check` 与旧 `terminal_gate_check` 全部通过；实际 OpenGL 窗口再次运行密码检查通过，并核对字体与数字键盘布局。密码检查覆盖取消／旧回调、数字与前导零、错误反馈、重试／新局以及不依赖已读数量的正确验证。仍需非作者从 F5 徒步完成路线；命令行验证不等于人工按键验收。

## 待完成

至少一位非作者实机完整路线复测、macOS／Linux 与导出包检查；D 正式台词／演出／配音／音效；受控攻击教学、正式复活点与跨房间状态保存；真实可见性、完整空间记忆／地图日志及完整 P1 联合验收。当前 `_enemy_visible_query()` 仍只是地图边界占位，不计作 VISION-04 通过。后续关卡沿用剧情传达行动的原则，本轮没有制作尚不存在关卡的完整剧情。
