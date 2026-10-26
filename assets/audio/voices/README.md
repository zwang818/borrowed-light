# Voices — 语音帧

## 文件清单

| 文件 | 角色 | 用途 |
|---|---|---|
| `frame03_deity.wav` | 神明 | 开场帧 03 的神明台词 |
| `frame04_xiaoyi.wav` | 小一 | 开场帧 04 的小一台词 |
| `frame05_deity.wav` | 神明 | 开场帧 05 的神明台词 |
| `frame06_deity.wav` | 神明 | 开场帧 06 的神明台词 |
| `frame08_deity.wav` | 神明 | 开场帧 08 的神明台词 |

> 所有素材经 `assets/audio/generate_voices.py` 合成，循环无缝。

## 原始素材来源（不进仓库）

`assets/audio/sources/` 目录已被 `.gitignore` 排除（约 100MB），包含：

| 来源 | URL |
|---|---|
| Kenney Voiceover | https://kenney.nl/assets/voiceover （CC0） |
| Madness Voice Pack | https://freesound.org/people/madness/packs/159/ （CC BY 3.0） |

队友如需重跑 `generate_voices.py`，自行前往上述链接下载原始包。

## 再生成

```bash
python3 assets/audio/generate_voices.py
```

脚本会从 `sources/` 读取素材 → 合成 → 输出到 `voices/`。
