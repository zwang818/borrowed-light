# A · 腹腔／制造区地图与环境交互

<a id="today-scene-update"></a>

## 第一关本轮场景更新总览

文档核对：2026-10-28；下文保留 2026-10-27 各项实现及验证记录的原日期。

A：汪哲。本次在已有第一关布局和 C 正式运行组合上完成环境美术、循环动画及用户新增的蛛网交互。当前分支 `feat/abdomen-env-art`，基于最新 `main`（`a93b7f6`，含 Bible v2.3）；已提交并发起 [PR #14](https://github.com/zwang818/borrowed-light/pull/14)，待队友复测后合入。用户已提出并推动两台风扇轴心修复，修复版仍待用户最终复测。以下为本轮实际实现，不把早期计划或局部检查当成完整 P1 验收。

下文第 8–13 节保留 2026-10-27 各项记录中的“未提交／推送”原表述，那是当时的状态快照；本轮实际提交与 PR 以本节和 Git 记录为准。

| 小交付 | 当前行为 | 主要文件（腹腔脚本均在 `scenes/levels/abdomen/`） | 核对重点 |
| --- | --- | --- | --- |
| 废土像素环境 | 冷灰绿旧金属、格栅、仪器、管线、蛛网与冷白灯具；沿用原路线 | `abdomen_graybox.tscn`、`abdomen_environment.tscn`、地板／墙面绘制脚本；7 张环境 PNG | 主路、制造室支路及门后落点可往返，主体可辨认 |
| 出生区机械臂 | 下探焊接、换位、复位，默认 6.4 秒循环 | `abdomen_welding_station.gd/.tscn` | 台面固定、臂段相连、冷白焊点及火花 |
| 出生区压缩机 | 4 秒循环，风扇转两圈、左右活塞交替伸缩 | `abdomen_compressor.gd/.tscn` | 转子、防护罩和风口同心；轴心已校正 |
| 墙外管线 | 默认 16 秒慢速往复／伸缩，接缝间歇排汽，各区错相 | `abdomen_cavity.gd`、`abdomen_cavity_motion.gdshader`、`abdomen_pipe_steam.gd` | 支架固定，蒸汽留在地板与墙体后方 |
| 出口前大风扇 | 默认 6 秒一圈，外框与十字防护架固定 | `abdomen_exhaust_fan.gd` | 已按源图像素重新校准轴心；其余三处小风口未改 |
| 可破坏蛛网 | 10 处室内网与背景 9 个网区×48 块；一击破坏，蜘蛛落下并快速逃走 | `breakable_web.gd`、`fleeing_spider.gd`、`abdomen_webs.gd`、`abdomen_web_catalog.gd` | 含腿宽约 20 单位，约 1.8 秒消失；一网一蛛、不计为敌人、重试恢复 |

### 本轮文件及依赖边界

- 全部环境图片及 `.import`、来源和提示摘要在 `assets/sprites/environment/abdomen/`；必要 `.uid` 随脚本保留。大风扇复用压缩机分件，轴心修复没有改图片。
- 四种循环均为自动环境表现，无交互／伤害；随正式游戏世界暂停和恢复。蛛网是本轮唯一新增的武器环境交互，依赖已有射线与 `apply_damage(amount)`，未改 B 的射击或敌人代码。
- C 的唯一代码接点是 `scenes/gameplay/abdomen_level.gd::_retry_level()` 的三行环境恢复调用；恢复蛛网、清理蜘蛛。详见 [C 接入说明](c_ui_achievements.md#abdomen-environment-retry)。没有新增成就、击杀条件、掉落物或存档格式。
- 墙体、地板尺寸、碰撞与遮光、房间／对象稳定 ID 均保留。为让枪能命中，将完全贴在斜墙内部的 ArrivalWestWeb 和 ExitWestWeb 向通路微移；具体位置见第 12 节。背景网被地板／墙遮住的命中区域被裁掉，墙仍挡枪。
- 标题窗口适配、字体导入等既有改动不纳入本 PR，继续在各自工作区独立保留；本轮场景工作不改 `project.godot`、输入映射、Autoload、主入口、玩家／敌人／枪械图像和 D 系统。OPEN-01 最终美术规格仍待定。

### 给队友的运行与验收步骤

1. **正式试玩**：打开 `scenes/gameplay/abdomen_level.tscn` 按 F6（部分 Mac 键盘用 Fn+F6）。取得脉冲枪后测试蛛网。F5 仍从标题进入已有流程。
2. **只看地图**：运行 `tests/manual/a_map/abdomen_preview.tscn`，Tab 看全图、G 显示制作标记。该入口没有正式枪械，不能用来验收打网。
3. 在出生区观察机械臂及压缩机，沿通路观察管线至少 16 秒，再观察大风扇至少 6 秒；确认两台风扇转轴不晃、防护架不转。Esc 暂停／恢复应冻结并续播。
4. 对准网丝开一枪，确认只掉一只蜘蛛，大小约为机器人头部，落地后迅速跑走；墙后目标不能穿墙击中。选择重试，确认网恢复、残留蜘蛛消失，枪／敌人／门仍按原流程复位。
5. 走完主路、制造室支路及门后落点，记录试玩者、平台、版本／提交号和实际结果。用户对轴心修正版的确认、非作者复测、Windows／导出包及整体性能验收仍待完成；没有预排后续周次。

### 本轮已有验证记录

macOS / Godot `4.7.2.stable.official.ed1daf0bf` / Compatibility。以下记录来自本轮对应改动后的实际执行；本次文档整理不冒称重新运行游戏。

| 仓库内可复现入口 | 已有结果 |
| --- | --- |
| `tests/manual/a_map/validate_abdomen.gd` | `A_MAP_V2: PASS`：路线、支路、返回、碰撞、标记关联 |
| `tests/manual/a_map/web_break_check.gd` | `WEBS: ... PASS`：10 处实际枪击、432 个背景网块、单次生成、暂停、清理、重试与敌人计数 |
| `tests/manual/b_combat/pulse_gun_check.gd` | `Laser checks: PASS`：已有射击规则回归 |
| `tests/manual/c_progress/progress_check.gd` | `RESTORE CHECKS: PASS`：已有恢复流程；后续蛛网接入后的执行通过 |
| 实际图形运行与完整循环截图 | 机械臂、压缩机、管线蒸汽、大风扇及蜘蛛落下／逃跑已检查；两台风扇分别重新校准并复查 |

检查脚本在仓库根目录用 `godot --headless --path . --script <上述脚本路径>` 执行；`godot` 替换成本机引擎路径。动画捕获脚本、PNG／GIF 留在仓库外，不是工程运行依赖，也不纳入提交。第 8 节中的首次素材替换验证为当时快照，之后增加的互动与 C 接点以本总览和第 12 节为准。

2026-10-28 提交前复跑（macOS / Godot `4.7.2.stable.official.ed1daf0bf`，任务分支已基于最新 `main` `a93b7f6`，即 Bible v2.3）：上表四个入口全部通过，另加 C 的 `tests/manual/c_progress/achievement_check.gd` 共五个检查入口通过；无界面导入无解析或缺失资源错误。四个场景（`scenes/main.tscn`、`scenes/gameplay/abdomen_level.tscn`、`abdomen_graybox.tscn`、`abdomen_environment.tscn`）在无界面模式加载各 3 帧，腹腔三个场景无错误；`main.tscn` 退出时报 2 个 ObjectDB 与 1 个资源提示，在未含本轮改动的 `origin/main` 干净副本上同样复现，与本次无关。以上均为无界面检查，不代替实际图形运行、F5／F6 试玩、Windows 与导出包验证，那些仍待用户和非作者复测。

## 历史灰盒交接说明（2026-10-20）

下方第 1–7 节保留当时的交付与验证；其中“待 B/C 接入”“未实现战斗”等只描述该历史阶段。当前正式入口已集成战斗与交互，运行和提交状态请以上方本轮总览为准。

2026-10-20 · A 地图布局交付，待用户试玩及 B/C 接入。按用户认可的纵向概念图重建，原横向房间已从当前场景替换。规则：LOOP-03、ENG-02/03/04、VISION-02/04、OPEN-01/02/08。

## 1. 当时交付了什么

由下向上：安全教学入口 → 必经取枪狭口 → 第一台清扫者的战斗区 → 机械肋骨折返通路 → 旁侧安全制造室 → 两台清扫者的出口战斗区 → 终端、门及脊柱入口落点。

制造室是一条可选支路，主路可继续向上；室内有工作台和接口图纸位置，不放敌人。图纸不是开门收集条件。图纸内容仍为 `p1_test_record` 占位，D/C 后续提供正式叙事。

本次只做地形、碰撞、遮光、候选区域和标记。三台清扫者均为位置标记；没有敌人 AI、射击、拾取、终端业务、探索记忆或房间状态提交。制造室的 `safe_zone` 等字段只是给 B/C 的安全区声明，尚未实现敌人追入限制或伤害豁免，不能称真实战斗安全区已验收。清扫者攻击形式仍按 OPEN-02 待定。

## 2. 打开与操作

1. 在包含本次地图改动的仓库副本中，用 Godot 导入根目录的 `project.godot`。本轮工作分支为 `feat/a-graybox`，尚未合入时不能只拉取 `main` 就期待地图存在。
2. 打开 `res://tests/manual/a_map/abdomen_preview.tscn`，运行当前场景（通常 F6，部分 Mac 键盘需 Fn+F6）。F5 仍是标题入口。
3. 若快捷键没有触发，在编辑器使用“运行当前场景”按钮；也可以在项目根目录通过下面的命令独立启动。无需修改主场景，不依赖仓库外的启动脚本。

```sh
godot --path . res://tests/manual/a_map/abdomen_preview.tscn
```

命令中的 `godot` 需要已加入 PATH；否则使用本机 Godot 可执行文件的完整路径替代它。编辑布局时打开地图源场景；试走时打开上述预览场景。

| 按键 | 测试用途 |
| --- | --- |
| WASD / 方向键 | 仅移动和碰撞的角色替身 |
| Tab | 默认角色跟随 ↔ 全图检查 |
| P | 从任意位置切换顶端测试门；门洞有人时不关闭 |
| L | 明亮 ↔ 灯光阴影检查；不包含探索记忆与真实可见性 |
| G | 摆放标记、标签、预览路线开关 |
| R | 回底部出生点 |

P 不是终端交互，也没有击杀条件。测试门仅在 `tests/manual/a_map/` 内存在，不能与 C 的真实门重复实例化。两组绿色往返标记不是已实现的传送系统。

## 3. 如何在编辑器调整

地图源文件：`res://scenes/levels/abdomen/abdomen_graybox.tscn`。布局保存为正常场景节点，运行时不会自动重造地图；不需要执行生成脚本。

| 节点 | 操作及含义 |
| --- | --- |
| `Floors/*` | 拖位置、改 `Size`；是地板可视范围，不产生碰撞 |
| `Walls/Boundary*` | 外边界墙，拖位置、改 `Size`；碰撞和遮光矩形同步 |
| `Walls/TeachingBaffle` | 出生后先绕过的横挡板 |
| `Walls/FirstCombatScreen` | 取枪之后的隔挡，先见转角再见第一敌人 |
| `Walls/WorkshopBench` | 制造室中置物工作台的实体占位 |
| `Walls/ExitMachine` | 出口战斗区中央的机械基座占位 |
| `Walls/*Chamfer*` | 斜角墙，使用 Polygon2D 顶点工具调整，碰撞和遮光多边形同步 |
| `Markers/*` | 物件位置与配置，不是正式实例；原点是占地中心 |
| `Rooms/*` | 三个逻辑房间的多边形数据；没有触发器业务 |
| `ExplorationRegions/*` | 18 个候选分区，C 仍须做遮挡及可见性判定 |
| `GuideLabels/*` | 六个概念分区的预览标签锚点 |
| `RouteWaypoints/MainRoute/*` | 黄色主路线的可拖动参考点，包括到终端再返回出口的路线 |
| `RouteWaypoints/WorkshopRoute/*` | 制造室支路的可拖动参考点 |

先只改一处，再保存并重新运行预览。比如调 `TeachingBaffle`，检查能否从两侧绕过；调 `WorkshopBench`，检查角色能站到图纸前。改变房间轮廓时需一起调整地板、外墙、Rooms 和 ExplorationRegions；移动路线点只改变制作引导，不会自动改变墙体。

保持地图根与各数据容器的变换为默认值，位置优先整格吸附。临时尺寸仍见 Bible 04，参考代码为 `graybox_metrics.gd`。新出口朝上，`Markers/Door` 的 `Footprint.x` 是门洞净宽、`.y` 是门厚；预览测试门读取该标记的尺寸。没有确定正式贴图、瓦片、角色画布或分辨率。

## 4. C 读取的字段与布局迁移

地图根：`schema_version = 1`（字段结构未变），`layout_revision = 2`（新布局），`graybox_only = true`，`map_bounds` 提供全图检查范围。地图的运行入口不引用任何 B/C 尚未交付的场景。

只读取本地图 `Markers` 的直接子节点；不扫描全树重复生成。位置取 `map.to_local(marker.global_position)`，不要将窗口坐标或运行父节点坐标混入。

| 字段 | 约定 |
| --- | --- |
| `object_id` | 唯一稳定 ID，复制后必须修改 |
| `object_type` | `spawn / weapon / cleaner / sentry / log / terminal / door / light / exit`；此地图不再放 sentry |
| `room_id` | 与 `Rooms/*` 的元数据一致 |
| `footprint` | 标记中心处的占地／出口范围参考；不自动产生碰撞、交互或伤害区 |
| `content_id` | 武器或日志内容 ID |
| `linked_ids` | 终端关联门及灯的 ID；A 只配置关联 |
| `target_room_id / target_entry_id` | 出口目标房间和出生标记，由 C 按边界方向和成功生成结果处理 |
| `show_guide` | 制作参考外框，真实运行对象接入后关闭 |

当前三个逻辑房间：

- `p1_manufacturing_01`：教学、取枪、首战、折返通路、出口战斗区及制造室门外支路。
- `p1_workshop_01`：独立制造室，元数据 `safe_zone = true`、`no_enemy_spawn = true`、`safety_requires_runtime = true`。
- `p1_landing_01`：顶端门后的脊柱入口落点。

与旧 P1 计划的差异：固定哨机标记已由三个清扫者标记替换，这是已认可的 A 布局方案。B 原定 P1 战斗任务仍是哨机；是否提前接入清扫者需由 B/C 对齐，本次不替他们扩大任务范围。

### 与 C 接口草案的对齐事项（提交前核对）

2026-10-20 核对了 C 尚未合并的 [PR #4](https://github.com/zwang818/borrowed-light/pull/4)；本地图独立运行不依赖该 PR，也不将其中代码复制到 A 分支。C 的 `docs/interfaces.md` 与 `RoomData` 提供对象类型及配置容器，和本地图 Marker2D 字段需要一次明确转换，并非直接兼容：

| A 地图数据 | C 草案中的接入方向／待确认项 |
| --- | --- |
| `object_id`、地图局部位置 | 对应 `RoomObjectData.object_id / position`；稳定 ID 不改名 |
| `weapon`、`cleaner / sentry` | 分别转换为 `PICKUP`、`ENEMY_SPAWN`；武器 ID、敌人类型等放入 `config`，具体键由 C 汇总 |
| `door / terminal / light / log` | 转换为对应对象枚举；占地、内容与终端关联需由 C 明确 `config` 字段 |
| `spawn` 与各入口标记 | C 草案每房间仅有一个 `spawn_point`；多个 `target_entry_id` 的入口查找方式仍待 C 确认 |
| `Rooms`、`ExplorationRegions` 多边形 | C 当前区域草案使用 `Rect2`；不能仅取包围盒就视为斜角／转角无遮挡，需保留遮挡判定并确认区域转换方式 |
| 四个 `exit` 标记 | 对应两组往返出口；目标房间、目标入口与位置需一起读取 |

这只是交接差异记录，不是已实现的转换器或双方已通过的接口验收。实际转换、生成对象及安全区逻辑归 C；A 配合调整必要标记与几何，B 核对正式占地和敌人需求。

`Rooms` / `ExplorationRegions` 的点保存在节点局部坐标，容器变换保持默认。通用读取逐点用 `map.to_local(region.to_global(point))`。候选探索区不能进入一次就整区揭图，尤其需处理折返通路和斜角。

| 迁移或对象 | 本次内容 |
| --- | --- |
| `p1_player_spawn`、`p1_pulse_pickup` | 保留 ID，移动到底部教学和必经取枪狭口 |
| 旧 `p1_sentry_01` | 用户明确以清扫者概念布局替换；该标记已删除，测试与说明已同步，无已接入的正式 C 消费者 |
| `abdomen_cleaner_01` | 首战一台清扫者 |
| `abdomen_cleaner_02 / abdomen_cleaner_03` | 出口前两台清扫者 |
| `p1_record_01` | 保留 ID，移入安全制造室，`content_id = p1_test_record` |
| `p1_terminal_01` | 顶端出口终端；关联 `p1_door_01`、`p1_light_01`、`p1_light_02` |
| `p1_door_01` | 保留 ID，移到顶端朝上出口，参考占地随朝向改为横向门 |
| `p1_light_01 / p1_light_02` | 保留 ID，移到出口战斗区 |
| `abdomen_workshop_light` | 制造室灯配置标记，初始是否点亮由 C 配置；地板暖色不等于已接入灯光 |
| `p1_exit_to_landing` | → `p1_landing_01 / p1_landing_entry` |
| `p1_exit_to_manufacturing` | → `p1_manufacturing_01 / p1_return_entry` |
| `abdomen_exit_to_workshop` | → `p1_workshop_01 / abdomen_workshop_entry` |
| `abdomen_exit_from_workshop` | → `p1_manufacturing_01 / abdomen_workshop_return` |

入口与出口两侧预留了落点，C 需按穿越边界方向处理，避免靠近标记反复传送。候选区域几何已经重建，旧版仅用于测试的探索结果不可套入新版；目前没有正式存档或 C 集成数据需要迁移。若 C 的个人分支已用旧草案，应按 `layout_revision = 2` 对齐后重新验证。

最小读取示例（只读取数据，不实现 C 的生成器）：

```gdscript
var descriptors: Array[Dictionary] = []
for marker in map.get_node("Markers").get_children():
    descriptors.append({
        "object_id": marker.object_id,
        "object_type": marker.object_type,
        "room_id": marker.room_id,
        "position": map.to_local(marker.global_position),
        "footprint": marker.footprint,
        "content_id": marker.content_id,
        "linked_ids": marker.linked_ids.duplicate(),
        "target_room_id": marker.target_room_id,
        "target_entry_id": marker.target_entry_id,
    })
```

## 5. 验收记录与后续依赖

本周小交付：由用户试走并调整这一张概念版灰盒。验收路线：底部出生 → 绕挡板 → 穿过取枪狭口 → 首战标记 → 制造室门外折返进入 → 工作台前 → 返回主路 → 两次折返 → 出口双敌标记 → 终端 → 关闭门受阻 → P 开测试门 → 脊柱入口落点 → 原路返回。

自动检查入口（在项目根目录执行；`godot` 的配置同上）：

```sh
godot --headless --path . --script res://tests/manual/a_map/validate_abdomen.gd
```

2026-10-20，本机 macOS / Godot `4.7.2.stable.official.ed1daf0bf`：

- 静态场景已通过无界面编辑器导入，无解析或缺失资源错误。
- 19 个物件标记、3 个房间、18 个候选分区，ID、房间归属、终端关联和四个出口标记（制造室、门后落点各一对往返）的目标引用检查通过。
- 三台清扫者按首战一台、出口两台摆放；制造室无清扫者标记；图纸属于制造室。
- 61 段矩形墙和 4 处斜角墙的碰撞／遮光边界检查通过；外墙、教学挡板、制造室实体侧墙与关闭出口门均能阻挡测试角色。
- 以角色形状做净空检查；首战敌人到图纸位置的直线被墙阻挡。物理细网格排除取枪点参考范围后，无法从出生处到达首战区，证明枪点位于必经狭口。该范围沿用 Bible 04 的临时交互距离，并不是已实现拾取。
- 实际 CharacterBody2D 已完成主路、制造室支路、出口落点及完整返回的自动移动验证。
- 主入口另通过无界面启动检查，主场景和工程配置未变。
- Compatibility 图形运行已渲染全图、入口、制造室和转角阴影截图，人工查看中文提示、角色跟随及分区可读性。全图模式是地图制作工具，不是真实探索地图。
- 补充复查通过：实际角色走到出口终端后再回门前；Tab 全图／跟随恢复正确；门洞有人时不会关闭测试门，角色离开后可关闭并恢复实体碰撞。

提交前复查：从 Git 暂存区导出不带 `.godot/` 缓存、也不含未暂存标题主题改动的干净副本，首次导入、上述自动检查、标题主入口无界面启动，以及独立预览 Compatibility 图形启动均通过。导入后源文件与暂存内容一致，资源引用、文档链接、脚本 UID 配对和提交空白检查通过；缓存、临时恢复文件与构建产物不纳入提交。

尚未声称：真实战斗、取枪与阅读、制造室敌人行为、终端开门、可见性和记忆、房间提交、Windows、导出版本或完整 P1 已通过。图形运行通过独立启动命令验证，不将其记为编辑器原生 F6 快捷键已验证。B 核对正式角色占地，并与 C 确认清扫者接入阶段；C 汇总字段、接入生成、安全区及门／进度；D 提供真实记录与界面。A 不替代这些模块。

提交前的非作者复测仍待完成：按本节路线试走，确认主路、制造室支路和门后落点均可到达并返回，检查 P 开关门及门洞防夹，再用 L 检查转角遮光。记录试玩者、平台、版本或提交号、实际结果与待调整位置；仅预览通过不能标为完整 P1 完成。

## 6. 文件与版本边界

- 腹腔地图场景：`scenes/levels/abdomen/abdomen_graybox.tscn`；公共墙体、地板、标记与临时尺寸仍在 `scenes/levels/graybox/`。
- 角色替身、测试门、跟随／全图检查、字体子集和检查脚本：`tests/manual/a_map/`。
- 此说明、README 测试入口及 Bible 99 授权记录随本版同步；临时几何规则仍在 Bible 04。
- 原横向布局已被当前腹腔场景替换，文件名随后统一为 abdomen；不保留两套活动布局。
- 本轮仅涉及 A 地图与相关说明；已有标题未提交改动独立保留，不纳入地图提交；不改主入口、项目配置或 B/C/D 系统。
- 提交与 PR 按用户授权及仓库流程执行，以实际 Git／PR 记录为准；不直接推送 main、不强推、不自动合并。PR 提供独立入口和真实验证结果，待另一位成员复测。


## 7. 腹腔文件名（2026-10-20）

用户要求从文件名直接辨认腹腔。当前入口为 `scenes/levels/abdomen/abdomen_graybox.tscn`（编辑布局）、`tests/manual/a_map/abdomen_preview.tscn`（独立运行）和 `tests/manual/a_map/validate_abdomen.gd`（检查）。对应预览脚本与 `.uid` 成对更名，本说明改为 `docs/abdomen_map.md`。公共灰盒组件保留通用命名；房间／对象稳定 ID、布局和玩法没有变化。README、分工表的入口路径及 Bible 引用已同步，不保留旧路径的第二份活动场景。

## 8. 腹腔环境美术初版（2026-10-27）

本周小交付：将用户认可的冷色科技废土像素风做入现有第一关，供用户逐处调整。保留布局 v2、32 世界单位换算、现有角色占地和摄像机；不将本版纹理尺寸当作全项目最终瓦片规格。整套最终规格 OPEN-01 继续待定。

### 文件与运行入口

| 文件 | 本轮内容 |
| --- | --- |
| `scenes/levels/abdomen/abdomen_graybox.tscn` | 仍是唯一布局源场景；地板及矩形墙换为环境绘制脚本，机械基座增加美术子节点，实例化 Environment；不改位置／尺寸／碰撞／遮光／房间及对象 ID |
| `scenes/levels/abdomen/abdomen_environment.tscn` | 可单独编辑的背景、仪表柜、管道、工具箱、蛛网、碎片、冷白灯具与地面装饰 |
| `abdomen_floor_art.gd`、`abdomen_wall_art.gd` | 位于上述腹腔目录；继承原灰盒组件，保留 Size 编辑方式及原碰撞／遮光生成，仅替换绘制 |
| `abdomen_prop.gd`、`abdomen_cavity.gd`、`abdomen_pixel.*` | 同目录；物件裁切、暗管线背景、环境专用像素整理；不供角色或 UI 使用 |
| `assets/sprites/environment/abdomen/` | 首批三张环境源图；当天后续加入设备分件、蜘蛛和补底图，共 7 张 PNG，含必要 `.import` 及来源说明 |
| `tests/manual/a_map/abdomen_preview.tscn` | A 独立预览入口未改名；默认隐藏制作引导，G 开关、Tab 全图、P 测门仍可用 |
| `scenes/gameplay/abdomen_level.tscn` | 正式试玩入口未改文件；同一地图实例自动显示新美术，保留队友所有玩法 |

实际灯具与少量冷色光池是环境视觉表现，**不提供当前可见性、探索记忆或终端控制灯的业务接口**。没有增加或修改 PointLight2D、CanvasModulate、战斗预警、伤害区和角色材质。环境碎片与油污可走过，大型实体机器只覆盖原有碰撞基座；墙外管线不是新通路。

制作标记仍保留全部字段，但 `show_guide` 默认关闭；A 预览按 G 可恢复全部标记和标签。正式运行时不再显示地图自带的制作外框。

### 初学者调整步骤

1. 先打开 `tests/manual/a_map/abdomen_preview.tscn` 运行当前场景，Tab 看全图、WASD 试走。想同时试战斗，运行 `scenes/gameplay/abdomen_level.tscn`；F5 仍从标题进入。
2. 调仪表柜、蛛网、灯具或碎片时，打开 `abdomen_environment.tscn`，在 `Decor` 中一次选一个节点，改 Position、Rotation 或 Draw Size。静态物件的 Atlas Cell 对照素材目录 README 的 0–15 编号；蛛网已改用独立脚本，不再设置 Atlas Cell。动态大风扇的速度见第 13 节；支持 Mirror X 的物件可左右翻转。
3. 调主机／工作台美术时，在布局源场景的 `Walls/AssemblyBase`、`TeachingMachine`、`WorkshopBench`、`ExitMachine`、`ExitSideMachine` 下选 `EnvironmentSkin`。它们随原基座移动；静态物件的 `Fit Parent Wall` 按现有实体占地适配，AssemblyBase 的焊接动画和 TeachingMachine 的压缩机动画自动适配。只想换外观不要改基座 Size。
4. 调地板时选 `Floors/*` 的 Surface，区分普通金属板、格栅、制造室和门槛。不要把地板改为墙体，也不要拿装饰代替碰撞。
5. 保存、重新运行，检查机器人能否看清、交互点是否遮挡、主路／制造室能否往返，再决定下一处细节。无需执行生成脚本。

### 首次美术替换的本机验证（不含后续互动）

以下是当天首次美术替换时的结果；后来增加的 C 重试接入和两处网位置调整见总览及第 12 节。

2026-10-27，macOS / Godot `4.7.2.stable.official.ed1daf0bf` / Compatibility：

- 素材无界面编辑器导入通过，没有新增解析、缺失资源或着色器错误；三张纹理保留无损导入及必要 `.import`。
- 原 `validate_abdomen.gd` 通过：19 标记、3 房间、18 候选分区、61 矩形墙与 4 斜角，碰撞／遮光相等，完整主路、制造室支路及门后落点可返回。
- 与最新 `main` 基线逐节点对比：176 个原节点的所有几何、稳定 ID、关联及目标字段一致；只变绘制、制作引导和美术元数据。
- 现有 C `progress_check.gd` 输出 `RESTORE CHECKS: PASS`，覆盖暂停／恢复、死亡选择与房间重试等现有流程。该检查退出时的 5 个 ObjectDB／1 资源提示，在未经美术修改的同一 main 干净副本上也可复现；本轮未改 C 系统或宣称修复该提示。
- 实际图形运行渲染全图、出生区、枪架、制造室和出口区，检查源图透明边缘、工作台图纸、冷色灯具、可走区域与主体可读性。临时截图及验证脚本保存在仓库外，不作为项目资源。
- 原有标题窗口适配的四个未提交文件及原两份字体导入配置 SHA-256 未变；`project.godot`、主场景、玩家、武器、敌人和 `scenes/gameplay/` 在该首次美术阶段没有差异；后续蛛网任务仅增加 C 重试处三行调用。

仍待用户逐处调整和队友复测；未宣称最终美术定稿、真实视野完成、Windows 或导出包已验证。本轮留在本地 `feat/abdomen-environment-art`，未提交、推送或合并。


## 9. 出生区左侧自动焊接（2026-10-27）

本次小交付仅将 `Walls/AssemblyBase/EnvironmentSkin` 换为 `abdomen_welding_station.tscn` 实例；脚本为同目录 `abdomen_welding_station.gd`，源素材为 `assets/sprites/environment/abdomen/welding_station_parts.png`。台面固定，上臂与前臂联动，约 6.4 秒完成“待机 → 下探 → 第一段焊接 → 抬起换位 → 第二段焊接 → 复位”，以每秒 12 次姿态更新保持像素动画节奏。

- 自动播放，无交互、声音、伤害、任务或灯光业务接口；冷白焊点和少量火花只作为环境视觉。
- 原基座位置、128×96 占地、碰撞和遮光保持不变；玩家、武器、清扫者及 C/D 系统未修改。
- 运行 `scenes/gameplay/abdomen_level.tscn`（F6）即可在出生点左侧看到动画；独立地图预览也会播放。只打开布局而不运行时默认显示待机姿态。
- 调整参数：在实例上改 `Animation Speed`（默认 1，调大加快）、`Welding Sparks`（焊光火花开关）、`Preview In Editor`（是否在编辑器内播放，默认关闭）。选中 EnvironmentSkin 即可查看这些属性；不要修改基座碰撞来调动画。
- 本机 Godot 4.7.2 实际场景检查通过：自动推进、暂停冻结、恢复续播、首尾姿态连续、活动焊头在台面范围内、碰撞资源固定及玩家贴图保持不变；渲染完整循环检查关节衔接。原地图验证脚本再次通过。

仍待用户检查动作节奏；本次仅本地修改，未提交或推送。后续其他设备逐件处理。

## 10. 出生区压缩机自动运转（2026-10-27）

本次仅将 `Walls/TeachingMachine/EnvironmentSkin` 换成同目录 `abdomen_compressor.tscn` 实例，逻辑在 `abdomen_compressor.gd`，使用独立 `compressor_parts.png`。外壳、风扇防护罩及底座固定，六叶风扇持续转动，两侧活塞反向往复。一个完整循环 4 秒，每秒更新 24 次姿态；默认风扇转两圈，活塞完成两次往复。

- 无交互、声音、伤害、任务或进度逻辑，随游戏世界暂停及恢复。
- 基座仍为 `(832, 2368)`、128×128，占地、碰撞和遮光不变；上一项焊接动画、机器人及其他设备保留。
- 运行 `scenes/gameplay/abdomen_level.tscn`（F6），出生区右侧即可看到；A 独立地图预览同样自动播放。
- 选中 `TeachingMachine/EnvironmentSkin`，`Animation Speed` 调整整体速度；`Preview In Editor` 控制编辑器中是否播放，默认关闭。仅调外观时不需要修改基座 Size。
- 本机实际场景检查通过：自动播放、暂停冻结与恢复续播、循环首尾、固定碰撞及玩家原贴图；完整循环渲染检查转子、防护罩和活塞槽的遮挡关系，地图原验证脚本通过。

素材来源及提示摘要已同步；当前为本地可调初版，待用户检查动作节奏，未提交或推送。

### 压缩机风扇轴心校正（2026-10-27）

压缩机中间的风扇也复用了旧分件坐标，出现相同偏心。现按 PNG 实际像素分别标定叶片轴承和防护罩孔位，并将机身风口轴心换算到原底座绘制区域，两者共用同一个绘制中心；防护罩等比缩放。机身及两侧活塞的裁切、行程、速度保持原样。实际渲染完整 4 秒循环（风扇两圈），检查不同角度的轴心及固定罩；自动播放、暂停恢复、循环衔接、原碰撞和玩家贴图检查通过。仅改 `abdomen_compressor.gd` 的风扇绘制与本说明，未改其他设备或素材。

## 11. 墙外管线慢速循环（2026-10-27）

沿用 `Environment/ServiceCavity` 和原 `service_cavity.png`，只修改背景绘制。`abdomen_cavity.gd` 驱动独立 `abdomen_cavity_motion.gdshader` 和 `abdomen_pipe_steam.gd`。不移动整张背景，不增加可行走面积、实体物理或交互逻辑。

- 默认 16 秒一轮：选定管身小幅往复滚动，波纹伸缩节上下收缩；夹箍、支架及贴图边缘固定，各区使用不同起始相位。
- 接缝间歇排出灰青色像素蒸汽，每次释放后逐渐上升、散开并消失，随后长时间静默。蒸汽和管线均在 z=-20 的背景层，由地板和墙体遮挡；不遮住走廊或改变视野系统。
- 自动循环且随世界暂停／恢复。使用脚本传递时间，不依赖暂停时仍可能前进的着色器 TIME。
- 调整时打开 `abdomen_environment.tscn`，选 `ServiceCavity`：`Cycle Seconds` 默认 16，调大变慢；`Animation Speed` 默认 1；`Steam Enabled` 开关蒸汽；`Preview In Editor` 默认关闭。无需修改玩家或关卡系统。
- F6 运行 `scenes/gameplay/abdomen_level.tscn`，靠近制造室外墙等边缘观察；A 独立预览也会显示。建议至少观察 16 秒，能看到静默、排汽、消散的完整周期。

本机 Godot 4.7.2 图形运行验证通过：背景着色器编译、自动推进、暂停恢复、周期首尾一致；渲染完整 16 秒检查动作及蒸汽遮挡，同视角选定的可走地面与角色区域像素保持一致。原地图碰撞／路线检查通过。原背景 PNG、地图场景、前两项设备动画、玩家／敌人／武器与标题改动均保留。素材未新增；当前为本地可调版本，未提交或推送。

## 12. 可击破蛛网与逃跑蜘蛛（2026-10-27）

用户本轮明确要求地图蛛网成为可射击主体。此次增加环境交互，不再只是静态美术：现有武器通过 `apply_damage(amount)` 造成任意正数伤害时，蛛网立即消失并只释放一只小蜘蛛。零或负伤害不触发。蜘蛛落下后快速爬走，约 1.8 秒内淡出清理；含腿可见宽约 20 世界单位，对照当前机器人头部约 19 单位。蜘蛛不攻击、不掉资源、不作为敌人、不计入终端解锁或成就。

### 蛛网清单与摆放

10 处原独立摆放蛛网全部替换为 `Area2D`，名称保留：

| 节点 | 区域 | 当前世界位置 |
| --- | --- | --- |
| ArrivalWestWeb | 出生区西侧转角 | (248, 2134) |
| ArrivalSouthWeb | 出生区南侧 | (982, 2584) |
| WeaponWeb | 枪架旁 | (386, 1802) |
| FirstCombatWeb | 首次战斗区 | (287, 1468) |
| MiddleTurnWeb | 中段折角 | (389, 1180) |
| UpperTurnWeb | 上段折角 | (375, 822) |
| WorkshopNorthWeb | 制造室北侧 | (1151, 1401) |
| WorkshopSouthWeb | 制造室南侧 | (924, 1646) |
| ExitWestWeb | 出口战斗区西侧 | (310, 310) |
| ExitEastWeb | 出口战斗区东侧 | (991, 289) |

ArrivalWestWeb 从 (218, 2104) 向通路移动 (30, 30)，ExitWestWeb 从 (293, 293) 移动 (17, 17)：原网丝完全藏在实体斜墙内，射线先撞墙，现露出可命中部分。其余 8 处位置、原墙体和所有通路均不改。

墙外管线原图中的 9 处蛛网区域记录在 `abdomen_web_catalog.gd`；沿原背景 6 列×8 行平铺，建立 432 个背景蛛网对象，加室内 10 个共 442 个。背景蛛网保留原图外观，破坏后显露去网补底图的对应局部；原背景其他区域继续使用原 PNG。仪表内 X 形撑杆及碎屏裂纹不当作蛛网。

背景网的命中多边形扣除了地板和实体墙覆盖的部分，完全被遮住的对象不参与武器检测。墙仍然挡枪，墙外目标须有无遮挡射线才可击中，不提供穿墙清网能力。背景蜘蛛保持在背景层，进入墙／地板后自然被遮挡。

### 文件与接入边界

- `breakable_web.gd`：三角形网面命中、一次性破坏、短暂残丝与恢复。
- `fleeing_spider.gd`：四帧步态、落下、快速逃跑和淡出；前景蜘蛛只碰世界，不碰玩家／敌人。
- `abdomen_webs.gd`：环境对象装配、背景遮挡裁切、寻找可走落点、重试恢复。
- `abdomen_web_catalog.gd`：背景网区域；`abdomen_environment.tscn` 保留原节点并替换脚本。
- `abdomen_cavity.gd`、`abdomen_cavity_motion.gdshader`：仅在网区域读取 `service_cavity_clean.png`；其余原材质及慢速管线循环保留。
- 新素材 `fleeing_spider.png`、`service_cavity_clean.png` 的生成来源、提示摘要见素材目录 README。
- **B 武器、玩家、敌人代码未修改**：复用现有射线掩码 5 与 `apply_damage` 接口。蛛网是层 3／位掩码 4 的 Area2D 命中目标，但不加入 `combat_enemies`，不参加辅助瞄准。命中后继续挡住本束 0.15 秒接触窗口，0.2 秒后关闭命中，避免同一束击穿多个对象。
- **C 仅一处接入**：`abdomen_level.gd::_retry_level()` 开头调用环境的 `reset_breakable_webs()`；清理逃跑蜘蛛并恢复全部蛛网。没有重写进度、战斗计数、存档、门或终端。D 系统不改。

### 验收

F6 运行 `scenes/gameplay/abdomen_level.tscn`，取得脉冲枪后对准网丝开火：一击消失、掉一只头部大小蜘蛛并迅速逃走；重复击中不会重复掉落；暂停冻结，继续后续播；重试恢复蛛网。A 独立预览没有正式枪械，应使用正式运行入口验收射击。

自动检查入口：`tests/manual/a_map/web_break_check.gd`。本机 Godot 4.7.2 验证 10 处均有从可走地面出发的实际脉冲射线；零伤害无效、同束接触阻挡、重复伤害不重复生成、蜘蛛落点可走、背景命中不藏在地板下、暂停／清理／C 重试恢复、敌人总数及击杀计数不变均通过。原脉冲枪检查 `Laser checks: PASS`，地图通路检查通过。已实际渲染破网、落下与逃跑过程；其他武器目前未实现，仅保留同样伤害接口，不宣称验证了不存在的武器。

当前为本地修改，待用户手动复测；未提交、推送或合并。

## 13. 最后房间前的大风扇（2026-10-27）

`Environment/Decor/MiddleExteriorFan` 改用 `abdomen_exhaust_fan.gd`，位置仍为 (642, 1006)，Draw Size 仍为 144×144，原暗色调保留。仅叶片绕轴持续旋转，方形框、螺栓与十字防护架固定；默认 6 秒一圈、每秒 24 次姿态更新。原静态图集保留，活动叶片与防护罩复用已经入库的 `compressor_parts.png`，未新增图片。

无交互、伤害、碰撞或任务逻辑。其余三处小风口不在本次范围，保持原样；前面完成的设备、蛛网及蜘蛛不改。自动随世界暂停和恢复。

测试入口仍为 `scenes/gameplay/abdomen_level.tscn`（F6），在上段通路旁观察；A 独立地图预览也会播放。调整时打开 `abdomen_environment.tscn`，选 `Decor/MiddleExteriorFan`，修改 `Seconds Per Turn`（越大越慢，默认 6）；`Preview In Editor` 默认关闭，开启后可在编辑器预览。

本机实际图形运行检查通过：自动旋转、暂停冻结、恢复续播、整圈首尾姿态一致，位置和尺寸不变，节点没有新增任何碰撞或交互子节点。渲染一整圈检查外框固定、转轴对齐及防护架遮挡。仍待用户确认速度；修改留在本地，未提交或推送。

### 大风扇轴心校正（2026-10-27）

用户实测发现转子偏心。此前分件坐标混用了显示参考尺寸与源图像素尺寸，且固定罩使用裁切矩形中心作为轴心，导致叶片绕偏移中心旋转。现以实际 1254 像素图分别标定原方框、转子轴承和防护罩孔位，按各自轴心绘制并对齐到同一世界位置；不再将分件坐标乘 1254/1280。固定罩采用等比缩放，转速仍为 6 秒一圈。实际渲染完整一圈，检查 0°、90°、180°及其余连续帧，转子与防护罩保持同心；自动循环、暂停恢复检查通过。仅修正大风扇绘制，不改其他设备、素材 PNG 或玩法。

## 附录：改名后旧标签页保存失败的修复（2026-10-20）

原因：文件已改名，但此前打开的旧 `map_preview` 标签页仍保留旧地图／脚本引用；该标签页带未保存状态，直接保存会因缺失旧路径失败。仅检查磁盘新文件可运行，不能证明已打开编辑器里的旧场景已迁移。

处理：临时接回旧依赖，将未保存标签页真实另存为恢复副本并保存到项目外备份；把恢复场景的脚本路径、脚本 UID 和地图路径迁到新名称；保留场景与节点 ID。关闭已备份的旧标签页，移走临时兼容文件，重载当前工程索引，重新打开 `abdomen_preview.tscn`，通过编辑器 Cmd+S 保存，未再出现依赖错误。编辑器已切回 2D 视图显示正确地图。

当前只保留新名称的活动场景，不将恢复副本或临时兼容脚本放入工程。已有标题改动不受影响。此修复不改变布局和玩法。今后改资源名前先保存相关场景，优先通过 Godot 文件系统操作；改名后核对已打开标签页，再实际保存和运行。
