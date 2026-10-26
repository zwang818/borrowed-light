extends Control
## 《借光》开场导入动画 v4
## 所有帧内容可在 Inspector 实时修改。
## 修复列表（vs v3）：按钮自动绑定关卡；WASD 说明移到开头；字体美化；神明视觉更纯粹。

signal intro_finished

# ---------- 导出分组 ----------
@export_group("Playback")
@export var auto_start: bool = true
@export var skip_allowed: bool = true
@export var crossfade_to_scene: PackedScene   # 留空自动用 abdomen_level

@export_group("Style — Colors")
@export var color_warm: Color = Color(0.96, 0.73, 0.42, 1.0)
@export var color_warm_dim: Color = Color(0.68, 0.46, 0.22, 1.0)
@export var color_cold: Color = Color(0.48, 0.83, 0.88, 1.0)
@export var color_text_on_warm: Color = Color(1.0, 0.97, 0.88, 1.0)
@export var color_text_on_cold: Color = Color(0.85, 0.97, 1.0, 1.0)

@export_group("Style — Fonts (OFL 1.1 免费商用)")
@export var font_deity_path: String = "res://assets/fonts/lxgw_wenkai.ttf"
@export var font_system_path: String = "res://assets/fonts/lxgw_wenkai_mono.ttf"
@export var font_size_deity: int = 20
@export var font_size_system: int = 14
@export var font_size_button: int = 15

@export_group("Background Asset")
@export var landscape_texture: Texture2D = preload("res://assets/backgrounds/title/title_landscape.svg")
@export var beast_texture: Texture2D = preload("res://assets/backgrounds/title/mechanical_beast.svg")
@export var robot_texture: Texture2D = preload("res://assets/sprites/title/title_robot.svg")

@export_group("Deity Position (Inspector 可拖动)")
@export var deity_pos: Vector2 = Vector2(240, 220)
@export var deity_size: Vector2 = Vector2(80, 80)

@export_group("Audio")
@export var intro_bgm: AudioStream = preload("res://assets/audio/title_bgm.wav")
@export_range(0.0, 1.0, 0.05) var bgm_volume: float = 0.4

# ---------- 帧数据（Inspector 可编辑） ----------
# mode         "auto" 按时长走；"click" 需鼠标/E 推进
# duration     auto 帧秒数
# text         对话框正文
# dialog_style "warm" | "warm_dim" | "cold" | "hidden"
# show_deity   是否显示神明光球（跟对话同步亮起）
# robot_action "idle" | "pulse" | "walk_to_beast"
# show_hud     是否显示进入按钮
# show_hint    是否显示 WASD 玩法说明（仅前几帧用）
# system_lines 系统警告文字数组（空=不弹）
@export var frames: Array[Dictionary] = [
	{   # 1. 黑底 1s
		"mode": "auto", "duration": 1.0,
		"text": "", "dialog_style": "hidden",
		"show_deity": false, "robot_action": "idle",
		"show_hud": false, "show_hint": false,
		"landscape_alpha": 0.0, "beast_alpha": 0.0, "robot_alpha": 0.0,
	},
	{   # 2. 背景淡入 + WASD 玩法说明 2s（玩家先看清环境 + 操作）
		"mode": "auto", "duration": 2.2,
		"text": "", "dialog_style": "hidden",
		"show_deity": false, "robot_action": "idle",
		"show_hud": false, "show_hint": true,
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 0.0,
	},
	{   # 3. 神明（edge-tts Yunxi 云希 + Madness 氛围）
		"mode": "click", "duration": 4.5,
		"text": "小一……传回来的那片绿，是什么？", "dialog_style": "warm",
		"show_deity": true, "robot_action": "idle",
		"show_hud": false, "show_hint": false,
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 1.0,
		"voice": "res://assets/audio/voices/frame03_deity.wav",
	},
	{   # 4. 小一（DROID 机器人素材 + 字幕）
		"mode": "click", "duration": 1.5,
		"text": "……种子。从石缝里钻出来。", "dialog_style": "warm",
		"show_deity": true, "robot_action": "pulse",
		"show_hud": false, "show_hint": false,
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 1.0,
		"voice": "res://assets/audio/voices/frame04_xiaoyi.wav",
	},
	{   # 5. 神明
		"mode": "click", "duration": 4.0,
		"text": "小一……维护系统，在收紧。", "dialog_style": "warm_dim",
		"show_deity": true, "robot_action": "pulse",
		"show_hud": false, "show_hint": false,
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 1.0,
		"voice": "res://assets/audio/voices/frame05_deity.wav",
	},
	{   # 6. 神明
		"mode": "click", "duration": 3.5,
		"text": "它们要清空……意识区。", "dialog_style": "warm_dim",
		"show_deity": true, "robot_action": "pulse",
		"show_hud": false, "show_hint": false,
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 1.0,
		"voice": "res://assets/audio/voices/frame06_deity.wav",
	},
	{   # 7. 系统警告 auto
		"mode": "auto", "duration": 3.0,
		"text": "", "dialog_style": "hidden",
		"show_deity": false, "robot_action": "idle",
		"show_hud": false, "show_hint": false,
		"system_lines": ["非授权外连已记录。", "意识载体定位中。"],
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 1.0,
		"voice": "",
	},
	{   # 8. 求救
		"mode": "click", "duration": 3.0,
		"text": "你能……回来吗？", "dialog_style": "warm",
		"show_deity": true, "robot_action": "walk_to_beast",
		"show_hud": false, "show_hint": false,
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 1.0,
		"voice": "res://assets/audio/voices/frame08_deity.wav",
	},
	{   # 9. 最后：进入按钮
		"mode": "click", "duration": 1.0,
		"text": "", "dialog_style": "hidden",
		"show_deity": true, "robot_action": "walk_to_beast",
		"show_hud": true, "show_hint": false,
		"landscape_alpha": 1.0, "beast_alpha": 1.0, "robot_alpha": 1.0,
	},
]

# ---------- 运行时 ----------
var _frame_index: int = -1
var _frame_timer: float = 0.0
var _elapsed: float = 0.0

var _landscape: TextureRect
var _beast: TextureRect
var _beast_chest: Control
var _deity_orb: TextureRect
var _deity_floor: Panel
var _robot_anchor: Control
var _robot: TextureRect
var _lamp_glow: TextureRect

var _dialog_container: Control
var _dialog_panel: Panel
var _text_label: Label
var _click_prompt: Label
var _next_arrow: Label

var _system_container: Control
var _system_labels: Array[Label] = []

var _hud_layer: Control
var _hud_goal: Label
var _hud_hint: Label
var _enter_button: Button

var _bgm_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _page_sfx: AudioStreamPlayer
var _footstep_sfx: AudioStreamPlayer
var _footstep_timer: float = 0.0
var _bgm_duck_tween: Tween
var _tween: Tween

# ---------- 生命周期 ----------
func _ready() -> void:
	_build_scene()
	_setup_audio()
	# 自动绑定关卡（兜底，即使 Inspector 没配也能走通）
	if crossfade_to_scene == null:
		var fallback := load("res://scenes/gameplay/abdomen_level.tscn")
		if fallback != null:
			crossfade_to_scene = fallback
	_apply_frame_visuals(frames[0])
	if auto_start and frames.size() > 0:
		_advance()

func _process(delta: float) -> void:
	_elapsed += delta
	if _frame_index < 0 or _frame_index >= frames.size():
		return
	var frame: Dictionary = frames[_frame_index]
	_apply_frame_dynamic(delta, frame)
	if str(frame.get("mode", "auto")) == "auto":
		_frame_timer += delta
		if _frame_timer >= float(frame.get("duration", 2.0)):
			_advance()

func _input(event: InputEvent) -> void:
	if _frame_index < 0 or _frame_index >= frames.size():
		return
	var frame: Dictionary = frames[_frame_index]
	if skip_allowed and event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()
		return
	if str(frame.get("mode", "auto")) == "click":
		var show_hud: bool = bool(frame.get("show_hud", false))
		if show_hud:
			return   # 最后一帧：让 enter_button 的 _gui_input 正常收 click，不吞事件
		var is_click: bool = event is InputEventMouseButton and \
			event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var is_accept: bool = event.is_action_pressed("ui_accept")
		if is_click or is_accept:
			_advance()
			get_viewport().set_input_as_handled()

func _advance() -> void:
	_frame_index += 1
	_frame_timer = 0.0
	if _frame_index >= frames.size():
		_finish()
		return
	var frame: Dictionary = frames[_frame_index]
	_apply_frame_visuals(frame)
	_play_page_tween(frame)
	_play_page_click()   # 点击下一句音效
	_play_frame_voice(frame)   # 角色配音 + BGM duck
	var mode: String = str(frame.get("mode", "auto"))
	if mode == "click":
		if bool(frame.get("show_hud", false)):
			_click_prompt.text = ""
			_next_arrow.text = ""
		else:
			_click_prompt.text = "点击 / E 继续"
			_next_arrow.text = "▼"
	else:
		_click_prompt.text = ""
		_next_arrow.text = ""

func _finish() -> void:
	_frame_index = -1
	_voice_player.stop()
	_restore_bgm()
	intro_finished.emit()
	if crossfade_to_scene != null:
		get_tree().change_scene_to_packed(crossfade_to_scene)

func _play_frame_voice(frame: Dictionary) -> void:
	_voice_player.stop()
	var voice_path: String = str(frame.get("voice", ""))
	if voice_path.is_empty():
		_restore_bgm()
		return
	var stream: AudioStream = load(voice_path)
	if stream == null:
		_restore_bgm()
		return
	_voice_player.stream = stream
	_voice_player.volume_db = -2.0   # 语音稍响，盖过 BGM
	_voice_player.play()
	_duck_bgm()

func _on_voice_finished() -> void:
	_restore_bgm()

func _duck_bgm() -> void:
	if _bgm_duck_tween != null and _bgm_duck_tween.is_valid():
		_bgm_duck_tween.kill()
	_bgm_duck_tween = create_tween()
	_bgm_duck_tween.tween_property(_bgm_player, "volume_db", linear_to_db(bgm_volume) - 10.0, 0.25).set_trans(Tween.TRANS_SINE)

func _restore_bgm() -> void:
	if _bgm_duck_tween != null and _bgm_duck_tween.is_valid():
		_bgm_duck_tween.kill()
	_bgm_duck_tween = create_tween()
	_bgm_duck_tween.tween_property(_bgm_player, "volume_db", linear_to_db(bgm_volume), 0.35).set_trans(Tween.TRANS_SINE)

func _setup_audio() -> void:
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_bgm_player.stream = intro_bgm
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	if intro_bgm != null:
		_bgm_player.play()
	_voice_player = AudioStreamPlayer.new()
	_voice_player.finished.connect(_on_voice_finished)
	add_child(_voice_player)
	_page_sfx = AudioStreamPlayer.new()
	add_child(_page_sfx)
	_footstep_sfx = AudioStreamPlayer.new()
	add_child(_footstep_sfx)

func _play_page_click() -> void:
	var s := _make_tick_sound()
	if s == null: return
	_page_sfx.stream = s
	_page_sfx.volume_db = -8.0
	_page_sfx.play()

func _play_footstep() -> void:
	var s := _make_footstep_sound()
	if s == null: return
	_footstep_sfx.stream = s
	_footstep_sfx.volume_db = -12.0
	_footstep_sfx.play()

func _make_tick_sound() -> AudioStreamWAV:
	var sr := 44100; var dur := 0.08; var count := int(sr * dur)
	var buf := PackedByteArray(); buf.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sr)
		var env := exp(-t * 40.0)
		var s := sin(t * TAU * 2200.0) * env * 0.18
		s += sin(t * TAU * 1400.0) * env * 0.08
		var val := clampi(int(s * 16383), -16384, 16383)
		buf[i*2] = val & 0xff; buf[i*2+1] = (val>>8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = sr
	stream.stereo = false; stream.data = buf; stream.loop_mode = 0
	return stream

func _make_footstep_sound() -> AudioStreamWAV:
	var sr := 44100; var dur := 0.15; var count := int(sr * dur)
	var buf := PackedByteArray(); buf.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sr)
		var env := exp(-t * 18.0)
		var s := (randf_range(-1, 1) * 0.5 + sin(t * TAU * 80.0) * 0.5) * env * 0.3
		var val := clampi(int(s * 16383), -16384, 16383)
		buf[i*2] = val & 0xff; buf[i*2+1] = (val>>8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = sr
	stream.stereo = false; stream.data = buf; stream.loop_mode = 0
	return stream

# ---------- 翻页动画 ----------
func _play_page_tween(frame: Dictionary) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_dialog_container.modulate.a = 0.0
	_dialog_container.scale = Vector2(0.93, 0.93)
	_tween.tween_property(_dialog_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_dialog_container, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------- 帧静态视觉 ----------
func _apply_frame_visuals(frame: Dictionary) -> void:
	_landscape.modulate.a = float(frame.get("landscape_alpha", 1.0))
	_beast.modulate.a = float(frame.get("beast_alpha", 1.0))
	_robot_anchor.modulate.a = float(frame.get("robot_alpha", 1.0))
	# 对话框
	var style: String = str(frame.get("dialog_style", "hidden"))
	if style == "hidden":
		_dialog_container.modulate.a = 0.0
	else:
		_dialog_container.modulate.a = 1.0
		_dialog_container.scale = Vector2.ONE
		_text_label.text = str(frame.get("text", ""))
		var deity_font: Font = _load_font(font_deity_path)
		_text_label.add_theme_font_override("font", deity_font)
		_text_label.add_theme_font_size_override("font_size", font_size_deity)
		match style:
			"warm":
				_text_label.add_theme_color_override("font_color", color_text_on_warm)
				_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_panel(Color(0.05, 0.04, 0.03, 0.88), Color(1.0, 0.70, 0.30, 0.55)))
			"warm_dim":
				_text_label.add_theme_color_override("font_color", color_text_on_warm)
				_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_panel(Color(0.12, 0.04, 0.0, 0.9), Color(0.75, 0.35, 0.12, 0.45)))
			"cold":
				_text_label.add_theme_color_override("font_color", color_text_on_cold)
				_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_panel(Color(0.0, 0.06, 0.08, 0.9), Color(0.35, 0.82, 0.88, 0.45)))
	# 神明视觉球（纯粹光球，不带文字）
	var show_deity: bool = bool(frame.get("show_deity", false))
	_deity_orb.modulate.a = 0.9 if show_deity else 0.0
	_deity_floor.modulate.a = 0.55 if show_deity else 0.0
	# 系统警告弹窗
	var sys_lines: Array = frame.get("system_lines", [])
	if sys_lines.size() > 0:
		_show_system(sys_lines)
	else:
		_system_container.modulate.a = 0.0
	# HUD：WASD 玩法说明（仅开头）
	if bool(frame.get("show_hint", false)):
		_hud_hint.modulate.a = 1.0
		_hud_goal.modulate.a = 0.0
	else:
		_hud_hint.modulate.a = 0.0
	# 进入按钮（仅最后一帧）
	if bool(frame.get("show_hud", false)):
		_enter_button.visible = true
		_hud_goal.modulate.a = 1.0
		_hud_hint.modulate.a = 0.0
		_click_prompt.text = ""
		_next_arrow.text = ""
	else:
		_enter_button.visible = false

func _make_dialog_panel(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_color = border
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 6; s.content_margin_bottom = 6
	return s

# ---------- 动态每帧 ----------
func _apply_frame_dynamic(delta: float, frame: Dictionary) -> void:
	var action: String = str(frame.get("robot_action", "idle"))
	match action:
		"pulse":
			_lamp_glow.modulate.a = 0.85 + sin(_elapsed * 8.0) * 0.15
			_robot.rotation = sin(_elapsed * 6.0) * 0.04
		"walk_to_beast":
			_robot_anchor.position.x = move_toward(_robot_anchor.position.x, 780.0, delta * 140.0)
			_robot_anchor.position.y = move_toward(_robot_anchor.position.y, 450.0, delta * 15.0)
			_robot.rotation = sin(_elapsed * 10.0) * 0.03
			_lamp_glow.modulate.a = 0.75 + sin(_elapsed * 14.0) * 0.08
			# 走路脚步声：每 0.45s 一次
			_footstep_timer += delta
			if _footstep_timer >= 0.45:
				_footstep_timer = 0.0
				_play_footstep()
		_:  # idle
			_robot.rotation = sin(_elapsed * 1.25) * 0.025
			_robot_anchor.position.y = 430.0 + sin(_elapsed * 1.5) * 1.5
			_lamp_glow.modulate.a = 0.78 + sin(_elapsed * 1.0) * 0.05
	# 神明光球：呼吸式缩放+alpha
	if _deity_orb.modulate.a > 0.01:
		_deity_orb.scale = Vector2.ONE * (1.0 + sin(_elapsed * 3.2) * 0.10)
		_deity_orb.modulate.a = 0.88 + sin(_elapsed * 3.2 + 1.0) * 0.12
		_deity_floor.modulate.a = 0.55 + sin(_elapsed * 3.2 + 1.0) * 0.15

# ---------- 场景构建 ----------
func _build_scene() -> void:
	# 纯黑底
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.03, 1)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 荒原背景 — 保持原始比例铺满
	_landscape = TextureRect.new()
	_landscape.texture = landscape_texture
	_landscape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_landscape.anchor_right = 1.0; _landscape.anchor_bottom = 1.0
	_landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_landscape)

	# 神兽剪影
	_beast = TextureRect.new()
	_beast.texture = beast_texture
	_beast.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_beast.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_beast.position = Vector2(500, 200)
	_beast.size = Vector2(780, 380)
	_beast.modulate.a = 0.0
	_beast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beast)

	# 神明锚点（Inspector 可调整位置/大小）
	_beast_chest = Control.new()
	_beast_chest.position = deity_pos
	_beast_chest.size = deity_size
	_beast_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beast_chest)
	# 柔光底座
	_deity_floor = Panel.new()
	var floor_style := StyleBoxFlat.new()
	floor_style.bg_color = Color(1.0, 0.80, 0.40, 0.60)
	floor_style.corner_radius_top_left = 40; floor_style.corner_radius_top_right = 40
	floor_style.corner_radius_bottom_left = 40; floor_style.corner_radius_bottom_right = 40
	floor_style.content_margin_left = 30; floor_style.content_margin_right = 30
	floor_style.content_margin_top = 30; floor_style.content_margin_bottom = 30
	_deity_floor.add_theme_stylebox_override("panel", floor_style)
	_deity_floor.position = Vector2(-40, -40)
	_deity_floor.size = Vector2(180, 180)
	_deity_floor.modulate.a = 0.0
	_deity_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beast_chest.add_child(_deity_floor)
	# 核心光球（径向渐变，带光的能量感）
	_deity_orb = TextureRect.new()
	_deity_orb.texture = _make_deity_gradient()
	_deity_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_deity_orb.stretch_mode = TextureRect.STRETCH_KEEP
	_deity_orb.position = Vector2(0, 0)
	_deity_orb.size = Vector2(80, 80)
	_deity_orb.modulate.a = 0.0
	_deity_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beast_chest.add_child(_deity_orb)

	# 机器人锚点 — 上移到 y=430，图片底=578，和对话框顶(662)空 84px
	_robot_anchor = Control.new()
	_robot_anchor.position = Vector2(200, 430)
	_robot_anchor.size = Vector2(120, 160)
	_robot_anchor.modulate.a = 0.0
	_robot_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_robot_anchor)
	_lamp_glow = TextureRect.new()
	_lamp_glow.texture = _make_lamp_gradient()
	_lamp_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lamp_glow.stretch_mode = TextureRect.STRETCH_KEEP
	_lamp_glow.position = Vector2(-30, -20)
	_lamp_glow.size = Vector2(180, 180)
	_robot_anchor.add_child(_lamp_glow)
	_robot = TextureRect.new()
	_robot.texture = robot_texture
	_robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_robot.position = Vector2(12, 20)
	_robot.size = Vector2(96, 128)
	_robot.pivot_offset = Vector2(48, 120)
	_robot_anchor.add_child(_robot)

	# 对话框 — 最小化 (92%-98.5%)，y=662-709，高度 47px，绝无可能挡任何主体
	_dialog_container = Control.new()
	_dialog_container.anchor_left = 0.22; _dialog_container.anchor_right = 0.78
	_dialog_container.anchor_top = 0.92; _dialog_container.anchor_bottom = 0.985
	_dialog_container.modulate.a = 0.0
	_dialog_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dialog_container)
	_dialog_panel = Panel.new()
	_dialog_panel.anchor_right = 1.0; _dialog_panel.anchor_bottom = 1.0
	_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_panel(Color(0.05, 0.04, 0.03, 0.88), Color(1.0, 0.70, 0.30, 0.55)))
	_dialog_container.add_child(_dialog_panel)
	# 正文（居中 + 阴影 + 描边。全靠 anchor，不写死 size）
	_text_label = Label.new()
	_text_label.anchor_left = 0.0; _text_label.anchor_right = 1.0
	_text_label.anchor_top = 0.0; _text_label.anchor_bottom = 1.0
	_text_label.offset_left = 20; _text_label.offset_right = -80
	_text_label.offset_top = 8; _text_label.offset_bottom = -4   # 右下留 4px 给翻页提示
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_size_override("font_size", font_size_deity)
	_text_label.add_theme_font_override("font", _load_font(font_deity_path))
	_text_label.add_theme_color_override("font_color", color_text_on_warm)
	_text_label.add_theme_constant_override("line_spacing", 8)
	_text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_text_label.add_theme_constant_override("shadow_offset_x", 2)
	_text_label.add_theme_constant_override("shadow_offset_y", 2)
	_text_label.add_theme_constant_override("shadow_outline_size", 4)
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	_text_label.add_theme_constant_override("outline_size", 1)
	_dialog_container.add_child(_text_label)
	# 翻页箭头（相对 dialog_container 右下角）
	_next_arrow = Label.new()
	_next_arrow.anchor_left = 1.0; _next_arrow.anchor_right = 1.0
	_next_arrow.anchor_top = 1.0; _next_arrow.anchor_bottom = 1.0
	_next_arrow.offset_left = -24; _next_arrow.offset_right = -4
	_next_arrow.offset_top = -24; _next_arrow.offset_bottom = -4
	_next_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_arrow.add_theme_font_size_override("font_size", 14)
	_next_arrow.add_theme_color_override("font_color", Color(0.92, 0.77, 0.5, 0.9))
	_next_arrow.add_theme_font_override("font", _load_font(font_system_path))
	_next_arrow.text = "▼"
	_dialog_container.add_child(_next_arrow)
	_click_prompt = Label.new()
	_click_prompt.anchor_left = 1.0; _click_prompt.anchor_right = 1.0
	_click_prompt.anchor_top = 1.0; _click_prompt.anchor_bottom = 1.0
	_click_prompt.offset_left = -132; _click_prompt.offset_right = -32
	_click_prompt.offset_top = -24; _click_prompt.offset_bottom = -4
	_click_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_click_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_click_prompt.add_theme_font_size_override("font_size", 12)
	_click_prompt.add_theme_color_override("font_color", Color(0.72, 0.72, 0.6, 0.65))
	_click_prompt.add_theme_font_override("font", _load_font(font_system_path))
	_click_prompt.text = "点击 / E 继续"
	_dialog_container.add_child(_click_prompt)

	# 系统警告弹窗 — 绝对顶部区 (0%-10%)
	_system_container = Control.new()
	_system_container.anchor_left = 0.68; _system_container.anchor_right = 0.98
	_system_container.anchor_top = 0.01; _system_container.anchor_bottom = 0.12
	_system_container.modulate.a = 0.0
	_system_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_system_container)
	var sys_floor := ColorRect.new()
	sys_floor.anchor_right = 1.0; sys_floor.anchor_bottom = 1.0
	sys_floor.color = Color(0.02, 0.05, 0.08, 0.88)
	_system_container.add_child(sys_floor)
	var sys_border := ColorRect.new()
	sys_border.anchor_right = 1.0; sys_border.anchor_top = 0.0; sys_border.anchor_bottom = 0.0
	sys_border.custom_minimum_size = Vector2(0, 2)
	sys_border.color = color_cold
	_system_container.add_child(sys_border)

	# HUD 层（WASD 提示 + 目标 + 进入按钮）
	_hud_layer = Control.new()
	_hud_layer.anchor_right = 1.0; _hud_layer.anchor_bottom = 1.0
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_layer)
	# 目标（右上）
	_hud_goal = Label.new()
	_hud_goal.position = Vector2(940, 28)
	_hud_goal.size = Vector2(300, 26)
	_hud_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_goal.add_theme_font_size_override("font_size", font_size_system)
	_hud_goal.add_theme_color_override("font_color", Color(0.93, 0.68, 0.35, 1))
	_hud_goal.add_theme_font_override("font", _load_font(font_system_path))
	_hud_goal.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_hud_goal.add_theme_constant_override("shadow_offset_x", 1)
	_hud_goal.add_theme_constant_override("shadow_offset_y", 1)
	_hud_goal.text = "当前目标：进入机械神兽体内"
	_hud_layer.add_child(_hud_goal)
	# WASD 玩法说明 — 顶部区 (5%-10%)，和系统警告同一带
	_hud_hint = Label.new()
	_hud_hint.position = Vector2(350, 40)
	_hud_hint.size = Vector2(580, 28)
	_hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_hint.add_theme_font_size_override("font_size", font_size_system)
	_hud_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85, 1.0))
	_hud_hint.add_theme_font_override("font", _load_font(font_system_path))
	_hud_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hud_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hud_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hud_hint.add_theme_constant_override("shadow_outline_size", 4)
	_hud_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_hud_hint.add_theme_constant_override("outline_size", 2)
	_hud_hint.text = "WASD 移动  ·  鼠标瞄准  ·  E 交互"
	_hud_layer.add_child(_hud_hint)

	# 进入游戏按钮 — 对话框正上方 (85%-90%)，和对话框 92% 空 14px
	_enter_button = Button.new()
	_enter_button.anchor_left = 0.42; _enter_button.anchor_right = 0.58
	_enter_button.anchor_top = 0.85; _enter_button.anchor_bottom = 0.90
	_enter_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_enter_button.visible = false
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.08, 0.04, 0.92)
	normal.border_color = Color(1.0, 0.70, 0.30, 0.85)
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6; normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6; normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 28; normal.content_margin_right = 28
	normal.content_margin_top = 12; normal.content_margin_bottom = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(0.20, 0.13, 0.05, 0.95)
	hover.border_color = Color(1.0, 0.85, 0.50, 1.0)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.30, 0.20, 0.08, 0.98)
	_enter_button.add_theme_stylebox_override("normal", normal)
	_enter_button.add_theme_stylebox_override("hover", hover)
	_enter_button.add_theme_stylebox_override("pressed", pressed)
	_enter_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.50, 1.0))
	_enter_button.add_theme_font_size_override("font_size", font_size_button)
	_enter_button.add_theme_font_override("font", _load_font(font_deity_path))
	_enter_button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_enter_button.add_theme_constant_override("shadow_offset_x", 1)
	_enter_button.add_theme_constant_override("shadow_offset_y", 1)
	_enter_button.text = "进入游戏"
	_enter_button.pressed.connect(_finish)
	add_child(_enter_button)

# ---------- 系统警告 ----------
func _show_system(lines: Array) -> void:
	for lbl in _system_labels:
		lbl.queue_free()
	_system_labels.clear()
	var sys_font := _load_font(font_system_path)
	var head := Label.new()
	head.position = Vector2(14, 10); head.size = Vector2(252, 20)
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", color_cold)
	head.add_theme_font_override("font", sys_font)
	head.text = "[ 维护系统 · 自动通知 ]"
	_system_container.add_child(head)
	_system_labels.append(head)
	for i in range(lines.size()):
		var lbl := Label.new()
		lbl.position = Vector2(14, 36 + i * 22); lbl.size = Vector2(252, 20)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", color_text_on_cold)
		lbl.add_theme_font_override("font", sys_font)
		lbl.text = str(lines[i])
		_system_container.add_child(lbl)
		_system_labels.append(lbl)
	_system_container.modulate.a = 1.0

# ---------- 渐变 & 字体 ----------
func _make_lamp_gradient() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([
		Color(1, 0.88, 0.55, 0.55),
		Color(1, 0.70, 0.30, 0.18),
		Color(1, 0.70, 0.30, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g; gt.width = 192; gt.height = 192
	gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5)
	return gt

func _make_deity_gradient() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.97, 0.82, 1.0),
		Color(1.0, 0.80, 0.45, 0.7),
		Color(1.0, 0.60, 0.20, 0.25),
		Color(1.0, 0.50, 0.10, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g; gt.width = 100; gt.height = 100
	gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5)
	return gt

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is Font:
			return r
	return ThemeDB.fallback_font
