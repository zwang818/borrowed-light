extends RefCounted
## Room-checkpoint persistence. JSON contains data only, never executable resources.
const DEFAULT_PATH := "user://journey_save.json"
const SCENE := "res://scenes/gameplay/abdomen_level.tscn"
const FLAGS := ["blueprint_known", "pulse_learned", "workshop_seen"]
const DUCTS := ["duct_arrival", "duct_weapon", "duct_exit"]

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var data = parser.data
	if not data is Dictionary or data.get("version") != 1 or data.get("scene") != SCENE:
		return {}
	if not data.get("saved_at") is String or not data.get("ducts") is Array or not data.get("explored") is Array:
		return {}
	if data.saved_at.length() > 32 or data.ducts.size() > DUCTS.size():
		return {}
	for flag in FLAGS:
		if not data.get(flag) is bool:
			return {}
	if data.pulse_learned and not data.blueprint_known:
		return {}
	if data.has("first_level_cleared") and not data.first_level_cleared is bool:
		return {}
	data["first_level_cleared"] = data.get("first_level_cleared", false)
	var seen: Dictionary = {}
	for id in data.ducts:
		if not id is String or not (id in DUCTS) or seen.has(id):
			return {}
		seen[id] = true
	if data.explored.size() > 2048:
		return {}
	for point in data.explored:
		if not point is Array or point.size() != 2:
			return {}
		for coordinate in point:
			if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(float(coordinate)) > 10000:
				return {}
	return data

static func read_save(path: String = DEFAULT_PATH) -> Dictionary:
	var data := _read(path)
	if data.is_empty():
		data = _read(path + ".bak")
		if not data.is_empty():
			data["recovered"] = true
	return data

static func write_save(path: String, knowledge: Dictionary) -> Error:
	var data := knowledge.duplicate(true)
	data.erase("recovered")
	data["version"] = 1
	data["scene"] = SCENE
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or _read(temporary).is_empty():
		return ERR_FILE_CANT_WRITE
	# Preserve the last readable main file; a corrupt main must not replace a backup.
	if not _read(path).is_empty():
		if FileAccess.file_exists(path + ".bak"):
			result = DirAccess.remove_absolute(path + ".bak")
			if result != OK:
				return result
		result = DirAccess.rename_absolute(path, path + ".bak")
	elif FileAccess.file_exists(path):
		result = DirAccess.remove_absolute(path)
	if result != OK:
		return result
	return DirAccess.rename_absolute(temporary, path)

static func erase(path: String) -> Error:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			var error := DirAccess.remove_absolute(path + suffix)
			if error != OK:
				return error
	return OK
