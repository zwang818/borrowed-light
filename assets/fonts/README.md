# 标题字体

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
