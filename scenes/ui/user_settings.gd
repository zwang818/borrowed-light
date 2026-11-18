extends RefCounted
## Preferences are independent from journey/achievement progress. No Autoload needed.
const BINDINGS := preload("res://scenes/gameplay/input_bindings.gd")
const DEFAULT_PATH := "user://settings.cfg"
const MUSIC_BUS := &"BorrowedLightMusic"
const UI_BUS := &"BorrowedLightUI"
const WINDOW_SIZES := [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]

static func defaults() -> Dictionary:
	return {"master":1.0,"music":1.0,"ui":1.0,"fullscreen":false,"size":Vector2i(1152,648),"vsync":true,"bindings":BINDINGS.defaults()}

static func read_preferences(path: String = DEFAULT_PATH) -> Dictionary:
	var data := defaults()
	var config := ConfigFile.new()
	if config.load(path) != OK: return data
	for key in ["master","music","ui"]:
		var raw = config.get_value("audio",key,data[key])
		if (raw is float or raw is int) and is_finite(float(raw)):
			data[key] = clampf(float(raw),0.0,1.0)
	for key in ["fullscreen","vsync"]:
		var raw = config.get_value("display",key,data[key])
		if raw is bool: data[key] = raw
	var window_size = config.get_value("display","size",data["size"])
	if window_size is Vector2i and window_size in WINDOW_SIZES: data["size"] = window_size
	data.bindings = BINDINGS.sanitize(config.get_value("controls","bindings",data.bindings))
	return data

static func save_preferences(data: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var config := ConfigFile.new()
	for key in ["master","music","ui"]: config.set_value("audio",key,data[key])
	for key in ["fullscreen","size","vsync"]: config.set_value("display",key,data[key])
	config.set_value("controls","bindings",data.bindings)
	return config.save(path)

static func ensure_audio_buses() -> void:
	for bus in [MUSIC_BUS,UI_BUS]:
		if AudioServer.get_bus_index(bus) >= 0: continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,bus)
		AudioServer.set_bus_send(index,&"Master")

static func apply_audio(data: Dictionary) -> void:
	ensure_audio_buses()
	for pair in [[&"Master","master"],[MUSIC_BUS,"music"],[UI_BUS,"ui"]]:
		var index := AudioServer.get_bus_index(pair[0])
		var volume: float = data[pair[1]]
		AudioServer.set_bus_mute(index,volume <= 0.0)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,volume)))

static func apply_display(data: Dictionary, window: Window) -> void:
	if DisplayServer.get_name() == "headless": return
	if data.fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		# Never place an oversized window outside the current monitor's usable area.
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		var requested: Vector2i = data["size"]
		window.size = Vector2i(mini(requested.x,usable.size.x),mini(requested.y,maxi(360,usable.size.y-48)))
		window.position = usable.position+(usable.size-window.size)/2
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED,window.get_window_id())
