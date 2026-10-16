# 标题字体

`borrowed_light_title.ttf` 是从 IPAex Gothic 003.01 裁剪并重命名的字体，字体家族名为 Borrowed Light Title。包含“借光”及基本 ASCII 字符，供当前最小标题场景使用；其他中文字符需补充完整字体后再使用。

原始字体来自 japanize-matplotlib 1.1.3 源码包中的 `japanize_matplotlib/fonts/ipaexg.ttf`：

https://pypi.org/project/japanize-matplotlib/1.1.3/#files

原始字体与本派生字体均按随附的 `IPA_Font_License_Agreement_v1.0.txt` 分发。字体内保留原始版权信息。修改内容：通过 FontTools 提取所需字符，修改派生字体家族名、完整名称和 PostScript 名称。

## 替换为原始字体

1. 从上述页面下载源码包，解压并取出 `japanize_matplotlib/fonts/ipaexg.ttf`。
2. 将未修改的 `ipaexg.ttf` 放到本目录，保留文件名和附带许可。
3. 在 `scenes/main.tscn` 中把字体资源路径改为 `res://assets/fonts/ipaexg.ttf`。
4. 由 Godot 重新导入字体，即可使用原字体支持的完整字符集。
