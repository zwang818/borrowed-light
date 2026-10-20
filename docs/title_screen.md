# 标题界面调整说明

当前是可替换的标题界面原型（第二版），遵循 Bible 的 UI-01、ART-01、ENG-01/02/03。背景采用代码辅助绘制的几何剪影占位素材，不代表最终像素美术。没有加入关卡、敌人或新玩法。

## 打开场景

- 保留程序入口：`res://scenes/main.tscn`。
- 美术与排版编辑：`res://scenes/ui/title_screen/title_screen.tscn`。
- 按 F5 运行项目，按 F6 可以独立预览标题界面场景。
- 编辑器若提示文件被外部修改，选择重新加载磁盘版本；如你有未保存的个人修改，先另存或比较。

## 各层怎么改

在标题场景中展开 `Presentation`。所有画面元素都是普通 Control / TextureRect / Label / Button，位置、尺寸、纹理和文字可以在检查器中调整。

| 节点 | 用途 | 美术调整方式 |
| --- | --- | --- |
| `WorldLayers/Landscape` | 天空与远中景荒原 | 替换 Texture，可用 PNG 或 SVG |
| `WorldLayers/MechanicalBeast` | 倒下的机械神兽 | 替换 Texture；拖动位置与尺寸，不影响按钮 |
| `WorldLayers/HorizonHaze` | 地平线附近的薄雾色层 | 调制颜色、透明度或直接隐藏 |
| `WorldLayers/Foreground` | 前景废铁与地面剪影 | 替换 Texture，保持透明背景 |
| `WorldLayers/RobotAnchor` | 小机器人和两层暖光的共同位置 | 移动此节点可连同灯光一起移动 |
| `WorldLayers/RobotAnchor/Robot` | 机器人占位图 | 替换 Texture；需要时调整光源相对胸口的位置 |
| `WorldLayers/RobotAnchor/LampGlow` | 胸前暖色光晕 | 编辑渐变资源与尺寸；根节点可关闭呼吸效果 |
| `WorldLayers/RobotAnchor/GroundGlow` | 脚边地面暖光 | 编辑渐变颜色、透明度与尺寸 |
| `Menu/GameTitle` | 游戏名金色正面 | 宋体字体、字号和颜色可独立调整；同时更新同尺寸的 `TitleGlow` 与 `TitleDepth1…6` |
| `Menu/TitleGlow` / `TitleDepth1…6` | 柔金光晕与侧面厚度 | 改描边透明度和偏移；保留文字一致 |
| `Menu/Tagline` / `QuoteSource` | 哲学文案与出处 | 改文本和换行；确认新字符在字体中存在 |
| `Menu/EnglishTitle` | 左下角英文水印 | 改位置、字号、透明度 |
| `WorldLayers/RobotAnchor/SaveButton` | 机器人透明点击区 | 跟随机器人位置；可键盘聚焦 |
| `Presentation/SaveOverlay` | 记忆档案弹窗 | 场景内默认隐藏，运行时点击机器人打开 |
| `Menu/Buttons` | 按钮纵向布局 | 调整宽度、位置与间距 |
| `Menu/Status` | 未接关卡时的提示 | 当前为“旅程即将启程”，配置关卡后自动隐藏 |

整体字体、按钮颜色与悬停样式在同目录 `title_theme.tres` 统一调整。开始按钮尚不可用时有独立的禁用样式，位于场景内。

## 窗口适配

`Presentation` 暂用 1280×720 的排版参考画布，运行时整体等比缩放并居中，多余区域保留深色背景。这个值只服务当前标题原型，没有修改项目全局分辨率，也没有替小组确定正式瓦片和像素规格。

在参考画布上修改排版即可。正式美术规格确定后，再统一调整设计画布、纹理与字体大小。

## 按钮行为

- **退出**：退出运行中的游戏，不退出 Godot 编辑器。
- **开始游戏**：根节点 `TitleScreen` 的 `Start Scene` 为待接入的 `PackedScene`。将真实第一关场景拖入后，按钮自动启用；点击后切换到该场景。
- 未配置第一关时，开始按钮禁用并显示提示，不放置假装进入游戏的空按钮。
- 设置与继续游戏尚未加入；存档仅有可打开的空状态面板，未实现进度读写。

## 字体与素材

本次新增的菜单字体覆盖当前标题、文案、按钮、提示和基本 ASCII，不能视为覆盖全部中文。新加中文时要重新补充字符或使用完整的许可字体。

素材来源及许可见 `asset_credits.md` 和 `assets/fonts/README.md`。当前图片是普通 SVG，占位图可以逐张替换，场景脚本不包含神兽或机器人的绘制逻辑。

## 第二版：标题、动态与存档入口

- 标题改用 Noto Serif SC 600 的“借光”子集；正面、六层侧面与一层柔光组成浅金立体字，均为可编辑 Label。
- 英文移到左下角，作为低对比水印。
- 文案为“世界的意义，必定在世界之外。”，据维特根斯坦《逻辑哲学论》6.41 英文首句自译；核对来源：https://www.wittgensteinproject.org/w/index.php/Tractatus_Logico-Philosophicus_(English) 。
- 机器人使用有明暗侧面的 SVG；`robot_motion_enabled` 可关轻微待机摆动，`robot_sway_amount` 调节幅度，暖光仍可单独调整。
- 鼠标悬停或键盘聚焦会轻微提亮机器人；点击打开“记忆档案”，关闭按钮和 Esc 均可关闭，并恢复焦点。弹窗打开时背景按钮不参与键盘导航。
- 当前只实现真实的空存档界面，没有写入或读取游戏进度。将来存档系统接入此面板，可监听 `archive_opened`；不使用虚构的可读档记录。

## 提交前与 PR 验收

1. 在 Godot 打开项目，按 F5；确认标题、哲学引句、按钮和存档文案中文完整，控制台无新增错误。
2. 打开 `title_screen.tscn` 按 F6，确认独立标题场景也能运行。
3. 调整窗口至 16:9 和 4:3，确认画面等比居中，文字、按钮和机器人入口没有超框。
4. 确认未接第一关时开始按钮禁用；退出按钮关闭游戏进程。
5. 悬停并点击机器人，确认提亮反馈、空存档面板、关闭按钮与 Esc 正常；用 Tab 检查弹窗内焦点不会进入背景按钮。
6. 需要验证接关卡时，在本地临时给 `Start Scene` 指定真实场景并检查跳转；不要提交临时测试目标或虚构的玩法场景。

已在 macOS / Godot 4.7.2 图形运行中通过字体覆盖、真实鼠标点击、弹窗焦点、关闭、缩放后点击与临时内存场景跳转检查。F5 / F6 人工验收由提交者和审阅者按上述步骤完成；Windows 与导出版本尚未验证。
