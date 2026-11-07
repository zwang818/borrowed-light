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
@export var landscape_texture: Texture2D = preload("res://assets/backgrounds/title/wasteland_intro_pixel.png")
@export var beast_texture: Texture2D = preload("res://assets/backgrounds/title/mechanical_deity_pixel.png")
@export var robot_texture: Texture2D = preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_idle_pixel.png")

@export_group("Audio")
@export var intro_bgm: AudioStream = preload("res://assets/audio/title_bgm.wav")
@export_range(0.0, 1.0, 0.05) var bgm_volume: float = 0.4

# ---------- 帧数据（Inspector 可编辑） ----------
# mode         "auto" 按时长走；"click" 需鼠标/E 推进
# duration     auto 帧秒数
# text         对话框正文
# dialog_style "warm" | "warm_dim" | "cold" | "hidden"
# show_deity   旧兼容字段；核心光效已绘入神明贴图
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
var _robot_anchor: Control
var _robot: TextureRect
var _lamp_glow: TextureRect
var _grass_foreground: TextureRect
var _grass_material: ShaderMaterial
var _wind_player: AudioStreamPlayer
var _walk_frames: Array[AtlasTexture] = []
var _walk_frame_elapsed := 0.0
var _walk_frame_index := 0
const DESIGN_SIZE := Vector2(1280.0, 720.0)
var _scene_scale := 1.0
var _scene_offset := Vector2.ZERO
const WALK_SHEET: Texture2D = preload("res://tests/manual/b_combat/art/xiaoyi/xiaoyi_walk_8dir.png")
const WALK_ROW_RIGHT := 6
const WALK_ROW_EDGES := [0, 213, 428, 644, 867, 1082, 1302, 1516, 1774]

var _dialog_container: Control
var _dialog_panel: Panel
var _dialog_glint_top: ColorRect
var _dialog_glint_side: ColorRect
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
	resized.connect(_fit_scene_art)
	_fit_scene_art()
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
	_wind_player = AudioStreamPlayer.new()
	_wind_player.stream = _make_wind_stream()
	_wind_player.volume_db = -1.5
	add_child(_wind_player)

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
	stream.stereo = false; stream.data = buf
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
	stream.stereo = false; stream.data = buf
	return stream

func _make_wind_stream() -> AudioStreamWAV:
	var sr := 22050
	var duration := 6.0
	var count := int(sr * duration)
	var buf := PackedByteArray()
	buf.resize(count * 2)
	var low := 0.0
	var mid := 0.0
	for i in range(count):
		var t := float(i) / float(sr)
		low = low * 0.992 + randf_range(-1.0, 1.0) * 0.008
		mid = mid * 0.94 + randf_range(-1.0, 1.0) * 0.06
		var gust := 0.72 + 0.28 * pow(0.5 + 0.5 * sin(TAU * 2.0 * t / duration), 2.0)
		var edge_fade := smoothstep(0.0, 0.08, minf(t, duration - t))
		var sample := clampf((low * 4.5 + mid * 0.52 + randf_range(-1.0, 1.0) * 0.035) * gust * edge_fade * 0.72, -0.98, 0.98)
		var pcm := int(sample * 32767.0)
		buf[i * 2] = pcm & 0xff
		buf[i * 2 + 1] = (pcm >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sr
	stream.stereo = false
	stream.data = buf
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream

func _prepare_walk_frames() -> void:
	_walk_frames.clear()
	var sheet_width := WALK_SHEET.get_width()
	var column_width := float(sheet_width) / 4.0
	for column in range(4):
		var x0 := roundi(column * column_width)
		var x1 := roundi((column + 1) * column_width)
		var frame := AtlasTexture.new()
		frame.atlas = WALK_SHEET
		frame.region = Rect2(x0, WALK_ROW_EDGES[WALK_ROW_RIGHT], x1 - x0, WALK_ROW_EDGES[WALK_ROW_RIGHT + 1] - WALK_ROW_EDGES[WALK_ROW_RIGHT])
		frame.filter_clip = true
		_walk_frames.append(frame)

func _fit_scene_art() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or _beast == null:
		return
	_scene_scale = minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	_scene_offset = (viewport_size - DESIGN_SIZE * _scene_scale) * 0.5
	_beast.position = _scene_offset + Vector2(380.0, 145.0) * _scene_scale
	_beast.size = Vector2(880.0, 440.0) * _scene_scale
	_robot_anchor.position = _scene_offset + Vector2(200.0, 430.0) * _scene_scale
	_robot_anchor.scale = Vector2.ONE * _scene_scale
	_grass_foreground.position = _scene_offset + Vector2(0.0, 470.0) * _scene_scale
	_grass_foreground.size = Vector2(1280.0, 250.0) * _scene_scale

# ---------- 翻页动画 ----------
func _play_page_tween(_frame: Dictionary) -> void:
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
				var warm_fill := Color(0.05, 0.04, 0.03, 0.88)
				_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_panel(warm_fill, Color(1.0, 0.70, 0.30, 0.55)))
				_set_dialog_reflection(warm_fill)
			"warm_dim":
				_text_label.add_theme_color_override("font_color", color_text_on_warm)
				var warm_dim_fill := Color(0.12, 0.04, 0.0, 0.9)
				_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_panel(warm_dim_fill, Color(0.75, 0.35, 0.12, 0.45)))
				_set_dialog_reflection(warm_dim_fill)
			"cold":
				_text_label.add_theme_color_override("font_color", color_text_on_cold)
				var cold_fill := Color(0.0, 0.06, 0.08, 0.9)
				_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_panel(cold_fill, Color(0.35, 0.82, 0.88, 0.45)))
				_set_dialog_reflection(cold_fill)
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
	var metal := bg.lerp(border, 0.72).lightened(0.1)
	metal.a = 1.0
	s.border_color = metal
	s.border_width_left = 4; s.border_width_right = 4
	s.border_width_top = 7; s.border_width_bottom = 4
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 6; s.content_margin_bottom = 6
	s.shadow_color = Color(0, 0, 0, 0.62)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s

func _set_dialog_reflection(fill: Color) -> void:
	if not is_instance_valid(_dialog_glint_top) or not is_instance_valid(_dialog_glint_side):
		return
	var metal := fill.lerp(Color("e6e7d7"), 0.78)
	metal.a = 0.58
	_dialog_glint_top.color = metal
	metal.a = 0.28
	_dialog_glint_side.color = metal

# ---------- 动态每帧 ----------
func _apply_frame_dynamic(delta: float, frame: Dictionary) -> void:
	var action: String = str(frame.get("robot_action", "idle"))
	var walking := action == "walk_to_beast"
	if _wind_player != null:
		if walking and not _wind_player.playing:
			_wind_player.play()
		elif not walking and _wind_player.playing:
			_wind_player.stop()
	if _grass_material != null:
		_grass_material.set_shader_parameter("sway_amount", (9.0 if walking else 1.6) * _scene_scale)
	match action:
		"pulse":
			_lamp_glow.modulate.a = 0.85 + sin(_elapsed * 8.0) * 0.15
			_robot.rotation = sin(_elapsed * 6.0) * 0.04
		"walk_to_beast":
			_robot_anchor.position.x = move_toward(_robot_anchor.position.x, _scene_offset.x + 629.0 * _scene_scale, delta * 140.0 * _scene_scale)
			_robot_anchor.position.y = move_toward(_robot_anchor.position.y, _scene_offset.y + 398.0 * _scene_scale, delta * 15.0 * _scene_scale)
			_walk_frame_elapsed += delta
			if _walk_frame_elapsed >= 0.13:
				_walk_frame_elapsed = fposmod(_walk_frame_elapsed, 0.13)
				_walk_frame_index = (_walk_frame_index + 1) % _walk_frames.size()
				_robot.texture = _walk_frames[_walk_frame_index]
			# 抵达腹腔入口后继续向内走，并在暗部中渐隐。
			var robot_design_x := (_robot_anchor.position.x - _scene_offset.x) / _scene_scale
			var enter_fade := clampf((robot_design_x - 559.0) / 70.0, 0.0, 1.0)
			_robot_anchor.modulate.a = 1.0 - enter_fade
			_robot.rotation = sin(_elapsed * 10.0) * 0.03
			_lamp_glow.modulate.a = (0.76 + sin(_elapsed * 14.0) * 0.08) * (1.0 - enter_fade)
			# 走路脚步声：每 0.45s 一次
			_footstep_timer += delta
			if _footstep_timer >= 0.45:
				_footstep_timer = 0.0
				_play_footstep()
		_:  # idle
			_robot_anchor.modulate.a = 1.0
			_robot.texture = robot_texture
			_walk_frame_elapsed = 0.0
			_walk_frame_index = 0
			_robot.rotation = sin(_elapsed * 1.25) * 0.025
			_robot_anchor.position.y = _scene_offset.y + (430.0 + sin(_elapsed * 1.5) * 1.5) * _scene_scale
			_lamp_glow.modulate.a = 0.78 + sin(_elapsed * 1.0) * 0.05

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

	# 神明遗体：透明像素贴图叠在荒原远景前
	_beast = TextureRect.new()
	_beast.texture = beast_texture
	_beast.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_beast.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_beast.position = Vector2(380, 145)
	_beast.size = Vector2(880, 440)
	_beast.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_beast.modulate.a = 0.0
	_beast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beast)

	# 小一锚点 — 开场从左侧荒原走向腹腔入口
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
	_lamp_glow.position = Vector2(16, 28)
	_lamp_glow.size = Vector2(88, 88)
	_robot_anchor.add_child(_lamp_glow)
	_robot = TextureRect.new()
	_robot.texture = robot_texture
	_robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_robot.position = Vector2(-1, 20)
	_robot.size = Vector2(122, 128)
	_robot.pivot_offset = Vector2(61, 120)
	_robot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_robot_anchor.add_child(_robot)
	_prepare_walk_frames()

	# 前景荒草单独覆盖在角色脚前，走路时受更强阵风推动。
	_grass_foreground = TextureRect.new()
	_grass_foreground.texture = preload("res://assets/backgrounds/title/wasteland_grass_foreground.png")
	_grass_foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grass_foreground.stretch_mode = TextureRect.STRETCH_SCALE
	_grass_foreground.position = Vector2(0, 470)
	_grass_foreground.size = Vector2(1280, 250)
	_grass_foreground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grass_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grass_material = ShaderMaterial.new()
	_grass_material.shader = preload("res://scenes/ui/intro_cutscene/wasteland_grass.gdshader")
	_grass_foreground.material = _grass_material
	add_child(_grass_foreground)

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
	_dialog_glint_top = ColorRect.new()
	_dialog_glint_top.anchor_right = 1.0
	_dialog_glint_top.offset_left = 8; _dialog_glint_top.offset_right = -12
	_dialog_glint_top.offset_top = 3; _dialog_glint_top.offset_bottom = 5
	_dialog_glint_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_panel.add_child(_dialog_glint_top)
	_dialog_glint_side = ColorRect.new()
	_dialog_glint_side.anchor_bottom = 1.0
	_dialog_glint_side.offset_left = 4; _dialog_glint_side.offset_right = 6
	_dialog_glint_side.offset_top = 10; _dialog_glint_side.offset_bottom = -12
	_dialog_glint_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_panel.add_child(_dialog_glint_side)
	_set_dialog_reflection(Color(0.05, 0.04, 0.03, 0.88))
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
	var sys_floor := Panel.new()
	sys_floor.anchor_right = 1.0; sys_floor.anchor_bottom = 1.0
	sys_floor.add_theme_stylebox_override("panel", _make_dialog_panel(Color(0.02, 0.05, 0.08, 0.88), Color(0.35, 0.82, 0.88, 0.45)))
	_system_container.add_child(sys_floor)
	var sys_border := ColorRect.new()
	sys_border.anchor_right = 1.0; sys_border.anchor_top = 0.0; sys_border.anchor_bottom = 0.0
	sys_border.custom_minimum_size = Vector2(0, 2)
	sys_border.color = Color(0.66, 0.91, 0.91, 0.72)
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
	_hud_goal.text = "当前目标：进入神明遗体"
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

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is Font:
			return r
	return ThemeDB.fallback_font
