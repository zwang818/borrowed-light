# 脉冲枪原型音效

pulse_charge.wav：1 秒上升音高蓄力音。
pulse_laser.wav：1 秒激光振荡音，带起落淡化。

两份均为本项目通过数学振荡器原创合成的单声道 44.1 kHz / 16 bit PCM，无第三方采样或署名依赖。可由 D 后续替换。
播放组件位于 scenes/weapons/pulse_audio.gd，监听武器状态；暂停随场景冻结，取消或结束时停止，不控制战斗逻辑。

## 脉冲 biu 音效

pulse_biu.wav 为 Codex 编写 generate_pulse_biu.py 数学合成的原创占位声音，无第三方采样/录音。180 ms 快速降调，发射时播放一次、不循环，取消或结束时仍由既有监听器停止。当前 B 使用此声音，AB 快照继续引用 pulse_laser.wav，不覆盖旧资源。

最新试听调整：biu 起始频率提高至约 2460 Hz，并增加少量二、三次谐波，使声音更尖锐；时长和归一化峰值保持不变，不单纯提高音量。仅 B 使用。

## 标题界面 BGM

title_bgm.wav：64 秒循环氛围音乐，仿 Hans Zimmer《原野追逐》的声音结构（55 Hz 低频 drone + Am7→Fmaj7→C→G 缓慢和弦垫 + 稀疏高音点缀），首尾振幅一致，无缝循环。

由 generate_title_bgm.py 纯数学振荡器原创合成，单声道 22.05 kHz / 16 bit PCM，无任何第三方采样或录音，无版权风险。原版曲目受版权保护，本文件仅为氛围参考的原创实现。

播放组件位于 scenes/ui/title_screen/title_screen.gd 的 _init_bgm()：代码创建 AudioStreamPlayer，循环开关在 title_bgm.wav.import 的 edit/loop_mode=1（Godot 4 的循环在资源上设置，player 无 loop 属性）。音量由 @export title_bgm_volume（默认 0.35）控制。

重新生成：python3 assets/audio/generate_title_bgm.py（可改脚本内频率/包络/时长参数出新版；装 ffmpeg 后自动附带产出 .ogg）。
