extends RefCounted
## Serializable knowledge is separate from room baselines and transient combat.
const FLAGS := ["first_fall", "hatch_open", "record_read", "receipt_learned", "scatter_blueprint", "assembled", "calibrated", "fluid_tutorial", "completed"]
const SERVICE_CHECKPOINT := "service_exit"
static func fresh() -> Dictionary:
	var state := {"ammo": 0, "capacity": 4, "room": "spine", "baseline": {}, "checkpoint": "entry"}
	for flag in FLAGS: state[flag] = false
	return state

static func sanitize(raw: Variant) -> Dictionary:
	var result := fresh()
	if not raw is Dictionary: return result
	for flag in FLAGS:
		if raw.get(flag) is bool: result[flag] = raw[flag]
	if raw.get("capacity") is int or raw.get("capacity") is float: result.capacity = clampi(int(raw.capacity),1,12)
	if raw.get("ammo") is int or raw.get("ammo") is float: result.ammo = clampi(int(raw.ammo),0,result.capacity)
	result.room = "workshop" if raw.get("room") == "workshop" else "spine"
	result.checkpoint = "return" if raw.get("checkpoint") == "return" else "entry"
	if raw.get("checkpoint") == SERVICE_CHECKPOINT and result.hatch_open:
		result.checkpoint = SERVICE_CHECKPOINT
	if raw.get("baseline") is Dictionary:
		var base: Dictionary = raw.baseline
		result.baseline = {"gate":base.get("gate",false)==true,"exit":base.get("exit",false)==true,"units":[]}
		if base.get("units") is Array and base.units.size()<=64:
			for unit in base.units:
				if not unit is Dictionary or not unit.get("id") is String or not unit.get("health") is int and not unit.get("health") is float: continue
				var pos = unit.get("position")
				if not pos is Array or pos.size()!=2: continue
				if not (pos[0] is float or pos[0] is int) or not (pos[1] is float or pos[1] is int): continue
				if not is_finite(float(pos[0])) or not is_finite(float(pos[1])) or absf(float(pos[0]))>20000 or absf(float(pos[1]))>20000: continue
				result.baseline.units.append({"id":unit.id,"health":clampi(int(unit.health),0,999),"position":pos.duplicate()})
	return result

static func save(path: String, original: Dictionary, state: Dictionary) -> Error:
	if path.is_empty(): return OK # Independent F6 session never writes a journey.
	var data := original.duplicate(true)
	data.merge({"blueprint_known": true, "pulse_learned": true, "workshop_seen": false, "ducts": [], "explored": []}, false)
	data.first_level_cleared = true
	data.scatter_unlocked = state.calibrated
	data.spine_flow = sanitize(state)
	var journey = preload("res://scenes/gameplay/journey_save.gd")
	var room: String = journey.SCENE if state.room == "workshop" or not data.has("snapshot") else journey.SPINE
	return journey.write_save(path, data, room)
