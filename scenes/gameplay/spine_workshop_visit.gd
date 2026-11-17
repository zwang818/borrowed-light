extends "res://scenes/gameplay/abdomen_level.gd"
## Revisit the actual abdomen map/workbench. First-level combat is already finished.
const FLOW := preload("res://scenes/gameplay/spine_flow_state.gd")
var transfer_payload: Dictionary = {}
var flow_state := FLOW.fresh()
var flow_data: Dictionary = {}
var flow_path := ""
var visit_ready := false
var visit_busy := false
var calibration_active := false
var calibration_targets: Array[Area2D] = []
var calibration_hits: Dictionary = {}
var calibration_direction := Vector2.RIGHT
var calibration_stand := Vector2.ZERO
var calibration_caption: Label
var craft_token := 0
var craft_action: Callable
var pending_live_snapshot: Dictionary = {}

func _setup_hud() -> void:
	super._setup_hud()
	# Retain the abdomen HUD's original face and metrics; fill only its missing
	# characters from the bundled second-level subset, without changing shared fonts.
	var visit_theme: Theme = UI_THEME.duplicate()
	var visit_font: Font = UI_THEME.default_font.duplicate()
	visit_font.fallbacks = [preload("res://assets/fonts/noto_sans_sc_spine_flow.ttf")]
	visit_theme.default_font = visit_font
	(hud_canvas.get_child(0) as Control).theme = visit_theme

func _ready() -> void:
	achievement_save_path = "user://spine_preview_achievements.cfg" if transfer_payload.get("isolated",true) else "user://achievements.cfg"
	if transfer_payload.is_empty() and get_tree().has_meta("journey_session"):
		var session: Dictionary = get_tree().get_meta("journey_session")
		flow_path = session.path
		flow_data = session.get("data",{}).duplicate(true)
		flow_state = FLOW.sanitize(flow_data.get("spine_flow",{}))
		achievement_save_path = "user://achievements.cfg" if not flow_path.is_empty() else "user://spine_preview_achievements.cfg"
	else:
		flow_path = transfer_payload.get("path","")
		flow_data = transfer_payload.get("data",{}).duplicate(true)
		flow_state = FLOW.sanitize(transfer_payload.get("state",{}))
		var transfer_data := flow_data.duplicate(true)
		transfer_data.erase("snapshot") # A spine snapshot is never an abdomen snapshot.
		get_tree().set_meta("journey_session",{"path":flow_path,"data":transfer_data})
	await super._ready()
	entry_ready = false
	journey_save_path = "" # Only the flow writer may update the owning journey.
	first_level_cleared = true
	blueprint_known = true
	pulse_learned = true
	workshop_seen = true
	terminal_activated = true
	for enemy in enemies:
		var snapshot: Dictionary = enemy.get_combat_state()
		snapshot.health = 0
		snapshot.alive = false
		enemy.restore_combat_state(snapshot)
	for object in interactables:
		if object.get_meta("is_door",false):
			object.get_child(0).set_deferred("disabled",true)
			object.set_meta("is_open",true)
			object.get_node("FacilityVisual").open_amount = 1.0
	for id in ducts:
		unlocked_ducts[id] = true
		ducts[id].visual.set_unlocked(true)
	var old = player
	old.set_script(preload("res://scenes/gameplay/spine_flow_player.gd"))
	player = old
	# Script replacement preserves Node children; bind inherited onready references.
	player.facing = player.get_node("Facing")
	player.pulse_gun = player.get_node("Facing/PulseGun")
	player.pulse_gun.muzzle_owner = player
	player.pressure_limited = true
	player.scatter_unlocked = flow_state.calibrated
	player.pressure = flow_state.ammo
	player.pressure_changed.connect(func(value): flow_state.ammo = value)
	var landing = _duct_landing(&"duct_arrival")
	if landing != null and pending_live_snapshot.is_empty(): player.restore_player(landing,transfer_payload.get("health",player.max_health),[&"pulse_gun"])
	player.scatter_unlocked = flow_state.calibrated
	camera.global_position = player.global_position
	camera.reset_smoothing()
	flow_state.room = "workshop"
	interaction_sheet.finished.disconnect(finish_interaction)
	interaction_sheet.finished.connect(_finish_craft_dialogue)
	interaction_sheet.presentation_theme = preload("res://scenes/gameplay/spine_flow_theme.tres")
	if not pending_live_snapshot.is_empty():
		super._restore_room_snapshot(pending_live_snapshot)
		pending_live_snapshot = {}
		camera.global_position = player.global_position
		camera.reset_smoothing()
	visit_ready = true
	entry_ready = true
	if flow_state.assembled and not flow_state.calibrated: _start_calibration.call_deferred()

func _configure_player() -> void:
	await super._configure_player()

func _process(delta: float) -> void:
	if not visit_ready: return
	super._process(delta)
	if get_tree().paused: return
	var bench: Vector2 = interaction_points[&"pulse_workbench"].global_position
	var duct: Vector2 = ducts[&"duct_arrival"].point.global_position
	var text := ""
	if player.global_position.distance_to(bench)<95:
		text = "[%s] %s" % [INPUT_BINDINGS.action_label(&"interact"),"接入散射制造台" if not flow_state.calibrated else "散射机械臂已完成"]
	elif player.global_position.distance_to(duct)<88:
		text = "[%s] 返回输能脊柱" % INPUT_BINDINGS.action_label(&"interact")
	if not text.is_empty():
		interact_label.text = text
		interact_label.show()
		interact_bg.show()
	if calibration_active:
		calibration_caption.text = "散射校准 · 站稳并瞄准两个触点之间，一次齐射点亮两点。"

func _try_interact() -> void:
	if not visit_ready or visit_busy or player.is_dead: return
	var bench: Vector2 = interaction_points[&"pulse_workbench"].global_position
	if player.global_position.distance_to(bench)<95 and _visit_line_clear(player.global_position,bench):
		if not flow_state.calibrated: _assemble()
		return
	var duct: Vector2 = ducts[&"duct_arrival"].point.global_position
	if player.global_position.distance_to(duct)<88:
		if flow_state.calibrated: _return_spine()
		else: _show_notification("先到原制造台完成右臂装配与双触点校准。",3)

func _visit_line_clear(from: Vector2,to: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1)).is_empty()

func _assemble() -> void:
	if calibration_active: return
	visit_busy = true
	craft_token += 1
	get_tree().paused = true
	interaction_sheet.present(craft_token,{"title":"腹腔原制造台 · 右臂装配","category":"通讯","summary":"","confirm":"装配并开始试射","dialogue":[{"speaker":"神明","text":"图纸与右臂接口已经对上。装好后，试着让一束散射同时点亮两枚触点。"},{"speaker":"小一","text":"我来调整距离和角度。"}]})

func _finish_craft_dialogue(token: int,completed: bool) -> void:
	if token!=craft_token: return
	visit_busy = false
	get_tree().paused = false
	if completed:
		flow_state.assembled = true
		_start_calibration()

func _start_calibration() -> void:
	if calibration_active or flow_state.calibrated: return
	calibration_active = true
	player.calibration_enabled = true
	player.set_attack_mode(player.AttackMode.SCATTER)
	var base = map.get_node("Walls/AssemblyBase")
	# D moved the operator tread; anchor physical targets to the machine itself.
	var bench: Vector2 = base.to_global(Vector2(base.size.x*0.5,base.size.y+4))
	var found := false
	for offset in [Vector2(60,80),Vector2(40,120),Vector2(60,140),Vector2(20,160),Vector2(80,100)]:
		for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
			var stand: Vector2 = bench+offset
			var center: Vector2 = stand+direction*110+direction.orthogonal()*-18
			var a: Vector2 = center+direction.orthogonal()*16
			var b: Vector2 = center-direction.orthogonal()*16
			if _on_floor(stand) and _on_floor(a) and _on_floor(b) and _visit_line_clear(stand,a) and _visit_line_clear(stand,b):
				calibration_stand = stand
				calibration_direction = direction
				for i in range(2):
					var target = preload("res://scenes/gameplay/spine_calibration_target.gd").new()
					target.index = i
					target.position = a if i==0 else b
					target.scatter_hit.connect(_calibration_hit)
					add_child(target)
					calibration_targets.append(target)
				found = true
				break
		if found: break
	calibration_caption = Label.new()
	calibration_caption.theme = preload("res://scenes/gameplay/spine_flow_theme.tres")
	calibration_caption.position = Vector2(24,110)
	hud_canvas.add_child(calibration_caption)
	if not found:
		calibration_active = false
		player.calibration_enabled = false
		_show_notification("校准区域被占用，请重新接入制造台。",4)
	_save_journey()
	queue_redraw()

func _on_floor(point: Vector2) -> bool:
	for floor_node in map.get_node("Floors").get_children():
		if Rect2(Vector2.ZERO,floor_node.size).grow(-18).has_point(floor_node.to_local(point)):
			var shape := PhysicsShapeQueryParameters2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 14
			shape.shape = circle
			shape.transform = Transform2D(0,point)
			shape.collision_mask = 1
			return get_world_2d().direct_space_state.intersect_shape(shape,1).is_empty()
	return false

func _calibration_hit(index: int,burst: int) -> void:
	if not calibration_active: return
	if not calibration_hits.has(burst): calibration_hits[burst] = {}
	calibration_hits[burst][index] = true
	if calibration_hits[burst].size()<2: return
	calibration_active = false
	player.calibration_enabled = false
	player.scatter_unlocked = true
	flow_state.calibrated = true
	flow_state.ammo = 0
	player.pressure = 0
	for target in calibration_targets: target.set_deferred("monitorable",false)
	calibration_caption.text = "校准完成 · 右臂已解锁。返回脊柱，在取液台补充压力。"
	_save_journey()
	queue_redraw()

func _on_exit_entered(_body: Node,_id: String) -> void:
	pass # Revisit leaves through the same arrival duct, never repeats level one.

func _retry_level() -> void:
	game_menus.close_and_resume()
	var landing = _duct_landing(&"duct_arrival")
	if landing != null:
		player.restore_player(landing,player.max_health,[&"pulse_gun"])
		player.scatter_unlocked = flow_state.calibrated
		player.calibration_enabled = calibration_active

func _save_journey(_show_result: bool = false) -> Error:
	if not visit_ready: return OK
	flow_state.ammo = player.pressure
	var candidate := flow_data.duplicate(true)
	candidate.snapshot = _capture_room_snapshot()
	var result := FLOW.save(flow_path,candidate,flow_state)
	if result == OK: flow_data = candidate
	else: _show_notification("存档失败，请检查磁盘空间或文件权限。",4)
	return result

func _restore_room_snapshot(snapshot: Dictionary) -> void:
	# Replacing the player script later in _ready resets script-owned properties.
	# Defer until the real flow player, physics and persistent ability are installed.
	pending_live_snapshot = snapshot.duplicate(true)

func _return_to_title() -> void:
	if _save_journey()!=OK: return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _return_spine() -> void:
	visit_busy = true
	player.pulse_gun.cancel()
	var loader = preload("res://scenes/gameplay/spine_flow_loading.gd").new()
	loader.name = "EntryLoading"
	loader.source = self
	loader.payload = {"state":flow_state.duplicate(true),"path":flow_path,"data":flow_data.duplicate(true),"health":player.health,"isolated":transfer_payload.get("isolated",flow_path.is_empty())}
	get_tree().root.add_child(loader)
	loader.begin("res://scenes/gameplay/spine_level.tscn")

func finish_flow_transfer(_payload: Dictionary) -> bool:
	if not _on_floor(player.global_position): return false
	return _save_journey()==OK

func flow_transfer_cancelled() -> void: visit_busy = false

func _draw() -> void:
	if not calibration_active: return
	draw_arc(calibration_stand,14,0,TAU,24,Color("a6cec3"),2)
