# 素材来源与许可

| 素材路径 | 来源 / 作者 | 许可与说明 |
| --- | --- | --- |
| `assets/backgrounds/title/*.svg` | 本项目，Codex 辅助编写的原创几何剪影 SVG | 标题界面占位美术，非最终像素素材；未使用第三方图片或 ImageGen |
| `assets/sprites/title/title_robot.svg` | 本项目，Codex 辅助编写的原创几何 SVG | 小机器人占位图，第二版增加金属侧面与明暗 |
| `assets/fonts/borrowed_light_title.ttf` | IPAex Gothic 003.01 的项目裁剪版 | IPA Font License v1.0；许可与替换说明在字体目录，旧最小标题资源保留 |
| `assets/fonts/noto_sans_sc_menu_regular.ttf` | Google Fonts / Noto Sans SC，400 字重，Google Fonts 文本子集接口 | SIL Open Font License 1.1；仅覆盖当前菜单所需字符与基本 ASCII |
| `assets/fonts/noto_sans_sc_menu_semibold.ttf` | Google Fonts / Noto Sans SC，600 字重，同上 | 同上 |
| `assets/fonts/noto_sans_sc_gameplay_ui.ttf` | Google Fonts / Noto Sans SC，400 字重，官方文本子集接口，2026-10-26 | SIL Open Font License 1.1，许可副本 `assets/fonts/OFL-NotoSansSC.txt`；325 个请求字符，来源 URL 与 SHA-256 见 `assets/fonts/gameplay_ui_source.json`；本轮 HUD、暂停／成就界面消费 |
| `scenes/gameplay/game_menus.gd`、`achievement_toasts.gd` 中的界面面板和菱形符号布局 | 本项目，Codex 辅助编写的代码绘制与 Unicode 文本 | 未加入第三方图片、Steam 图标或 SDK；符号字形由上述有许可记录的字体提供 |
| `tests/manual/a_map/assets/graybox_labels.ttf` | Google Fonts / Noto Sans SC，400 字重，按腹腔预览文案下载的文本子集 | SIL Open Font License 1.1；来源与下载记录见 [SOURCE.md](../tests/manual/a_map/assets/SOURCE.md)，[许可副本](../tests/manual/a_map/assets/OFL-NotoSansSC.txt)；仅供 A 地图测试，不作为 D 的正式 UI 字体 |
| `scenes/levels/abdomen/`、`scenes/levels/graybox/` 中的地板、墙体与机械物件几何占位 | 本项目，Codex 辅助编写的原创几何与布局 | 腹腔灰盒占位，未使用第三方地图贴图；不是最终环境美术 |
| `assets/sprites/environment/abdomen/terrain_atlas.png`、`props_atlas.png`、`service_cavity.png` | 2026-10-27，Codex 内置 ImageGen 生成，依据用户认可的像素腹腔概念图设计 | 当前腹腔环境美术初版；未使用第三方素材包，不标称第三方 CC0 或独占版权。来源、图集编号及生成提示摘要见 [素材说明](../assets/sprites/environment/abdomen/README.md)。角色、敌人、枪械和 UI 不在此次生成范围内 |
| `assets/sprites/environment/abdomen/welding_station_parts.png` | 2026-10-27，Codex 内置 ImageGen，以本项目生成的 `props_atlas.png` 为参考拆分重绘 | 出生区机械臂的固定台面、上臂、前臂与轴盖；来源与提示摘要见上述素材说明，未引入第三方素材包。火花由环境动画脚本绘制 |
| `assets/sprites/environment/abdomen/compressor_parts.png` | 2026-10-27，Codex 内置 ImageGen，以本项目 `props_atlas.png` 压缩机为参考重绘动态分件 | 固定机身、六叶转子、两侧活塞及固定防护罩；出口前大风扇复用转子／罩，轴心修复仅改绘制坐标。透明源图保留，来源和提示见素材目录说明，未引入第三方素材包 |
| `assets/sprites/environment/abdomen/fleeing_spider.png`、`service_cavity_clean.png` | 2026-10-27，Codex 内置 ImageGen；蜘蛛原创生成，去网补底以本项目原管线图为参考编辑 | 四帧环境蜘蛛及 9 处去网补底，不新增战斗敌人；原图保留，仅补底局部被采样。提示摘要见素材目录 README，未引入第三方素材包 |

Noto Sans SC 来源：https://fonts.google.com/noto/specimen/Noto+Sans+SC

菜单字体下载接口：https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;600 （请求中通过 `text` 选择当前文案字符，字体文件由 `fonts.gstatic.com` 提供。）

Noto Sans SC 的许可副本：`assets/fonts/OFL-NotoSansSC.txt`。

第二版标题字体 `assets/fonts/noto_serif_sc_title.ttf`：Google Fonts / Noto Serif SC，600 字重，“借光”文本子集；SIL Open Font License 1.1，许可副本 `assets/fonts/OFL-NotoSerifSC.txt`。来源：https://fonts.google.com/noto/specimen/Noto+Serif+SC 。菜单 Noto Sans SC 子集已扩展至第二版全部文案。

腹腔灰盒按已认可的概念图安排空间；概念图与用户提供的风格参考图未作为图片资源纳入工程。本表的原创几何说明仅指布局实现，不代表参考图的版权归本项目。2026-10-27 起实际地图使用上表单独记录的 AI 生成环境素材；概念图中的人物、标注与黄色路线未贴入地图。后续若将参考图纳入交付材料，需另记来源与许可。

2026-11-02 C 第一关交互：更新游戏界面 Noto Sans SC 字体子集，覆盖八个 C 运行脚本的当前字符；准确字形请求数、原始 URL 及哈希以 `assets/fonts/gameplay_ui_source.json` 为准，继续使用 SIL OFL。新交互标记、功能面板及门禁使用 Godot 几何与控件，无新增外部图片或声音。

机械心参考：用户于 2026-11-02 提供三张手机截图，仅用于满／半／空三状态示意；截图未进入工程。`health_hearts.gd` 中心形像素网格、仪表板与铆钉以及 `facility_visual.gd` 门禁／终端，均为本项目 Godot 代码绘制，无新增图片依赖或第三方图片许可。

| 素材路径 | 来源 / 作者 | 许可与说明 |
| --- | --- | --- |
| `assets/sprites/interactables/bulkhead.png`、`access_terminal.png` | 2026-11-02 本项目内置 image_gen 按用户要求生成 | 生成素材，非下载的 CC0 资产；原始 PNG 和透明通道保留。风格参考为用户提供的本项目截图，未直接复制其截图像素。完整提示词、用途及哈希见同目录 `generation_source.json`；项目消费说明见同目录 README。 |

同日后续：门禁／终端由前述原生几何表现改为上述生成贴图；管道盖复用 A 的环境地形图集井盖格，来源继续沿用该图集的既有说明。

2026-11-02 C-ACH-02：趣味成就标题、短句和进度 UI 为本项目文案与原有控件，未使用蜘蛛侠图像、品牌图标、Steam SDK 或第三方图像／音频。字体子集已补齐本轮运行文案，继续使用同目录 OFL 与来源 JSON。

2026-11-02 C-STORY-01：小一／神明通讯为按用户剧情示例编写的可替换短稿；不提取《绝区零》字体、图标或截图素材。取消目标栏后没有新增目标字体或图标资源，现有中文子集已补齐实际运行台词。

2026-11-03 C-TERMINAL-01：数字键盘沿用 Godot 控件与本项目面板样式，未引入外部图片／声音。Noto Sans SC 400 字体子集补齐密码及分段线索文案，继续使用 SIL OFL；准确来源、请求字符数与哈希见 `assets/fonts/gameplay_ui_source.json`。

2026-11-03 A-SPINE-02（历史试做）：`scenes/levels/spine/` 的破壳外皮、红色管束、卷边、阀体、背景支架，以及第二关独立预览站立替身，均由本项目原生Polygon2D／Line2D／代码绘制，Codex辅助实现。用户认可的生成概念图仅作布局参考，未作为贴图或运行依赖纳入工程；未下载第三方素材、增加图片或声音，不据此确定最终美术规格。

2026-11-04 斜向 2D 灰盒修订 4：外皮、管束、支架、风扇及活塞占位均为本项目原生2D几何绘制，无新PNG、3D模型、声音或第三方素材。此前3D尝试及其生成材质已被用户否决并移出工程，未纳入当前资产。
