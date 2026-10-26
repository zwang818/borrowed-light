# 《借光》项目字体库

> 全部免费商用（OFL 1.1），跨平台可直接导入 Godot 使用。

## 字体清单

| 文件 | 角色 | 用途 |
|---|---|---|
| `lxgw_wenkai.ttf` | 霞鹜文楷 Regular | 神明对话、正文、标题衬线风 |
| `lxgw_wenkai_mono.ttf` | 霞鹜文楷等宽 | 系统警告、菜单提示（等宽更规整） |

## 授权

- **LXGW WenKai**：SIL Open Font License 1.1
  作者 LXGW（霞鹜），仓库 https://github.com/lxgw/LxgwWenKai
  可免费商用、可修改、可分发。

## 子集化说明（重要）

仓库内两个文楷字体是**裁剪后的子集**（原版各 25MB，裁剪后合计约 180KB），
仅包含 intro 过场当前用到的 198 个字符 + ASCII + 常用标点。

**改台词时若用到新字，需重新生成子集**，否则新字会显示为空白：

```bash
python3 -c "
import re
src = open('scenes/ui/intro_cutscene/intro_cutscene.gd', encoding='utf-8').read()
chars = set()
for t in re.findall(r'\"([^\"]*)\"', src): chars.update(t)
chars.update(chr(c) for c in range(0x20, 0x7F))
chars.update('，。！？；：「」『』（）—…、·《》0123456789')
open('/tmp/intro_chars.txt','w',encoding='utf-8').write(''.join(sorted(chars)))
"
pyftsubset assets/fonts/lxgw_wenkai.ttf --text-file=/tmp/intro_chars.txt \
  --output-file=assets/fonts/lxgw_wenkai.ttf --layout-features='*'
```

原版完整字体从 https://github.com/lxgw/LxgwWenKai/releases 下载，不进仓库。

## Godot 使用方式

1. 字体文件放进本目录（`.ttf` / `.otf` 直接放，**不提交 `.import`**，Godot 会自动生成）
2. 代码中用 `preload("res://assets/fonts/lxgw_wenkai.ttf")` 加载
3. Label / Button 用 `add_theme_font_override("font", 字体对象)` 覆盖默认

## 当前映射

| 场景 | 字体 |
|---|---|
| 标题界面 | `borrowed_light_title.ttf`（自定义美术字） |
| 神明对话 | `lxgw_wenkai.ttf` |
| 维护系统警告 | `lxgw_wenkai_mono.ttf` |
| 操作提示 / HUD | `lxgw_wenkai_mono.ttf` |
| 对话正文 | `lxgw_wenkai.ttf` |
