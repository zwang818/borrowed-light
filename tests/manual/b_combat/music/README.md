# 内部探索背景音乐 · B 灰盒原型

依据 Bible 06 AUDIO-01、ASSET-01 及内部探索音乐建议。当前只接入 B 的 combat_test.tscn；未修改 AB、标题、主入口、项目音频总线或其他成员资产。荒原/结尾和 Boss 是不同场景的音乐需求，本次没有将它们混入腹腔测试。

interior_exploration.wav：32 秒单声道循环，22.05 kHz / 16 bit。低频机械底声、缓慢开放和弦与稀疏柔和旋律，无突发惊吓和强鼓点。默认 -24 dB，受伤/预警时压低至 -32 dB；预警结束后缓慢恢复。启动与重试 0.8 秒淡入，死亡 0.3 秒淡出停止，暂停保留播放位置，随场景释放播放器。

来源：Codex（OpenAI AI 编程助手）编写 generate_music.py，通过数学振荡器、音符包络和跨循环叠加合成的原创占位音乐。无第三方采样/录音，无第三方署名要求；不是商业配乐或真实乐器录制。重建：python3 tests/manual/b_combat/music/generate_music.py。

脚本显式设置完整 WAV 正向循环，不依赖本机导入设置。音符尾部跨边界叠加，机械底声使用整周期频率。自动检查覆盖开始播放、循环长度与模式、受伤压低、暂停恢复、死亡停止、重试重启及场景释放。听感、长时间循环舒适度及扬声器混音仍需人工试听。

验证：godot --headless --path . --script res://tests/manual/b_combat/music_check.gd
