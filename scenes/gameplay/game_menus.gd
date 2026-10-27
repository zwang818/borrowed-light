extends CanvasLayer
## Menus keep processing while their sibling gameplay nodes are paused.

signal retry_requested
signal title_requested

enum Page { CLOSED, PAUSE, ACHIEVEMENTS, DEATH }
const TOAST_SCRIPT := preload("res://scenes/gameplay/achievement_toasts.gd")
const UI_THEME := preload("res://scenes/gameplay/gameplay_ui_theme.tres")
static var _toasts: CanvasLayer

const DEFINITIONS := {
	"first_weapon": {"title": "借来一束光", "description": "首次拾取脉冲枪"},
	"first_terminal": {"title": "重新连接", "description": "首次激活终端"},
	"first_clear": {"title": "清理完成", "description": "首次击败房间内所有敌人"},
	"first_exit": {"title": "继续前行", "description": "首次抵达样板出口"},
}

var achievement_save_path := "user://achievements.cfg"
var achievements: Dictionary = {}
var page: Page = Page.CLOSED
var _content: VBoxContainer
var _overlay: Control
var _panel: PanelContainer
var _manual_list: VBoxContainer
var _manual_summary: Label
var _manual_progress: ProgressBar
var _search_text := ""
var _filter_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_load_achievements()
	if not is_instance_valid(_toasts):
		_toasts = TOAST_SCRIPT.new()
		_toasts.name = "AchievementNotifications"
		get_tree().root.add_child.call_deferred(_toasts)
	_overlay = Control.new()
	_overlay.theme = UI_THEME
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.016, 0.024, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480, 0)
	_panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.055, 0.065), 28))
	center.add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_panel.add_child(_content)
	_overlay.hide()


func toggle_pause() -> void:
	match page:
		Page.CLOSED:
			_show_page(Page.PAUSE)
		Page.PAUSE:
			close_and_resume()
		Page.ACHIEVEMENTS:
			_show_page(Page.PAUSE)
		Page.DEATH:
			pass


func show_death() -> void:
	_show_page(Page.DEATH)


func close_and_resume() -> void:
	page = Page.CLOSED
	_overlay.hide()
	get_tree().paused = false


func unlock_achievement(id: String) -> bool:
	if not DEFINITIONS.has(id) or achievements.get(id, false):
		return false
	achievements[id] = true
	var config := ConfigFile.new()
	for key in DEFINITIONS:
		config.set_value("achievements", key, achievements.get(key, false))
	var error := config.save(achievement_save_path)
	if error != OK:
		push_warning("成就记录保存失败：%s" % error_string(error))
	_toasts.show_achievement(id, DEFINITIONS[id], _completed_count(), DEFINITIONS.size())
	if page == Page.ACHIEVEMENTS:
		_refresh_handbook()
	return true


func _load_achievements() -> void:
	var config := ConfigFile.new()
	if config.load(achievement_save_path) != OK:
		return
	for key in DEFINITIONS:
		achievements[key] = config.get_value("achievements", key, false) == true


func _show_page(next_page: Page) -> void:
	page = next_page
	_panel.custom_minimum_size.x = 600 if page == Page.ACHIEVEMENTS else 480
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_overlay.show()
	get_tree().paused = true
	match page:
		Page.PAUSE:
			_label("暂停", 34, Color(0.96, 0.9, 0.73))
			_label("Esc 继续游戏", 16, Color(0.65, 0.75, 0.77))
			_button("继续游戏", close_and_resume)
			_button("成就手册", func(): _show_page(Page.ACHIEVEMENTS))
			_button("重试本房间", func(): retry_requested.emit())
			_button("返回标题", func(): title_requested.emit())
		Page.ACHIEVEMENTS:
			_label("成就手册", 34, Color(0.96, 0.9, 0.73))
			_build_handbook()
			_button("返回暂停菜单", func(): _show_page(Page.PAUSE))
		Page.DEATH:
			_label("信号中断", 34, Color(0.96, 0.9, 0.73))
			_label("重试将回到本房间入口", 16, Color(0.65, 0.75, 0.77))
			_button("重试本房间", func(): retry_requested.emit())
			_button("返回标题", func(): title_requested.emit())
	var first_button := _content.find_children("*", "Button", false, false)
	if not first_button.is_empty():
		first_button[0].call_deferred("grab_focus")


func _completed_count() -> int:
	var count := 0
	for id in DEFINITIONS:
		if achievements.get(id, false):
			count += 1
	return count


func _build_handbook() -> void:
	_manual_summary = _label("", 16, Color(0.65, 0.75, 0.77))
	_manual_progress = ProgressBar.new()
	_manual_progress.custom_minimum_size.y = 8
	_manual_progress.show_percentage = false
	_manual_progress.max_value = DEFINITIONS.size()
	_manual_progress.add_theme_stylebox_override("background", _style(Color(0.08, 0.12, 0.13), 0))
	_manual_progress.add_theme_stylebox_override("fill", _style(Color(0.35, 0.66, 0.61), 0))
	_content.add_child(_manual_progress)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	_content.add_child(toolbar)
	var search := LineEdit.new()
	search.placeholder_text = "搜索名称或完成条件"
	search.text = _search_text
	search.custom_minimum_size.y = 36
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.clear_button_enabled = true
	search.text_changed.connect(func(value: String):
		_search_text = value
		_refresh_handbook())
	toolbar.add_child(search)
	var filter := OptionButton.new()
	filter.add_item("全部成就")
	filter.add_item("未解锁")
	filter.add_item("已解锁")
	filter.select(_filter_index)
	filter.item_selected.connect(func(index: int):
		_filter_index = index
		_refresh_handbook())
	toolbar.add_child(filter)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 220
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_manual_list = VBoxContainer.new()
	_manual_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_manual_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_manual_list)
	_refresh_handbook()


func _refresh_handbook() -> void:
	_manual_summary.text = "已完成 %d / %d 项 · 记录保存在本机" % [_completed_count(), DEFINITIONS.size()]
	_manual_progress.value = _completed_count()
	for child in _manual_list.get_children():
		_manual_list.remove_child(child)
		child.queue_free()
	var query := _search_text.strip_edges().to_lower()
	for id in DEFINITIONS:
		var entry: Dictionary = DEFINITIONS[id]
		var unlocked: bool = achievements.get(id, false)
		if (_filter_index == 1 and unlocked) or (_filter_index == 2 and not unlocked):
			continue
		if not query.is_empty() and not (entry.title + " " + entry.description).to_lower().contains(query):
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(0.06, 0.105, 0.12) if unlocked else Color(0.04, 0.065, 0.075), 12))
		_manual_list.add_child(card)
		var details := VBoxContainer.new()
		details.add_theme_constant_override("separation", 6)
		card.add_child(details)
		var header := HBoxContainer.new()
		details.add_child(header)
		var name_label := Label.new()
		name_label.text = ("◆ " if unlocked else "◇ ") + entry.title
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.63) if unlocked else Color(0.72, 0.79, 0.8))
		header.add_child(name_label)
		var status := Label.new()
		status.text = "已解锁" if unlocked else "未解锁"
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color(0.57, 0.76, 0.73) if unlocked else Color(0.56, 0.63, 0.65))
		header.add_child(status)
		var condition := Label.new()
		condition.text = "完成条件：" + entry.description
		condition.add_theme_font_size_override("font_size", 15)
		condition.add_theme_color_override("font_color", Color(0.7, 0.77, 0.78))
		condition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(condition)
	if _manual_list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "没有符合条件的成就"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_manual_list.add_child(empty)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label


func _button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.9, 0.94, 0.91))
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.14, 0.16)))
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.24, 0.25)))
	button.add_theme_stylebox_override("pressed", _style(Color(0.055, 0.095, 0.11)))
	button.pressed.connect(callback)
	_content.add_child(button)


func _style(background: Color, margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.24, 0.48, 0.5, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style
