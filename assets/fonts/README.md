# 标题字体

## C 游戏界面字体（2026-10-26）

`noto_sans_sc_gameplay_ui.ttf` 是 Google Fonts 官方提供的 Noto Sans SC 400 文本子集，供 `scenes/gameplay/gameplay_ui_theme.tres` 绑定 HUD、交互、暂停、成就手册和通知。

- 许可：SIL Open Font License 1.1，沿用本目录的 `OFL-NotoSansSC.txt`。
- 来源、实际下载 URL、SHA-256 和字形请求数记录在 `gameplay_ui_source.json`；本次请求覆盖三个运行脚本中的 325 个字符及基本 ASCII。
- 原始字体来自 Google Fonts，保留其内部字体名称与版权信息；没有从用户电脑字库提取字体。
- `.ttf.import` 随源字体提交，`allow_system_fallback=false`，不提交 `.godot/imported/` 缓存。
- `tests/manual/c_progress/achievement_check.gd` 对当前三个运行脚本中的实际字符检查字体覆盖；新增中文或符号时需补齐子集并更新来源记录，再运行检查。

本主题不替换标题、开场和 A 的测试字体；它们仍使用各自已有资源。

## 当前菜单字体

`noto_sans_sc_menu_regular.ttf` 和 `noto_sans_sc_menu_semibold.ttf` 来自 Google Fonts 的 Noto Sans SC，分别为 400、600 字重。许可为 SIL Open Font License 1.1，副本见 `OFL-NotoSansSC.txt`。

这两份文件由 Google Fonts 文本子集接口提供，覆盖当前游戏名、哲学引句与署名、开始／退出按钮、存档空状态、等待提示及基本 ASCII。增加其他中文文案时，应先补字或改用完整许可字体，不依赖本机系统字体回退。

完整来源记录见 `docs/asset_credits.md`。旧标题字体继续保留，供已有引用使用。

## 原最小标题字体

`borrowed_light_title.ttf` 是从 IPAex Gothic 003.01 裁剪并重命名的字体，字体家族名为 Borrowed Light Title。包含“借光”及基本 ASCII 字符，供当前最小标题场景使用；其他中文字符需补充完整字体后再使用。

原始字体来自 japanize-matplotlib 1.1.3 源码包中的 `japanize_matplotlib/fonts/ipaexg.ttf`：

https://pypi.org/project/japanize-matplotlib/1.1.3/#files

原始字体与本派生字体均按随附的 `IPA_Font_License_Agreement_v1.0.txt` 分发。字体内保留原始版权信息。修改内容：通过 FontTools 提取所需字符，修改派生字体家族名、完整名称和 PostScript 名称。

## 替换为原始字体

1. 从上述页面下载源码包，解压并取出 `japanize_matplotlib/fonts/ipaexg.ttf`。
2. 将未修改的 `ipaexg.ttf` 放到本目录，保留文件名和附带许可。
3. 在 `scenes/main.tscn` 中把字体资源路径改为 `res://assets/fonts/ipaexg.ttf`。
4. 由 Godot 重新导入字体，即可使用原字体支持的完整字符集。

## 金色标题字体

`noto_serif_sc_title.ttf` 来自 Google Fonts 的 Noto Serif SC，600 字重，只包含“借光”。用于第二版标题的宋体正面、侧面与柔光层。许可为 SIL Open Font License 1.1，副本见 `OFL-NotoSerifSC.txt`。修改标题文字时需补齐字符。
