extends Control
## Presentation only. Button hit rectangles, callbacks and container sizes stay fixed.
const PREFS := preload("res://scenes/ui/user_settings.gd")
const ACCENT := Color("ddc18a")
var button: Button
var minimal := false
var text_menu := false
var hover_mix := 0.0
var press_mix := 0.0
var flash_mix := 0.0
var click_at := Vector2.ZERO
var down := false
var hovered := false
var styles: Array[StyleBoxFlat] = []
var base_styles: Array[StyleBoxFlat] = []
static var click_sound: AudioStreamWAV

static func attach(target: Button, robot_only: bool = false, open_menu: bool = false) -> Control:
	if target.has_node("ButtonFeedback"): return target.get_node("ButtonFeedback")
	var effect = load("res://scenes/ui/ui_button_feedback.gd").new()
	effect.name = "ButtonFeedback"
	effect.minimal = robot_only
	effect.text_menu = open_menu
	target.add_child(effect)
	return effect

static func reveal(panel: Control, slide: bool = false) -> void:
	var previous = panel.get_meta("ui_reveal_tween") if panel.has_meta("ui_reveal_tween") else null
	if previous != null and previous.is_valid(): previous.kill()
	panel.modulate.a = 0.0
	var tween := panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel.set_meta("ui_reveal_tween",tween)
	tween.tween_property(panel,"modulate:a",1.0,0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if slide:
		if not panel.has_meta("ui_rest_position"): panel.set_meta("ui_rest_position",panel.position)
		var origin: Vector2 = panel.get_meta("ui_rest_position")
		panel.position = origin + Vector2(0,10)
		tween.parallel().tween_property(panel,"position",origin,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	button = get_parent() as Button
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not minimal:
		button.add_theme_color_override("font_pressed_color",Color("fff0c6"))
		var states := ["normal","hover","pressed","focus"]
		if text_menu: states.append("disabled")
		for state in states:
			var source := button.get_theme_stylebox(state)
			if text_menu:
				source = StyleBoxFlat.new()
				source.bg_color = Color.TRANSPARENT
				source.content_margin_left = 18
				source.content_margin_right = 18
				source.content_margin_top = 7
				source.content_margin_bottom = 7
			if source is StyleBoxFlat:
				var style: StyleBoxFlat = source.duplicate()
				styles.append(style)
				base_styles.append(style.duplicate())
				button.add_theme_stylebox_override(state,style)
	button.mouse_entered.connect(func(): hovered = true)
	button.mouse_exited.connect(func(): hovered = false)
	button.button_down.connect(func():
		if button.disabled: return
		down = true
		click_at = button.get_local_mouse_position()
		if not Rect2(Vector2.ZERO,button.size).has_point(click_at): click_at = button.size/2)
	button.button_up.connect(func(): down = false)
	button.pressed.connect(_clicked)
	button.visibility_changed.connect(func():
		if not button.is_visible_in_tree():
			down = false
			hovered = false
			hover_mix = 0.0
			press_mix = 0.0
			flash_mix = 0.0)

func _clicked() -> void:
	if button.disabled: return
	flash_mix = 1.0
	# A tiny synthesized dry click, independent from gameplay audio and BGM.
	if click_sound == null:
		click_sound = AudioStreamWAV.new()
		click_sound.format = AudioStreamWAV.FORMAT_8_BITS
		click_sound.mix_rate = 22050
		var data := PackedByteArray()
		for i in range(990):
			var t := float(i)/22050.0
			var sample := sin(TAU*1100*t)*exp(-t*130)*0.25
			data.append(int(sample*127)&255)
		click_sound.data = data
	var voice := AudioStreamPlayer.new()
	PREFS.ensure_audio_buses()
	voice.bus = PREFS.UI_BUS
	voice.stream = click_sound
	voice.volume_db = -16
	# Root ownership lets a click finish after its menu is closed or freed.
	voice.process_mode = Node.PROCESS_MODE_ALWAYS
	(Engine.get_main_loop() as SceneTree).root.add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func _process(delta: float) -> void:
	var enabled := not button.disabled and button.is_visible_in_tree()
	var emphasis := enabled and (hovered or button.has_focus())
	hover_mix = lerpf(hover_mix,1.0 if emphasis else 0.0,1.0-exp(-delta*15))
	press_mix = move_toward(press_mix,1.0 if enabled and down else 0.0,delta*14)
	flash_mix = maxf(0.0,flash_mix-delta*3.8)
	if not minimal:
		for i in range(styles.size()):
			var style := styles[i]
			var base := base_styles[i]
			var shift := hover_mix*6.0 + press_mix*1.5
			style.content_margin_left = base.content_margin_left + shift
			style.content_margin_right = base.content_margin_right - shift
			if i < 3 and not text_menu:
				style.bg_color = base_styles[0].bg_color.lerp(Color(0.17,0.20,0.19,0.94),hover_mix*0.8).lerp(Color(0.29,0.25,0.17,1),press_mix*0.6)
			style.border_color = base.border_color.lerp(ACCENT,hover_mix*0.65+press_mix*0.25)
	queue_redraw()

func _draw() -> void:
	if button == null or button.disabled: return
	if text_menu and hover_mix > 0.001:
		draw_rect(Rect2(2,3,(size.x-4)*hover_mix,size.y-6),Color(ACCENT,hover_mix*0.18+press_mix*0.08))
		draw_circle(Vector2(size.x-17,size.y/2),2.2,Color(ACCENT,hover_mix*0.9))
	elif not minimal and hover_mix > 0.001:
		var inset := 2.0 + press_mix*1.5
		draw_rect(Rect2(Vector2(inset,inset),Vector2((size.x-inset*2)*hover_mix,size.y-inset*2)),Color(ACCENT,hover_mix*0.07))
		draw_rect(Rect2(3,size.y*0.25,2,size.y*0.5),Color(ACCENT,hover_mix*0.85))
		draw_line(Vector2(5,size.y-2),Vector2(5+(size.x-10)*hover_mix,size.y-2),Color(ACCENT,hover_mix*0.6),1)
	if flash_mix > 0:
		var radius := (1.0-flash_mix)*maxf(size.x,size.y)*0.6+4
		draw_arc(click_at,radius,0,TAU,36,Color(ACCENT,flash_mix*0.5),1.5,true)
		if not minimal: draw_rect(Rect2(Vector2.ONE*3,size-Vector2.ONE*6),Color(ACCENT,flash_mix*0.12))
