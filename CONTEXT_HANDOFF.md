# 借光 · 项目上下文交接

> 2026-11-17（Asia/Shanghai）更新。项目延续开发，用户从本次交接起改任成员 C，负责交互与关卡进度。范围仅为此文档。本次核对了工作树、Git 引用、项目配置、设计文件与已有测试记录。
>
> 文中“已接入”表示当前分支的代码连到了所述入口。“已有验证”指注明来源的历史实测或日志。“设计已定”“地图预留”“待验证”分别表示尚需实现、已有几何或标记、尚缺对应验收。本次没有重跑游戏流程。

## 1. 项目目标、技术栈和分工

《借光》是四人课程项目，采用 2D 俯视像素画面。小一返回机械神兽，沿途探索、学习使用脉冲和散射臂、理解维护协议，并前往意识核心营救神明。目标流程为荒原开场 → 腹腔制造区 → 脊柱输能区 → 胸腔 → 核心监护者与同步 → 荒原结尾，完整游玩预算 10–15 分钟，待完整试玩计时。

- Godot `4.7.2.stable.official.ed1daf0bf`，以本机 `/Applications/Godot.app/Contents/MacOS/Godot --version` 和 README 为依据。GDScript、`.tscn`、`.tres`、`.gdshader`；2D 使用 GL Compatibility 和 `canvas_items` 拉伸。F5 主入口 `res://scenes/main.tscn`。工程配置无 Autoload。仓库用普通 Git 管理资源，`.gitattributes` 设置 LF，当前没有 LFS 过滤规则。
- 人员历史名单见 [团队计划](docs/team_plan.md)。A 负责地图、美术与地形碰撞，B 负责小一、武器、敌人与战斗，C 负责交互、门禁、协议、重试、存档和正式关卡装配，D 负责叙事、视觉表现、音频及协调。用户当前接手 C；此前用户参与的 B 工作按既有成果保留。此交接只更新用户当前负责的工作，项目名单仍查团队文件。
- 玩法与设计以 [Bible 总览](docs/bible/_index.md)、[各关游玩流程](docs/bible/09_level_flow.md)、[规则](docs/bible/03_rules.md) 和 [决策记录](docs/bible/99_decisions.md) 为准。判断是否已接入时先看所处分支的代码与资源，验收以相应运行结果为准。

### 目录与装配关系

| 路径 | 职责 |
| --- | --- |
| `project.godot`、`scenes/main.tscn` | 共用工程配置、F5 标题入口 |
| `scenes/ui/title_screen/`、`scenes/ui/intro_cutscene/` | 标题、开场、共用 Loading 与关卡进入流程 |
| `scenes/gameplay/` | 腹腔、脊柱正式包装，交互、HUD、暂停重试、成就、存档和转场 |
| `scenes/levels/abdomen/`、`scenes/levels/spine/`、`scenes/levels/graybox/` | A 的路线、碰撞、标记、关卡美术和支撑资源 |
| `scenes/player/`、`scenes/weapons/`、`scenes/enemies/` | 玩家状态、武器、清扫者、哨塔 |
| `assets/` | 像素图、字体、音频、开场与加载图、过场视频等 |
| `tests/manual/a_map/`、`tests/manual/b_combat/`、`tests/manual/c_progress/`、`tests/manual/gameplay/` | 独立地图与战斗预览、C 流程检查和正式场景回归 |
| `docs/`、`docs/bible/`、`.github/pull_request_template.md` | 玩法设计、模块文档、协作与 PR 模板 |
| `ab_test/`、`node_2d.tscn` | 旧试验与旧场景；F5 走 `scenes/main.tscn` |

正式腹腔由 `scenes/gameplay/abdomen_level.tscn/.gd` 组合 A 腹腔地图与玩家、敌人、机关。正式脊柱 `scenes/gameplay/spine_level.tscn/.gd` 继承 B 第二灰盒的装配，直接复用 A 脊柱修订 5，并接上正式交互、菜单及存档。`tests/manual/b_combat/` 中有生产依赖，包括共享角色／清扫者贴图逻辑、枪口、散弹及第二关装配。正式入口机关也继承 `tests/manual/a_map/spine_hazard_preview.gd`。移动、删除或清理预览文件前需要追踪引用，尤其用户曾要求优化第二灰盒启动速度。

## 2. 当前 Git 与接手基线

| 项目 | 本次核对结果 |
| --- | --- |
| 仓库 | `/Users/Admin1/projects/game/borrowed-light`，`origin` 为 `https://github.com/zwang818/borrowed-light` |
| 当前分支 | `feat/p1-combat`，HEAD `691e8aba617537bbb252caa542daab9167ec0b63`，提交“优化清扫者配合与寻路，重做散弹特效” |
| 跟踪分支 | `origin/feat/p1-combat` 指向同一提交，按本机引用计算领先／落后均为 0 |
| 本地 main | `bc6337dbd143f9955ac6545f8024bcd5378d0918`，距本机记录的 `origin/main` 落后 78 个提交 |
| 本机记录的 origin/main | `80cb1da6f3d72bf6470ad85a7d1f92a5a40b977e`。`HEAD...origin/main` 为 1／3。本次未 fetch，远端实时状态未核验 |
| 开始交接前的工作树 | 只有未暂存 `.gitignore` 改动，加入 `/CONTEXT_HANDOFF.md`。交接文件已被 Git 跟踪，仍会显示文档更新。保留该既有改动；本次没有暂存、提交、切分支或合并 |

**新对话先核对目标基线。** 本机 `origin/main` 包含 `5a747a5` 与 PR #36 的腹腔神明独白和交互演出，涉及 `abdomen_voice.gd`、`abdomen_level.gd`、`interaction_point.gd`、`blueprint_terminal.gd`、`exit_terminal_visual.gd`、`intro_cutscene.gd`、独白插图与监听光效。该引用内还更新了正式脊柱散弹提示。当前检出的 `feat/p1-combat` 还没有这些改动。PR #37 的合并记录包含旧提交 `1fad03e`，其父提交与树均显示当前 `691e8ab` 的寻路、协同和加大弹头等预览仍在功能分支。开展 C 工作时先比较两边对 `abdomen_level.gd`、`spine_level.gd` 的修改，核对既有独白、装配反馈和当前战斗入口，避免重复实现或遗漏分支上的改动。共同基线 `1fad03e` 已有脊柱防线、摆臂和标准新版散弹。

## 3. 当前代码已经接入的功能

### 3.1 标题、旅程、过场和加载

- `scenes/ui/title_screen/title_screen.gd` 提供单档旅程。根据当前档显示开始／继续／继续第二关；点击机器人可看记忆档案并操作存档，重新开始与删除需确认。开新旅程在关卡可用后才写入。`intro_cutscene.tscn/.gd` 处理有字幕的可推进、可跳过的开场演出。独立可行走荒原和结尾还没有相应正式流程。
- 第一关终端已激活且脚底进最终落点后，先保存 `first_level_cleared`，再由 `scenes/ui/intro_cutscene/level_transition.gd` 播放约 12 秒关际视频 `assets/video/abdomen_to_spine.ogv`，保留原声和比例。原始文件为用户给的 `微信视频2026-11-14_184325_465.mp4`，运行用仓库中的 Theora/Vorbis 文件，无额外播放插件。视频结束经过共用 Loading 进入 `spine_level.tscn`。本局转场经 `spine_entry` 携带生命与存档路径，第二关恢复激光。从标题续玩经 `journey_session` 进入，从安全入口按基线恢复。
- `entry_loading.gd` 负责线程读取、源图预热、挂场景、等待 `is_entry_ready()/get_entry_progress()`。百分比分段约为读取 0–60、预热 60–85、切换 85–88、初始化至 97、就绪帧至 100；最短展示 3 秒。覆盖层暂停期间照常更新并消费输入，失败可通过 LOAD FAILED／RETURN 返回。`loading_card_bag.gd` 用三张世界观图洗牌，`loading_robot_animation.gd` 以 14 fps 播放 8 帧跑步。`scenes/gameplay/prepared_sprite_frames.gd` 在加载阶段复用源图准备结果，切换完成后释放临时资源。初始化先后顺序涉及实际就绪，详见 [加载说明](docs/entry_loading.md)。
- `scenes/gameplay/journey_save.gd` 管理格式 1 的 `user://journey_save.json`、`.tmp` 写入校验、`.bak` 回退。进度含图纸、脉冲、已读制造室记录、探索记录、三处管道和 `first_level_cleared`、可选布尔 `scatter_unlocked`。旧档缺新字段时有兼容默认值。当前 `scene` 字段仍以首关作为格式约定，标题按通关标记路由第二关；现有格式未记录实时坐标、生命或敌人快照。F6 直进正式关卡可试交互，成功建立实际旅程存档需走标题。成就单独存为 `user://achievements.cfg`。参见 [旅程存档](docs/journey_save.md)，其中较早段落以本分支的路由为准。

### 3.2 第一关腹腔交互（C）

地图源 `scenes/levels/abdomen/abdomen_graybox.tscn`，正式运行脚本 `scenes/gameplay/abdomen_level.gd`。从 F5 开新旅程初始无战斗能力。当前分支的流程如下。

| 环节 | 实际行为与落点 |
| --- | --- |
| 出生与环境 | `arrival_gripper` 有单独演出和控制归还。近距离显示 E 提示，按实际位置与视线获取可交互物件 |
| 图纸 | `pulse_blueprint` 需在对话中确认“接入”，播放约 5 秒传输，完成后记住图纸、取得口令前段 `04`。取消可以重新阅读 |
| 制造台 | `pulse_workbench` 缺图纸时提示，拿到图纸后授予脉冲，已有能力可防重复。受控试射／完整校准待实现 |
| 制造室记录 | `workshop_origin` 为可选支路，阅读完成提供口令后段 `17`，取消不增加已读状态 |
| 清场、入口门与电闸 | 现有三台清扫者全部击败后，开放 `p1_terminal_access_gate`。终端在合法站位内第一次 E 拉闸通电并切换交互点，之后 E 才开口令界面 |
| 维护口令与出口 | `0417` 为四位知识口令，已知正确答案可直接输入；错误可改，Esc 取消。验证通过才开最终出口门。脚底到门后合法区域且终端已激活时才进关际转场 |
| 管道 | `duct_arrival`、`duct_weapon`、`duct_exit` 分别在出生、图纸和终端区；E 解锁，限第一关内已解锁目标。传送挑选可行走、无墙体或敌人占用的落点，并复位镜头、取消蓄力 |
| 探索、成就与菜单 | 探索当前记录采样过的区域；完整可见性、地图日志／空间记忆仍待做。11 项成就通过现有事件触发，无数值奖励。室内 10 处可击破蛛网计入成就，背景蛛网独立。`game_menus.gd`、`pause_input.gd`、`health_hearts.gd`、`achievement_toasts.gd` 提供相应界面 |
| 死亡和重试 | 当前实现回出生点并补满生命；保留图纸、已读内容、已学脉冲、解锁管道、已有探索和成就。重置敌人（含出口遭遇）、两道门、终端、可破蛛网及临时弹丸／交互。环境循环相位、正式进化后复活点、恢复耐久规则仍需按 Bible 和试玩确认 |

交互接口见 `interaction_point.gd`、`interaction_sheet.gd`。关卡维护 `interaction_requested(content_id, payload, token)`、`interaction_finished(token, completed)` 与 `finish_interaction(token, completed)`，只接受当前有效请求，异步完成、取消、重试和迟到回调都要考虑。`get_interaction_state()` 向展示层提供状态副本。口令权限只在 C 的 `_submit_terminal_code` 按 token、目标站位、门、通电和输入值确认。剧情播放完毕的回调只提交其对应内容。范围为 48 世界单位，终端还检查站立区与墙体视线。相关装配和反馈代码包括 `facility_visual.gd`、`exit_terminal_platform.gd`、`exit_terminal_visual.gd`、`duct_visual.gd`。详见 [第一关交互](docs/c_level_one_interactions.md)、[暂停与成就](docs/c_ui_achievements.md)、[成就目录](docs/c_achievement_catalog.md)。

### 3.3 第二关脊柱正式内容与地图预留

- `scenes/levels/spine/spine_graybox.tscn` 是 A 的斜向 2D 修订 5，复用同一套走面、点位与美术。正式场景使用美化地图并屏蔽灰盒调试操作，6 台清扫者、6 台哨塔，左臂激光已装备。正式暂停、死亡和重试已挂接。普通门的当前装配默认开放，检修暗道有独立的封板、碰撞和遮光。详见 [脊柱地图](docs/spine_map.md)、[正式接入](docs/spine_runtime_integration.md)。
- `spine_entrance_hazards.gd` 已把新版入口防线接到正式关卡与 B 第二灰盒，沿用 A 的 8 个壁挂发射口和 7 个地埋电极。小型激光球会被墙挡，电圈跟随警告和周期，保留安全凹位。两类命中均调用 `apply_damage(1)`，受既有无敌时间限制。暂停冻结，重试清理激光球与电圈命中状态、重置周期。原 `spine_electric_seam.gd` 的通电接缝也仍接入。隔离闸落下、固定封锁脉冲和首次倒下推进尚未接入。`09_level_flow.md` 5.3 的“新版火力待接入”与当前基础伤害装配有差异。
- 当前可用的 **临时** 散弹流程是靠近 `Markers/ScatterEvolution` 按 E 原地装配右臂。`try_unlock_scatter()` 位于 `tests/manual/b_combat/spine_combat_test.gd`，正式包装负责提示、保存以及重试后的保留。关卡先只有左臂；F5 旅程从标题续玩可恢复 `scatter_unlocked`，回到第二关安全入口。地图该点稳定 ID 为 `p2_scatter_evolution`，元数据 `role=blueprint`、`grants_ability=false`，正式规划要求先取图纸再返程制造。临时装配与设计的差异仍待 C 接入。
- A 预览可用 K 模拟揭示暗道，靠近 E 开盖，P 测试协议门。`set_service_passage_state()` 在地图脚本中管理 `CONCEALED`、`REVEALED`、`OPEN`，同步两端装甲件、碰撞与遮光。`tests/manual/a_map/spine_protocol_preview.gd` 包含协议段预览。正式场景尚未把预览操作串成剧情和门禁。
- C 可用的既有标记位于 `scenes/levels/spine/spine_graybox.tscn` 的 `Markers`。入口 `DefenseSafePocket`、`IsolationGate`、`MaintenanceHatch`、`MaintenanceExit`；协议 `ProtocolObservation`、`ProtocolDemoReader`、`ProtocolTerminalUse`、`ProtocolGateReader`、`ProtocolYieldRear`、`ProtocolYieldFront`、`ProtocolExit`；返程与补能 `ScatterEvolution`、`ScatterReturnEntry`、`SpinalFluidTap`、`SpinalFluidTapUse`。配对的稳定 ID、门位和净空见地图文档。可选记录支路、首台哨塔掩体与胸腔接收套筒已有位置，正式记录和胸腔出口交互尚未完成。

### 3.4 与 C 接口相关的既有 B 行为

这些是当前分支的集成基线，尤其装配、协议、死亡和换关会调用相同的玩家及敌人。

- `player.gd` → `xiaoyi_map_player.gd` → `xiaoyi_field_player.gd` → `xiaoyi_journey_player.gd`。B 灰盒角色 `combat_player.gd` 共享正式武器行为。第一灰盒预装两臂；第二灰盒初始化仅装激光，保留散弹站供流程测试。正式玩家由关卡授予能力。保留兼容用 ID `pulse_gun`。选用武器后，无可见敌人时会自动收手，玩家仍可主动发起攻击。
- 小一有八方向独立摆臂、收手与攻击姿态、贴合模型的受击区；自然行走用 `xiaoyi_scatter_pose_visual.gd` 等共享脚本，双臂以 22°／19° 交替摆动，使用局部肩点与头部遮挡。已调各向武器臂的像素位置、闲置副手和蓄力特效层级，黄色蓄力特效盖枪口并随头部遮挡。按住 Shift 疾走，松开恢复；首关及第一灰盒倍率 1.25，第二关及第二灰盒倍率 1.5，保持正常脚步节奏。灰色扬尘，已删金色擦地火花。第二关右上、左下方向按约 25° 顺着斜廊，其余场景保留常规 45° 斜向输入。
- 脉冲激光使用约 0.8 秒蓄力与枪口、墙体遮挡，之前试过的墙面反射已删除。生产及第一灰盒用 `scatter_burst_a.gd` 的单扇形 9 弹丸散弹，弹速 448、射程 128、每颗 1 点、冷却 0.75 秒，尚无脊液弹量。第二灰盒的 `hot_scatter_preview=true` 选 `spine_scatter_burst.gd`，亮芯、加法混合火焰拖尾及撞墙／撞敌不同粒子。后一次把弹头长度加到 18 视觉像素，弹丸规则沿用基类。正式 `spine_level.tscn` 显式关闭该试验开关，沿用已批准的 A 版。试验使用的 Kenney 粒子和 CC0 许可随 `tests/manual/b_combat/art/vfx/kenney_particle_pack/` 保存。
- 清扫者以屏幕内可见为发现条件；远处停下从红眼吐丝，减速约 2 秒至 60% 速度，然后继续接近；近处用既有预警近战。吐丝本身不扣血，正式持久模式速度 330，碰撞收尾。`scenes/enemies/cleaner/cleaner.gd` 与 `cleaner_pathfinder.gd` 提供带身体净空的局部路径、缓存路径和受阻／目标移动重规划。腹腔出口战斗经 `abdomen_exit_cleaner.gd` 配合，利用侧路、错开近战和远程压制，重试时恢复基线。
- 浮空哨塔球头 16 向跟踪，进入玩家屏幕进入警戒，交替使用 A/B 攻击。B 组合与正式场景使用 360 弹速、持久炮弹及放大的配套扫掠碰撞，场景墙体仍拦弹。角色协议状态通过 `has_protocol` 影响攻击／清扫者识别等公共入口。后续 C 需要限定正式区域与退出，灰盒 P 注入只供测试。

## 4. C 接手的当前计划与技术原则

已确认流程见 [09 Level Flow 第 5 节](docs/bible/09_level_flow.md)。现阶段完成了地图修订 5、基础机关伤害、第二关正式装配、临时散弹与继续旅程。下面是接手后可按任务逐段落实的顺序，目前尚未启动新玩法实现。

| 优先事项 | 目标、依赖与最小验收 |
| --- | --- |
| 1. 确认目标分支与第一关基线 | 对照 `origin/main` 的独白／交互与本分支战斗，确定后续工作的目标提交后重跑 F5、首关交互、门禁、存档转场。新任务按用户授权的分支范围推进 |
| 2. 首次倒下 → 神明通讯 → 暗道 | 正面火力的普通致死和隔离闸落下后的封锁脉冲进入同一段一次性进度。安全凹位恢复、通信能完成或按约定跳过、短暂停黑后 E 揭示后的盖板可走，暗道绕到首台哨塔前。使用 A 的地图状态接口，和 D 对接表演。验证两种触发、重试、读档、重复触发与通讯取消后的状态 |
| 3. 维护回执 → 授权门 | 观察清扫者及读头按“短、长、短”闪烁；三格拨片可选短／长，提交后读头按输入回放，答错可再试，演示可重播。校准后读头与胸灯回执，门前两只清扫者让行，跨门在掩体处退出协议。协议只对指定区的清扫者识别和授权门生效，期间禁攻；环境机关、哨塔和实体碰撞保留。OPEN-04 的首次攻击按键行为按 Bible 现有状态继续讨论。记录支路可折返，与本门无捷径 |
| 4. REV-16 图纸和跨关返程 | 图纸点只记知识。由图纸旁管道回 `p1_manufacturing_01 / duct_arrival`，在原工作台制造散射并做首次练习／校准，再回 `p2_scatter_return_entry`。保留第一关进度与原管道成就边界，不重复清场、教学或授予能力。目标落点应在基线碰撞下合法可达；目标场景就绪、安全落位后才提交跨房间进度，失败需可回退或再试。范围涉及存档兼容，以及现有临时 `try_unlock_scatter()` 的正式替代 |
| 5. 脊液补能和出口 | 返回脊柱后在取液台展示透明管／分格表，右臂每次齐射用一份有限压力，空仓需补能，左臂独立。容量、补能数量、重试剩余量同 B 对齐；UI／声音同 D 对齐。出口与胸腔加载待接入，第二关出口清场要求仍待定 |
| 6. 复活与联合试玩 | 进化后安全复活点按 REV-14／STATE-01：保留已得能力、已读及探索，房间敌人、机关、门、终端回基线，清理旧投射物、协议、回调和计时。安全落位与存档提交分开。恢复耐久按 OPEN-05 确认。实际从 F5 真人走完整第一、第二关再校准难度、时长和战斗节奏 |

已确认的边界：

- C 持有进度与权限，D 负责反馈演出。用请求 token／完成结果连接两者。播放过剧情和世界状态是独立条件，恢复时分别依据实际记录与地图／门禁状态。取消、失败和旧回调应可重试。
- 稳定对象 ID 与现有地图、存档、成就、门的对应关系继续使用。优先沿现有接口接地图标记，明确交互距离、墙体与落脚条件。跨房间进度提交需等真实到达，避免读档落墙或带入半提交的状态。
- C 已有通道、授权、进度保存逻辑可复用。正式能力授予由关卡决定，敌人和武器沿 B 的伤害、碰撞、协议接口运行。狭窄空间的墙体和遮挡同时影响站位、终端可用性与攻击表现。
- 第三关胸腔、核心 Boss／同步、可玩的荒原教学及完整结尾仍处于设计或待制作。日志数量不作结局分支门槛。叙事基线保持线性，按 STORY-02／04 保留隐藏信息和结尾语义，能力范围维持两臂。未裁定的玩法规则应留待用户及团队确认。

## 5. 已知问题、排查和验证状态

| 事项 | 结论与证据 |
| --- | --- |
| 合并后第一关卡在 88% | 已修在 `aac4097`。清扫者视觉异步帧尚未返回就进入帧缓存／碰撞配置，可见 `Out of bounds get index '15' (on base: 'Array[AtlasTexture]')`，随后有 Dictionary `index` 访问报错。`tests/manual/b_combat/cleaner_visual.gd` 等待 `_build_frames()` 后再缓存并置 `preparation_complete`；`cleaner_preparation_check.gd` 覆盖冷读和缓存。再遇 88% 时看第一条初始化错误以及就绪状态 |
| 清扫者隔墙走来回 | 本分支用路径净空及稳定路线修复此前截图中的首台清扫者横挡板、出口竖向机器两处问题。既有 `abdomen_first_cleaner_detour_check.gd`、`abdomen_exit_navigation_check.gd`、`abdomen_exit_encounter_check.gd` 与更新后的 `cleaner_check.gd` 有 PASS 日志。遮挡角落和正式地图变更后仍需实走，缓存 `origin/main` 暂无该提交 |
| 两条旧断言失败 | `tests/manual/gameplay/terminal_gate_check.gd:25` 仍以第一下 E 就开口令表单为预期，现有流程先通电。`combat_integration_check.gd:76` 直接调用出口回调时玩家脚底不在落点。两项在前序未修改基线对照仍失败，留待更新用例并重跑真实门与出口；`/tmp/borrowed-light-baseline-terminal_gate_check.log` 和 `/tmp/borrowed-light-baseline-combat_integration_check.log` 是本机临时记录 |
| 第二关启动、首次进入与渲染 | 初次资源准备较慢；旧无美术的预览切换已简化，保留生产用几何及共享依赖。`docs/entry_loading.md` 记录 Windows 实窗 5 次过场／读档／缓存进入与进度断言通过；`docs/spine_runtime_integration.md` 记录脊柱转场、存档与机关专项验证。当前交接未重新测启动耗时或导出包 |
| 字体与控制台 | 以前“继续第二关”“装配右臂散弹”有方块缺字，已补 `assets/fonts/noto_sans_sc_gameplay_ui.ttf` 游戏字库及 `gameplay_ui_source.json`。新增 C 中文文案需核对子集与实际窗口。历史日志有 ObjectDB／资源退出警告、macOS 证书 `ret != noErr` 及沙箱不可保存编辑器设置／用户数据等。记录具体报错与步骤，独立判断脚本断言 |
| 全流程验收 | 已有历史专项验证和主线场景，尚缺当前分支非作者完整手动通关、正式协议／首次倒下／跨关返程用例、后续关卡和独立导出验收。C 文档与 README 存在较老的“通关回标题”“只支持一关存档”描述，以 `level_transition.gd`、标题路由等运行代码与较新的 [脊柱接入说明](docs/spine_runtime_integration.md) 为准 |

## 6. 运行、导入和测试

在仓库根目录执行。macOS 本机 Godot 版本已核对。也可在项目管理器导入 `project.godot`，F5 走标题，F6 只跑当前打开的场景。

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --version
"$GODOT_BIN" --editor --path .
"$GODOT_BIN" --headless --editor --import --path . --quit
"$GODOT_BIN" --path . res://scenes/gameplay/abdomen_level.tscn
"$GODOT_BIN" --path . res://scenes/gameplay/spine_level.tscn
"$GODOT_BIN" --path . res://tests/manual/b_combat/combat_test.tscn
"$GODOT_BIN" --path . res://tests/manual/b_combat/spine_combat_test.tscn
"$GODOT_BIN" --path . res://tests/manual/a_map/spine_preview.tscn
```

- 常规操作 WASD／方向键，E 交互，鼠标瞄准与左键，1／2 切激光／散弹（需解锁），Shift 疾走，Esc 暂停或当前交互取消。灰盒 R 重置，P 可测试协议，部分地图有 Tab 全图。正式脊柱不开放预览键。
- `project.godot` 的 2D 碰撞层从 1 到 8 依次为 `world`、`player_body`、`enemy_body`、`player_projectile`、`enemy_projectile`、`interactable`、`hazard`、`room_trigger`。代码中的 mask 为位值，和层号区分。Shift 的 `b_sprint` 为运行时注册。
- 当前检查未发现仓库内已提交的 `export_presets.cfg` 或 GDExtension。日常“构建”检查以 Godot 资源导入、脚本加载和相应场景启动为准；发行包按团队目标安装匹配的导出模板并独立实测。视频、图像、字体、声音等已在仓库中供运行，源 MP4、外部素材包和 `/tmp` 诊断文件不构成运行依赖。素材许可查 [素材来源](docs/asset_credits.md) 和对应资产目录。

脚本多为 `extends SceneTree`，请用 `--script`。将图形和无窗口验证分开，读实际 PASS、断言、脚本和资源日志。需要等待视频自然结束的检查使用实际窗口。

```sh
"$GODOT_BIN" --headless --path . --log-file /tmp/borrowed-light-interaction.log --script res://tests/manual/c_progress/interaction_check.gd
"$GODOT_BIN" --headless --path . --script res://tests/manual/c_progress/terminal_password_check.gd
"$GODOT_BIN" --headless --path . --script res://tests/manual/c_progress/journey_save_check.gd
"$GODOT_BIN" --headless --path . --script res://tests/manual/gameplay/spine_entrance_hazards_check.gd
"$GODOT_BIN" --path . --rendering-method gl_compatibility --script res://tests/manual/c_progress/loading_cards_check.gd
"$GODOT_BIN" --path . --rendering-method gl_compatibility --script res://tests/manual/gameplay/spine_transition_check.gd
```

- C 其余专项位于 `tests/manual/c_progress/`，包括 `duct_check.gd`、`progress_check.gd`、`level_clear_check.gd`、`achievement_check.gd`、`achievement_events_check.gd`、`loading_resource_check.gd`。第二关读档 `tests/manual/gameplay/spine_save_check.gd`。A 地图的稳定 ID 与碰撞检查 `tests/manual/a_map/validate_abdomen.gd`、`validate_spine.gd`。
- 战斗改动影响接口时复测 `tests/manual/b_combat/` 的 `spine_combat_check.gd`、`scatter_burst_check.gd`、`cleaner_preparation_check.gd`、`cleaner_check.gd`、`web_attack_check.gd` 等针对项。界面重点看 E 提示、键盘路由、中文、门位置、枪口与肩头遮挡，以及暂停后的输入和动画。
- 存档测试使用 `user://test_*` 或独立测试路径。真人档案、成就、设置文件需保留。用 F5 验证真实操作，F6 和脚本有各自的入口、角色构造和状态隔离。

## 7. 开发偏好与工作约束

- 中文沟通。本项目按已有文件、约定和用户最新确认延续，代码现状优先于历史交接。用户要求先阅读、先给建议或先出多版样图时，等其选定或明确执行范围。用户亲自撤销或确认的最后版本作为下次基线。
- 用户明确要求先在第一个／第二个灰盒改时，做对应范围内的预览，正式场景同步另按指示。改共享视觉、玩家或武器脚本前查正式引用，防止引入灰盒调试和实验特效。视觉以实窗动效、像素位置、实际遮挡和贴图对齐验收；动作需逐朝向自然，改点位要区分游戏像素与放大截图像素。角色缩放按模型本身校验，相机跟随和缩放另行处理。历史试做的电光激光和额外模型缩放以现有资源及代码为准，只有新的明确任务才重新启动。
- C 优先完成交互、进度、门禁和场景接入。现有地图几何／稳定 ID、战斗数值、玩家资源、角色动画及美术／声音调整分别和 A、B、D 对齐，遵守当次用户的授权范围。`project.godot`、输入映射、Autoload、碰撞层、公共 TileSet、`scenes/main.tscn` 为团队共享配置，有实际需求时先按团队约定处理。保留 Godot 版本与 Compatibility 设置。正式关卡音频沿已有接点，灰盒试验音乐／音效的同步依本次明确范围。
- 用户要 GitHub 上传文案时给约 20 个中文字的简洁标题／提交文案和可复制的 PR 正文。按 [.github/pull_request_template.md](.github/pull_request_template.md) 的“改了什么”“对应任务 / Bible 规则”“怎么验证的”“有没有动共享文件”“截图 / 录屏”“还没做完 / 已知问题”填写，勾选真实跑过的验证，已知缺项据实列出。
- 改动按 [版本管理](docs/version_control.md) 和 PR 流程协作。先核对 Git 与待保留的改动，按用户授权执行分支、拉取、合并及上传。旧交接中的一次性强制重置属于历史操作，本次工作树和目标分支以上方 Git 记录为准。

## 8. 新对话的最短接手顺序

1. 完整读本文件，运行 `git status --short --branch` 与 `git log -8 --oneline --decorate`，核对当前任务和目标分支。需要切到团队最新代码时，先确认当前未提交改动与两边交互入口的差异。
2. 读 [09 Level Flow](docs/bible/09_level_flow.md) 第 4–5 节、[03 Rules](docs/bible/03_rules.md) 的协议与状态、[99 Decisions](docs/bible/99_decisions.md) 的 REV-14／REV-16 与 OPEN-04／05，并对照 [脊柱地图](docs/spine_map.md) 的点位和 [第一关交互](docs/c_level_one_interactions.md) 的 C 接口。
3. 从 `abdomen_level.gd`、`spine_level.gd`、`journey_save.gd` 与 `spine_entrance_hazards.gd` 看实际初始化、E 输入、死亡、恢复与保存。根据用户新下达的任务，只实现并验证授权的步骤。
