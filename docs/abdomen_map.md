# A · 腹腔／制造区概念版灰盒 v2

2026-10-20 · A 地图布局交付，待用户试玩及 B/C 接入。按用户认可的纵向概念图重建，原横向房间已从当前场景替换。规则：LOOP-03、ENG-02/03/04、VISION-02/04、OPEN-01/02/08。

## 1. 现在交付了什么

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


## 8. 改名后旧标签页保存失败的修复（2026-10-20）

原因：文件已改名，但此前打开的旧 `map_preview` 标签页仍保留旧地图／脚本引用；该标签页带未保存状态，直接保存会因缺失旧路径失败。仅检查磁盘新文件可运行，不能证明已打开编辑器里的旧场景已迁移。

处理：临时接回旧依赖，将未保存标签页真实另存为恢复副本并保存到项目外备份；把恢复场景的脚本路径、脚本 UID 和地图路径迁到新名称；保留场景与节点 ID。关闭已备份的旧标签页，移走临时兼容文件，重载当前工程索引，重新打开 `abdomen_preview.tscn`，通过编辑器 Cmd+S 保存，未再出现依赖错误。编辑器已切回 2D 视图显示正确地图。

当前只保留新名称的活动场景，不将恢复副本或临时兼容脚本放入工程。已有标题改动不受影响。此修复不改变布局和玩法。今后改资源名前先保存相关场景，优先通过 Godot 文件系统操作；改名后核对已打开标签页，再实际保存和运行。
