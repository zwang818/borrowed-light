# 《借光》上下文交接文档

核对日期：2026-11-07（Asia/Shanghai）。项目根目录：`/Users/Admin1/projects/game/borrowed-light`。

本文依据当前工作树、Git 状态及本次对话中的明确决定编写。**当前代码基线优先于对话中的旧完成记录**；本文是交接索引，不替代 Bible，也不授权新增玩法。文中仓库内相对路径均相对于上述项目根目录。

## 1. 接手前先读：刚发生的版本回退

- 用户明确要求从 GitHub 拉取 `feat/p1-combat`，并明确说“不要保存本地相对 p1-combat 多出的部分”。
- 已成功获取远程分支，并执行 `git reset --hard origin/feat/p1-combat`。此前本地领先的 5 个提交已从当前分支移除；本次不恢复这些提交。
- 当前分支：`feat/p1-combat`；跟踪：`origin/feat/p1-combat`。
- 当前 HEAD：`f455ac3559f2b1f0d0104b9e38749615f855103d`。
- 提交说明：`feat: 优化小一动作与手臂交互，修正敌人受击范围`。
- 远程：`https://github.com/zwang818/borrowed-light`。
- 回退完成时双方 ahead/behind 为 `0/0`，工作区干净。本文创建前再次核对仍无未提交修改。本文是本轮唯一预期新增文件，尚未提交或推送。
- **不要把拉取 `feat/p1-combat` 误解为合并最新 main**。本轮没有再合并 main，未核验当前远程 main 的最新状态。
- 后期电光激光、蓄力亮核及额外模型缩放曾在对话中实施/讨论，但当前工作树没有这些新特效实现。下一次开发不能沿用旧总结声称它们已在主场景中。

## 2. 项目目标、技术栈和协作职责

四人大学游戏开发课程项目：2D 俯视角像素剧情闯关游戏。小机器人“小一”进入机械神兽营救创造自己的神明，通过探索记忆、两种内置攻击能力、维护协议与关卡交互完成流程。完整设计目标约 10–15 分钟；当前主要实现标题、开场和第一关腹腔，不能称为整款游戏完成。

- Godot：仓库 README 约定 `4.7.2.stable.official.ed1daf0bf`；本轮执行本机 `--version`，输出与之相同。
- 语言：GDScript，资源为 `.tscn`、`.tres`、`.gdshader`、PNG/WAV/字体等。
- 渲染：Compatibility / `gl_compatibility`；2D 游戏。配置中有 Jolt 3D 条目，不代表游戏改成 3D。
- 主入口：`project.godot` → `scenes/main.tscn`；无 `[autoload]` 配置。
- Git 普通素材管理；`.gitattributes` 当前未启用 LFS 过滤。不要把文档中的未来 LFS 建议当作已安装依赖。
- 未发现仓库 `export_presets.cfg`，没有已核验的正式导出流程；不要声称已有可发布构建。

| 成员 | 归属（以 docs/team_plan.md 为准） |
| --- | --- |
| A 汪哲 | 全部地图、环境美术、碰撞、遮光与摆放；统一场景风格 |
| B 傅韩鹏（当前用户） | 玩家、武器、伤害、敌人、Boss、角色素材接入及独立战斗灰盒 |
| C 林昆泽 | 探索、交互、协议、重试/进度、运行场景与集成 |
| D 蒋博宇（组长） | UI、叙事演出、字体、音效与音乐呈现 |

用户曾明确授权 B 做声音和主场景集成等局部跨模块工作；这不等于长期接管 A/C/D 所有内容。

## 3. 真实架构和目录

```text
borrowed-light/
├── project.godot、README.md、.github/pull_request_template.md
├── docs/
│   ├── bible/                       # 十文件设计与执行约束
│   ├── team_plan.md、version_control.md
│   ├── abdomen_map.md、title_screen.md、asset_credits.md
│   └── c_level_one_interactions.md、c_ui_achievements.md、c_achievement_catalog.md
├── scenes/
│   ├── main.tscn                    # 实例化标题，指定腹腔启动场景
│   ├── ui/title_screen/、ui/intro_cutscene/
│   ├── gameplay/                    # 腹腔组合、菜单、交互、成就、机械心等
│   ├── levels/abdomen/、levels/graybox/
│   ├── player/、weapons/
│   └── enemies/cleaner/、enemies/sentry/
├── assets/                         # 字体、声音、标题和环境等美术
├── tests/manual/
│   ├── a_map/、b_combat/、c_progress/、gameplay/
├── ab_test/                        # 历史 AB 集成与 combat_snapshot
└── CONTEXT_HANDOFF.md
```

README/分工中的 `scripts/`、`data/`、`scenes/runtime/`、`scenes/interactables/` 等属于建议目录，不能据此当作已实现架构；本次核对前三类相关业务实际集中在 `scenes/gameplay/` 等现有路径。

关键依赖链：

1. 标题经开场进入 `scenes/gameplay/abdomen_level.tscn`。
2. 腹腔实例化 A 的 `scenes/levels/abdomen/abdomen_graybox.tscn`；`abdomen_level.gd` 读取标记，生成玩家、敌人、交互与门禁，维护重试状态。
3. 共享玩家 `scenes/player/player.gd`；正式地图使用其子脚本 `xiaoyi_map_player.gd`。
4. B 灰盒 `combat_player.gd` 又继承 `xiaoyi_map_player.gd`，只预授予散弹测试能力，避免维护两套行为。
5. 正式地图正在直接引用 `tests/manual/b_combat/` 中的角色视觉、枪口适配、散弹弹丸和清扫者视觉。**这里不全是可删除的测试文件**；修改共享视觉会同时影响主场景，隔离试验前必须检查引用。
6. `ab_test/ab_combat.tscn` 是历史组合，不是当前 F5 主入口，不应自动同步。

## 4. 已实现功能与代码入口

本节“已实现”指本轮核对当前代码存在，不代表本轮实机或全部回归通过。本轮仅文档任务，没有启动游戏或重跑玩法测试。

### 4.1 玩家、模式和手臂

- `scenes/player/player.gd/.tscn`：CharacterBody2D 移动、鼠标瞄准、伤害、无敌时间、死亡恢复、协议禁攻击。移动速度原型值 160；斜向归一化，使用碰撞移动。
- `scenes/player/xiaoyi_map_player.gd`：主场景与灰盒共用的攻击/收手行为；`learn_pulse()`、`has_arm_module()`、`set_attack_mode()`、`get_shot_origin()` 是关键接口。
- **当前键位是 1 激光、2 散弹**，没有按 2 手动无武器或按 3 散弹的现行绑定。内部枚举仍是 LASER=1、UNARMED=2、SCATTER=3，不能把枚举数字直接解释为键位。
- 左臂激光、右臂散弹。已解锁能力和当前抬手姿态分开：`pulse_gun_equipped` / `scatter_unlocked` 表示能力，`selected_mode` 记住选择，`attack_mode` 控制表现。
- 当前屏幕内存在可见且存活的 `combat_enemies` 时抬起选中的攻击臂；不是固定半径，也不等于 C 的真实照明可见性。
- 无敌人时点击仍可抬手攻击环境蛛网；停止攻击约 2 秒后收手，记住选中的能力。能力模块收手后仍可见。
- 首次 `learn_pulse()` 有约 1.2 秒装配后观察动作；点击攻击可中断。恢复不会再次播放此动作。
- 正式关卡散弹默认未解锁，等待后续散弹进化点；B 灰盒直接解锁两种能力供测试。
- 攻击忙碌时不切模式；死亡、禁用控制、协议状态会阻止相关攻击。

视觉：`tests/manual/b_combat/xiaoyi_aim_visual.gd` 继承 `xiaoyi_combat_visual.gd`，使用 `art/xiaoyi/xiaoyi_body_rig.png` 和 `xiaoyi_arm_rig.png`。身体保持八方向，武器臂独立连续瞄准；无武器姿态随移动，攻击姿态考虑瞄准/发射方向。步态使用 `xiaoyi_gait.gdshader` 和帧动画，增强迈步而非仅整体平移。

- 激光臂长度25、其他武器臂27、普通臂21、粗细1.12为当前视觉参数。
- 手臂从肩部连接；头部独立遮挡层 `head_occluder.z_index=3`，防止枪管画到头上；不要沿用回退前总结中的 z=4。
- 角色脚底箭头用于最近敌人方向提示，不代替射击方向。
- 主场景和 B 灰盒当前 `display_height=60`。本轮查看的配置没有后期额外 `visual.scale=1.5`。
- 主场景镜头 zoom=1.5 并有跟随/平滑；灰盒镜头固定 `(480,320)`、默认 zoom=1。屏幕显示尺寸受相机影响，不要通过改镜头替代用户要求的模型缩放。

### 4.2 激光与散弹

- `scenes/weapons/pulse_gun.gd/.tscn`：IDLE → CHARGING → FIRING。
- 蓄力0.8秒；蓄力结束读取当前鼠标方向，再执行 ±10° 辅助索敌；发射后锁方向，枪口随玩家位置更新。
- 激光最大持续0.5秒；命中墙或敌人后0.15秒结束；以0.3秒参数逐渐向外延伸。
- 无反射、无20发弹夹、无旧0.3秒射击CD/5秒换弹；结束后可再次点按蓄力。
- 激光不穿墙、不穿敌人，按地图边界截止，无旧固定短射程上限；单束同一伤害接收者只伤害一次。
- `laser_trace.gd` 提供射线追踪与 `damage_receiver()` 归一化；`muzzle_pulse_gun.gd/.tscn` 让激光从左臂枪口发出，身体到枪口的阻挡检查防止贴墙穿透。
- 当前效果仍是 `Line2D` Beam/BeamCore 和 `Polygon2D` ChargeGlow；蓄力转发射时旧 ChargeGlow 隐藏。**没有新版外部电磁炮序列帧，也没有蓄力亮核延续到激光结束的后期逻辑。**
- 散弹在 `xiaoyi_map_player.gd` 和 `tests/manual/b_combat/scatter_pellet.gd`：右臂枪口、三颗、±12°、0.75秒冷却；逐颗碰撞/伤害。参数为原型，不自动宣布最终平衡。
- `assets/audio/pulse_charge.wav`、`pulse_biu.wav`、`scenes/weapons/pulse_audio.gd` 是现有激光声音相关入口。

### 4.3 敌人、生命与命中

- 参数集中在 `scenes/weapons/combat_parameters.gd`：玩家3HP、受击无敌0.8秒；哨机/清扫者各3HP（原型数值）。
- 哨机 `scenes/enemies/sentry/`：固定警戒、视线检查、预警后三连发；警戒320、预警0.75秒、弹间隔0.2秒、恢复1.25秒。弹速240、射程480、伤害1。
- 清扫者 `scenes/enemies/cleaner/`：巡逻、追击、近身停顿预警、前方攻击、恢复。巡逻48、追击120、警戒256、攻击距离52、预警0.65秒、有效攻击0.16秒、恢复0.65秒、伤害1。
- 用户明确选近身攻击，不增加第二套冲撞攻击。
- `tests/manual/b_combat/cleaner_visual.gd`：采用 A 型灰绿色机械蜘蛛侧视/斜侧视觉；步行、攻击与预警表现；血条置于模型上方。素材 `art/cleaner/side_animation.png` 等。历史深色候选素材仍存在，不代表场景同时放置两版。
- 主场景和灰盒都启用 `match_hurtbox`。`scenes/enemies/cleaner/cleaner_hurtbox.gd` + ModelHurtbox 用透明轮廓凸包适配动画帧，转发到敌人本体；移动碰撞与受击范围分开。
- 这是对“视觉模型变大但激光打不中”的已实施修正。凸包并非逐像素精确遮罩，窄缝/边缘观感仍应实机复测。

### 4.4 第一关、环境、UI与进度

- `abdomen_level.gd`：查看图纸 → 回制造台主动装配/学习 → 清扫者战斗 → 清场开放终端区域入口 → 操作终端 → 出口门。
- 终端入口门与出口门是不同对象；不能在有清扫者时提前使用终端。
- `interaction_point.gd`、`interaction_sheet.gd` 等接入通讯；剧情会暂停世界；常驻以机械心耐久为主，已取消任务目标/距离导航栏。
- 三个井盖逐点 E 解锁，已解锁点之间互传，有落点安全检查；本关实例内死亡保留解锁。
- `_retry_level()`：当前恢复到出生标记，恢复满血（当前原型实现），保留 `pulse_learned`，恢复敌人、门、终端、蛛网，清理攻击/弹丸。**新的进化点后复活点尚未实现**；不能把当前满血实现当作 Bible OPEN-05 已定稿。
- `game_menus.gd`、`pause_input.gd`、`health_hearts.gd`、`achievement_toasts.gd`：暂停/重试、机械心、成就手册与通知。当前11项成就，默认 `user://achievements.cfg` 本机保存；成就存储不是完整游戏存档。
- A 环境：地板、墙体、灰绿废土像素风、机械臂焊接、压缩机、管线蒸汽、风扇动画；`abdomen_webs.gd`、`breakable_web.gd`、`fleeing_spider.gd` 支持破网释放无伤害逃跑蜘蛛、重试恢复。
- 标题 `scenes/ui/title_screen/` 使用新版小一和 `xiaoyi_title_animation.gd` 循环动作；记忆档案入口不是已经完成的继续游戏读档。
- B 灰盒有 `combat_audio.gd`、`audio/`、`music/background_music.gd` 等声音/BGM；历史 AB 也有独立音频检查。不要将其自动整套接入主场景，主场景/标题已有自己的声音接点。

## 5. 已确认设计及覆盖关系

以用户最新明确要求优先于旧讨论，再看现行 Bible 与决策记录。历史被覆盖的要求不要复活。

1. “捡枪”已改为神明指导下学习、自我改造；左激光、右散弹体现身体进化与羁绊。保留 `pulse_gun` 等代码ID兼容，不因名称旧就批量重命名接口。
2. REV-14 覆盖 REV-13：完成进化后死亡保留能力，不重新过进化、不重播首次教学、不回原点校准。未来在进化点之后设置复活点；首次教学仍需要。
3. 身体八方向 + 武器臂独立瞄准，是为解决八向身体与连续激光方向偏差；不要无故退回整张武器贴图随身体旋转。
4. 最新1/2选择能力 + 自动收放覆盖早期1/2/3三模式。收手不等于失去能力，也不等于不能打环境彩蛋。
5. 清扫者采用灰绿色 A 型蜘蛛，侧视/斜侧而非纯顶视，动画需流畅协调；保留清楚预警及血条可读性。
6. 脉冲枪时间、无反射、末端锁向、一次伤害按4.2；旧弹夹、反弹及点按瞬间锁向均废弃。
7. Bible 十文件结构保持：`_index`、`01_core_loop`、`02_entities`、`03_rules`、`04_physics`、`05_ui_hud`、`06_audio`、`07_file_layout`、`08_naming`、`99_decisions`（均.md）。不要另造相互冲突的 Bible。
8. 叙事仍是固定线性流程，无等级/技能树/材料刷取/第三种攻击；隐藏事实与结尾遵守 `_index.md` STORY-02/04，不擅改为双意识平等共生或新结局。

Bible 中 REV-15 等历史条目还保留早期1/2/3描述，而当前代码和用户后续决定已变更；后续若专门整理设计文档需同步，**本次不修改 Bible**。

## 6. 当前任务、待做与不要误判的历史工作

### 本次任务

只编写本交接文档。已完成代码/文档/版本静态核对及本机引擎版本检查；不修改业务代码，不自动提交/推送，不运行会产生玩法状态的实机验收。没有另一个获授权正在实施的玩法任务。

### 后续建议顺序（不是擅自开工授权）

1. 接到新任务先核对 Git 和本文基线是否仍一致。
2. 若做 B 战斗试验，优先打开 `tests/manual/b_combat/combat_test.tscn`；先检查共享脚本影响主场景的范围。
3. 针对新改动运行相关检查、实机看视觉；用户确认需要时再同步主场景/AB。
4. 团队后续待完成：正式散弹进化点、进化后复活点、后续关卡/Boss、真实可见性与空间记忆、跨房间进度/完整存档、正式台词与联合验收。不能只凭存在测试或文档就宣布完成。

### 历史特效意图：当前未保留，不自动恢复

回退前用户希望：蓝白激光；充能使用“蓝白雷核放电”蓄力后半段，去掉最外围圈，保留蓝白核心；亮核先小→大，再随发射缩小，到枪口大小，与激光同时消失；覆盖枪口但不遮头。发射采用“电磁炮贯穿光束”素材，保持原伤害和阻挡逻辑。后来曾要求同步到主场景。

来源目录（对话提供，本轮未重新验证其内容或存在性）：

- `/Users/Admin1/projects/game/特效库/蓝白雷核放电-V1-256x256-Godot4/`
- `/Users/Admin1/projects/game/特效库/电磁炮贯穿光束-V6-128x128-Godot4/`
- 更早尝试：Downloads 中“电光冲刺拖尾 V2-128x128-Godot4”“雷电蓄能球-V1-128x128-Godot4”。

当前没有 `tests/manual/b_combat/art/electric_laser/` 和 `electric_laser_visual.gd` 等实现。后续若用户要求继续特效，再核验素材并重新确定工作范围；此前“同步成功”的历史描述不代表当前状态。类似地，回退后的灰盒未保留额外1.5倍模型缩放，不要把本轮版本回退当作继续执行旧缩放任务。

## 7. 已知问题、限制及排查结果

| 事项 | 当前证据与状态 |
| --- | --- |
| GitHub 网络 | 先报 `Could not resolve host: github.com`，联网重试报 `Recv failure: Operation timed out` 和 `Operation too slow. Less than 1 bytes/sec transferred the last 20 seconds`；最后重试成功并已对齐远程。未证实具体网络/代理根因，不应再说拉取未完成。 |
| 设计文档滞后 | 早期三模式键位、原型状态等历史记录仍在；当前实现与后续用户决定见本文件，需专项同步时再改。 |
| 测试目录被正式代码依赖 | 实际存在，不是清理建议；删除/改名会破坏主场景。 |
| 显示与瞄准 | 独立臂和头部遮挡修正已在代码；肩点、八向切换、贴墙枪口和模型边缘命中仍需当前版本实机验收。 |
| 环境像素密度 | 文档说明地板/墙/静态物件已统一当前试做基准；设备/蛛网仍保留原生细度，不等于全部素材已统一。 |
| 重试与存档 | 当前本关重试与成就保存，不是设计要求的全套复活点/跨房间/跨程序存档。 |
| 测试日志历史警告 | 前序工作曾出现 ObjectDB/resource 退出泄漏警告、macOS证书/用户设置保存权限警告；不能当作本轮新错误或已修复。新运行时记录完整输出，区分沙箱环境与真实断言失败。 |

仍待定规则见 `docs/bible/99_decisions.md`：OPEN-01完整美术规格/导出验证，OPEN-04协议首次攻击输入，OPEN-05维修/复活恢复量，OPEN-06部分界面暂停与散弹持续输入策略，OPEN-07最终数值，OPEN-08最终日志/布局/素材。清扫者近身攻击与死亡不重新校准已确认，不再当未定问题反复问。

## 8. 用户偏好、范围限制和协作要求

- 中文沟通，解释具体，保持原来的实现思路，不无故重写完成代码；改完检查并运行适合改动的测试，诚实说明未验证项。
- 用户做 B，希望模块独立、可在灰盒测试，不依赖 A 先做完整地图；A 统一正式地图风格。
- 未授权不要改地图布局或其他成员系统。明确要求“只文档”时只改文档。
- 默认在 B 灰盒迭代；主场景、`ab_test/ab_combat.tscn` 的同步必须符合当轮要求，不能一次自动扩散到所有场景。共享脚本需特别留意。
- 主场景不要因 B 模型/特效改动额外加入 BGM 和整套声音；保留现有成员接入，禁止把旧要求理解成删掉已有声音。
- 修改模型大小不能偷偷改相机；动画要看得出迈步、关节动作，不只平移贴图；手臂不能盖头、不能残留第三只手。
- 废土像素风，适配灰绿地图；脚步要像机器人踩金属格栅，有摩擦/零件声，避免电子提示音、沉闷或过响。当前不是再次修改音量的授权。
- 可对真正未确定的玩法提简短选择题；普通实现细节不要反复索要许可。
- Git：功能分支提交，PR由其他成员审核后合并main；不要直接推main、自动合并、自动群发。约20字提交文案和口语化群消息是常见后续请求。
- 本次丢弃本地5个提交是明确的一次性授权，不代表未来可无条件reset/清理未提交工作。
- 共享 `project.godot`、Input Map、Autoload、碰撞层、公共TileSet、`scenes/main.tscn` 由协作规范约束；同一场景避免多人同时编辑。不要升级引擎、切渲染器或引入大框架。

## 9. 运行、测试与构建

本机 Godot 可执行文件：`/Applications/Godot.app/Contents/MacOS/Godot`。

```sh
cd /Users/Admin1/projects/game/borrowed-light
# 编辑器，F5标题→开场→腹腔
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .
# B灰盒（Godot编辑器打开此场景可F6）
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/manual/b_combat/combat_test.tscn
# 直接进入正式腹腔
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/gameplay/abdomen_level.tscn
# 首次导入/必要时资源检查
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path . --quit
# 示例：SceneTree检查脚本
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/manual/b_combat/graybox_sync_check.gd
```

B灰盒：WASD/方向键移动，鼠标瞄准，左键攻击，1激光，2散弹，R重置，P注入测试协议。P是灰盒调试，不代表正式关卡协议最终操作。灰盒全亮可见性适配器不等于迷雾系统。

已有检查入口（按任务选择，不必每次全跑）：

| 范围 | 路径/脚本 |
| --- | --- |
| 移动与基本战斗 | `tests/manual/b_combat/movement_check.gd`、`pulse_gun_check.gd`、`health_sentry_check.gd`、`cleaner_check.gd` |
| 独立手臂与枪口 | 同目录 `independent_arm_check.gd`、`muzzle_check.gd`、`xiaoyi_animation_check.gd`、`attack_modes_check.gd` |
| 主场景行为/探索攻击/受击范围 | 同目录 `main_auto_mode_check.gd`、`exploration_attack_check.gd`、`cleaner_hurtbox_check.gd`、`graybox_sync_check.gd` |
| 声音 | 同目录 `audio_check.gd`、`music_check.gd`；AB有独立对应脚本 |
| 地图与蛛网 | `tests/manual/a_map/validate_abdomen.gd`、`web_break_check.gd`；预览 `abdomen_preview.tscn` |
| C进度交互 | `tests/manual/c_progress/progress_check.gd`、`interaction_check.gd`、`duct_check.gd` |
| 成就 | 同目录 `achievement_check.gd`、`achievement_events_check.gd` |
| 集成表现与终端 | `tests/manual/gameplay/presentation_check.gd`、`cleaner_visual_check.gd`、`terminal_gate_check.gd` |

这些 `extends SceneTree` 的脚本用 `--script`，不是F6。部分底层战斗测试使用 `manual_modes_fixture.gd` 手动设置姿态，不应把测试替身装进正式游戏。C测试会用隔离 `user://test_*.cfg`，详见 `tests/manual/c_progress/README.md`，不要清空玩家真实成就文件。

检查不仅看退出码，还看 PASS、断言、解析错误和资源错误。视觉任务必须实际看迈步、朝向、枪口、遮挡、预警和血条；headless不能证明视觉正确。前序对话中的通过记录仅代表当时工作树，尤其回退前的新特效测试不能用于证明当前版本。

图形启动可能需要运行环境额外权限；无界面下用户目录写权限/证书错误需要单独判断。导出尚未核验：先由团队确定平台、安装对应导出模板并维护预设，再记录实际构建命令，不虚构 `--export-release` 预设名。

## 10. 下一位开发者开工检查清单

1. 先读当前 `git status --short --branch`、HEAD及用户最新任务；不要直接照历史要求恢复已丢弃内容。
2. 读 Bible `_index.md`、相关模块和99待定项；核对现行代码与历史记录差异。
3. 确认改动入口是 B 灰盒、正式腹腔还是历史 AB，检查共享脚本/资源引用。
4. 不把旧附图的临时路径当永久资产；优先仓库素材及其README。外部原始方案与修改建议曾来自微信临时路径，本轮未重读，不假装已逐字核验。
5. 记录实际改动、测试命令/结果和未验证项；不要将“能启动”写成完整通关/团队验收。
6. 不改本次范围外文件，不自动提交推送。若后续更新本文，刷新日期、HEAD、工作区和验收记录，避免旧状态继续误导。

本文本轮核验范围：Git状态、目录/关键代码、README/Bible相关记录、协作及测试说明、Godot版本。未进行游戏运行、视觉验收、完整测试套件、导出或远程PR检查。

## 2026-11-14 主流程接入补充（优先于上文旧快照）

已按用户要求将第一关通关后的视频 → 原 Loading → 第二关美化地图串联，并同步最新 B 灰盒角色/敌人行为。正式入口为 `scenes/gameplay/spine_level.tscn`，详细范围、存档、验证及尚未实现的 Bible 跨关制造流程见 `docs/spine_runtime_integration.md`。第一关通关存档现在可从标题继续第二关。当前工作区有大量此前未提交素材/脚本，请保留；未提交或推送。
