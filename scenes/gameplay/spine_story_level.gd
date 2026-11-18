extends "res://scenes/gameplay/spine_level.gd"
## Interactive v5 flow on A's source map and B's real player/weapons/enemies.
const FLOW := preload("res://scenes/gameplay/spine_flow_state.gd")
const INPUT := preload("res://scenes/gameplay/input_bindings.gd")
const F := Vector2(0.9063078,-0.4226183)
@export var isolate_progress := false
@export_enum("入口", "检修观察位", "图纸返程平台") var playtest_start := 0
var transfer_payload: Dictionary = {}
var state := FLOW.fresh()
var story_ready := false
var busy := false
var sheet
var dialog_action: Callable
var dialog_token := 0
var dialog_required := false
var protocol_panel
var defense
var signals
var demo_cleaner
var authorized_gate
var exit_gate
var gate_receipting := false
var baseline_gate := false
var baseline_exit := false
var record_cued := false
var scan_done := false
var scan_time := 0.0
var refill_time := -1.0
var complete_panel: CanvasLayer
var prompt: Label
var pressure_label: Label
var nearest := ""
var death_pending := false
var saved_receipt := false
var protocol_armed := false
var world_revision := 0
var tree_installed := false
var demo_controlled := false
var demo_viewed := false
var pending_live_snapshot: Dictionary = {}

func hero(): return $SpawnPoints/PlayerSpawn/Player
func anchor(key: String) -> Vector2:
	var aliases := {"MaintenanceRecord":"OptionalRecord", "ReturnDuct":"BlueprintDuct", "ScatterCheckpoint":"Checkpoint", "ThoraxEntry":"ToThorax"}
	return map.get_node("Markers/"+aliases.get(key,key)).global_position

func _enter_tree() -> void:
	if tree_installed: return # A cancelled transactional transfer reattaches this room.
	tree_installed = true
	super._enter_tree()
	$SpawnPoints/PlayerSpawn/Player.set_script(preload("res://scenes/gameplay/spine_flow_player.gd"))

func _ready() -> void:
	# The base creates menus during _ready: establish the real save owner first.
	if not transfer_payload.is_empty():
		save_path = transfer_payload.get("path","")
		var transfer_data: Dictionary = transfer_payload.get("data",{}).duplicate(true)
		transfer_data.erase("snapshot") # Never restore the source abdomen in the spine.
		get_tree().set_meta("journey_session",{"path":save_path,"data":transfer_data})
	await super._ready()
	entry_ready = false
	add_child(scatter_approach) # Own the base prompt even though this flow hides it.
	scatter_approach.hide()
	# The formal story defense owns damage/timing; keep B preview hazards separate.
	entrance_hazards.process_mode = Node.PROCESS_MODE_DISABLED
	entrance_hazards.hide()
	if isolate_progress: save_path = ""
	state = FLOW.sanitize(transfer_payload.get("state",save_data.get("spine_flow",{})))
	if transfer_payload.is_empty() and not save_data.has("spine_flow") and save_data.get("scatter_unlocked",false):
		state.scatter_blueprint = true
		state.assembled = true
		state.calibrated = true
	if not transfer_payload.is_empty():
		save_path = transfer_payload.get("path","")
		save_data = transfer_payload.get("data",{}).duplicate(true)
		isolate_progress = transfer_payload.get("isolated",false)
	state.room = "spine"
	hero().pressure_limited = true
	hero().pressure = state.ammo
	hero().scatter_unlocked = state.calibrated
	hero().pressure_changed.connect(func(value): state.ammo = value)
	$SpawnPoints/SentrySpawn/Sentry.entity_id = "p2_sentry_01"
	demo_cleaner = $SpawnPoints/CleanerSpawn/Cleaner
	demo_cleaner.entity_id = "p2_cleaner_01"
	demo_cleaner.patrol_offsets = PackedVector2Array([Vector2.ZERO, F*36])
	for i in range(2): baselines[i].state = enemies[i].get_combat_state().duplicate(true)
	for unit in enemies:
		if unit is CharacterBody2D:
			unit.set_meta("story_patrol",unit.patrol_offsets)
			unit.visibility_query = _cleaner_on_screen
			unit.protocol_query = _test_protocol_active
	_spawn_gate_sentry()
	authorized_gate = _door("p2_authorized_door")
	exit_gate = _door("p2_exit_door")
	if _door("p2_defense_isolation_gate") == null: _make_door(map.get_node("Markers/IsolationGate"))
	_door("p2_defense_isolation_gate").set_open(false)
	_restore_baseline()
	map.set_service_passage_state(map.ServicePassage.OPEN if state.hatch_open else (map.ServicePassage.REVEALED if state.first_fall else map.ServicePassage.CONCEALED))
	defense = preload("res://scenes/gameplay/spine_story_defense.gd").new()
	defense.name = "EntranceDefenseGameplay"
	defense.flow = self
	add_child(defense)
	defense.configure(map,hero())
	signals = preload("res://scenes/gameplay/spine_story_signals.gd").new()
	signals.flow = self
	add_child(signals)
	sheet = preload("res://scenes/gameplay/interaction_sheet.gd").new()
	add_child(sheet)
	sheet.finished.connect(_dialog_finished)
	var hud := CanvasLayer.new()
	add_child(hud)
	prompt = Label.new()
	prompt.theme = health_display.theme
	prompt.position = Vector2(24,158)
	hud.add_child(prompt)
	pressure_label = Label.new()
	pressure_label.theme = health_display.theme
	pressure_label.position = Vector2(24,112)
	hud.add_child(pressure_label)
	notice.hide()
	health_display.theme = preload("res://scenes/gameplay/spine_flow_theme.tres")
	prompt.theme = health_display.theme
	pressure_label.theme = health_display.theme
	sheet.presentation_theme = health_display.theme
	if pending_live_snapshot.is_empty() and (not transfer_payload.is_empty() or state.checkpoint == "return"):
		hero().global_position = anchor("ScatterReturnEntry")
	elif pending_live_snapshot.is_empty() and state.first_fall:
		hero().global_position = anchor("DefenseSafePocket")
	if playtest_start > 0 and isolate_progress:
		state.first_fall = true
		state.hatch_open = true
		map.set_service_passage_state(map.ServicePassage.OPEN)
		hero().global_position = anchor("ProtocolObservation")
		if playtest_start == 2:
			state.receipt_learned = true
			authorized_gate.set_open(true)
			hero().global_position = anchor("ScatterReturnEntry")
	baseline_gate = authorized_gate.is_open
	baseline_exit = exit_gate.is_open
	if not pending_live_snapshot.is_empty():
		_apply_live_snapshot(pending_live_snapshot)
		pending_live_snapshot = {}
	story_ready = true
	entry_ready = true
	_update_camera()
	$Camera2D.reset_smoothing()
	# The base cannot capture story nodes before this asynchronous setup finishes.
	if not save_path.is_empty() and transfer_payload.is_empty(): _save_progress(false)
	if not get_tree().root.has_node("EntryLoading"): on_entry_revealed()

func _spawn_gate_sentry() -> void:
	var unit = preload("res://scenes/enemies/sentry/sentry.tscn").instantiate()
	unit.set_script(preload("res://tests/manual/b_combat/floating_sentry.gd"))
	unit.entity_id = "p2_protocol_gate_sentry"
	unit.position = anchor("ProtocolGateSentry")
	add_child(unit)
	unit.configure(hero(),_test_enemy_readable,$EnemyProjectiles)
	_register_enemy(unit)

func _make_door(marker: Node2D) -> void:
	var door = preload("res://scenes/gameplay/spine_flow_gate.gd").new()
	door.transform = marker.transform
	door.size = marker.footprint
	door.set_meta("stable_id",marker.object_id)
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	body.add_child(collision)
	door.add_child(body)
	var occluder := LightOccluder2D.new()
	occluder.name = "Occluder"
	door.add_child(occluder)
	add_child(door)
	door.set_open(false)
	doors.append(door)

func _door(id: String):
	for door in doors:
		if door.get_meta("stable_id","") == id: return door
	return null

func _install_electric_seams(_parent: Node) -> void:
	pass # v5's eight emitters/seven rings replace the obsolete entry seam overlay.

func _test_enemy_readable(enemy: Node2D) -> bool:
	return super._test_enemy_readable(enemy) and _line_clear(hero().global_position,enemy.global_position)

func _sentry_on_screen(enemy: Node2D) -> bool:
	return super._sentry_on_screen(enemy) and _line_clear(hero().global_position,enemy.global_position)

func _cleaner_on_screen(enemy: Node2D) -> bool:
	return super._cleaner_on_screen(enemy) and _line_clear(hero().global_position,enemy.global_position)

func _line_clear(from: Vector2, to: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1)).is_empty()

func _process(_delta: float) -> void:
	if not story_ready: return
	_update_camera()
	health_display.set_health(hero().health,hero().max_health)
	hero().modulate = Color(0.62,0.83,0.92,0.82) if hero().has_protocol else Color.WHITE
	pressure_label.text = "右臂蓄压  %d / %d" % [hero().pressure,state.capacity] if state.calibrated else ""
	_update_prompt()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not story_ready or hero().is_dead or busy: return
	var zone = map.get_node("Reservations/ProtocolZone")
	var inside := Rect2(Vector2.ZERO,zone.size).has_point(zone.to_local(hero().global_position))
	inside = inside or hero().global_position.distance_to(anchor("ProtocolTerminalUse")) < 95
	if hero().has_protocol and not inside:
		hero().set_protocol_active(false)
		scan_done = false
	if inside and protocol_armed and state.receipt_learned and not hero().has_protocol and not saved_receipt:
		hero().set_protocol_active(true)
	if not inside: saved_receipt = false
	_update_demonstration(delta)
	_update_scanning(delta)
	if not record_cued and hero().global_position.distance_to(map.get_node("RouteWaypoints/RecordRoute/Point00").global_position) < 110:
		record_cued = true
		signals.record_at = anchor("MaintenanceRecord")
		signals.record_clock = 0
	if state.calibrated and hero().global_position.distance_to(anchor("ScatterCheckpoint")) < 48:
		state.checkpoint = "return"
	if refill_time >= 0:
		if hero().global_position.distance_to(anchor("SpinalFluidTapUse")) > 100:
			refill_time = -1
		else:
			refill_time += delta
			if refill_time >= 1.6:
				hero().pressure = state.capacity
				state.ammo = hero().pressure
				state.fluid_tutorial = true
				refill_time = -1
				_save_progress()
	if exit_gate.is_open and hero().global_position.distance_to(anchor("ThoraxEntry")) < 76:
		_finish_level()

func _update_demonstration(_delta: float) -> void:
	var observe: bool = not state.receipt_learned and demo_cleaner.health>0 and hero().global_position.distance_to(anchor("ProtocolObservation"))<200 and not demo_cleaner.can_detect()
	if not observe:
		if demo_controlled: demo_cleaner.set_physics_process(true)
		demo_controlled = false
		return
	if not demo_viewed:
		demo_viewed = true
		signals.clock = 0
	demo_controlled = true
	demo_cleaner.set_physics_process(false)
	var phase := fposmod(signals.clock,5)
	if phase<0.35:
		demo_cleaner.move_toward_point(anchor("ProtocolCleaner"),128)
	elif phase<4.3:
		demo_cleaner.velocity = Vector2.ZERO
		demo_cleaner.get_node("Facing").rotation = demo_cleaner.global_position.direction_to(anchor("ProtocolDemoReader")).angle()
	else:
		demo_cleaner.move_toward_point(anchor("ProtocolCleaner")-F*44,90)

func _update_scanning(delta: float) -> void:
	if not is_instance_valid(demo_cleaner) or demo_cleaner.health<=0: return
	if not hero().has_protocol:
		if not demo_controlled: demo_cleaner.set_physics_process(true)
		return
	if scan_done or hero().global_position.distance_to(demo_cleaner.global_position)>160: return
	demo_cleaner.set_physics_process(false)
	scan_time += delta
	demo_cleaner.velocity = Vector2.ZERO
	if scan_time < 0.55:
		demo_cleaner.move_toward_point(hero().global_position-F*54,50)
	elif scan_time < 1.3:
		demo_cleaner.get_node("Facing").rotation = demo_cleaner.global_position.direction_to(hero().global_position).angle()
	else:
		scan_done = true
		demo_cleaner.patrol_offsets = PackedVector2Array([F*42, -F*42])
		demo_cleaner.set_physics_process(true)

func _update_scatter_prompt() -> void:
	if is_instance_valid(scatter_prompt): scatter_prompt.hide()
	if is_instance_valid(scatter_station): scatter_station.hide()

func try_unlock_scatter() -> bool:
	# Production acquisition is the abdomen manufacture/calibration transaction.
	return false

func _interaction_candidates() -> Dictionary:
	return {"MaintenanceHatch": "开启检修盖板" if state.first_fall else "检查装甲接缝", "MaintenanceRecord":"查看旧记录", "ProtocolTerminalUse":"接入检修终端", "ProtocolDemoReader":"重放维护灯语", "ProtocolGateReader":"发送维护回执", "ScatterEvolution":"重看散射图纸" if state.scatter_blueprint else "读取散射图纸", "ReturnDuct":"进入返程井", "SpinalFluidTapUse":"接入脊液补能", "ExitTerminal":"接入胸腔终端"}

func _update_prompt() -> void:
	nearest = ""
	var distance := 89.0
	var candidates := _interaction_candidates()
	for key in candidates:
		var at := anchor(key)
		var d: float = hero().global_position.distance_to(at)
		if d < distance and _interaction_clear(hero().global_position,at,key):
			nearest = key
			distance = d
	prompt.text = "[%s] %s" % [INPUT.action_label(&"interact"),candidates[nearest]] if not nearest.is_empty() and not busy else ""
	if refill_time >= 0: prompt.text = "脊液接入  %d%%" % int(refill_time/1.6*100)

func _interaction_clear(from: Vector2, to: Vector2, key: String) -> bool:
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1))
	if hit.is_empty(): return true
	# The authored hatch seal is the interaction target, not an intervening wall.
	return key == "MaintenanceHatch" and str(hit.collider.get_path()).contains("ServiceSeals") and Vector2(hit.position).distance_to(to) < 60

func _unhandled_key_input(event: InputEvent) -> void:
	if not story_ready or event.is_echo(): return
	if event.is_action_pressed("protocol_exit") and hero().has_protocol:
		hero().set_protocol_active(false)
		saved_receipt = true
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and not busy and not hero().is_dead:
		_update_prompt()
		if not nearest.is_empty():
			interact(nearest)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Remapped mouse buttons and scripted actions share the same interaction gate.
	if not event is InputEventKey: _unhandled_key_input(event)

func interact(key: String) -> void:
	if busy or hero().is_dead: return
	if hero().global_position.distance_to(anchor(key)) > 89 or not _interaction_clear(hero().global_position,anchor(key),key): return
	match key:
		"MaintenanceHatch":
			if not state.first_fall:
				_talk("装甲接缝",["小一|装甲下面，好像有气流。"],func(): pass)
			else:
				state.hatch_open = true
				map.set_service_passage_state(map.ServicePassage.OPEN)
				_save_progress()
		"MaintenanceRecord":
			_talk("旧记录 · 按事件先后排列",["记录|较早：返程路线已预约。", "记录|较晚：收到求救通讯。", "小一|这条返程记录……比那次通话还早。"],func(): state.record_read = true; _save_progress())
		"ProtocolDemoReader":
			signals.clock = 0
			_talk("维护读头",["小一|它的背灯和读头，正在交换同一段信号。"],func(): pass)
		"ProtocolTerminalUse": _open_protocol()
		"ProtocolGateReader": _authorize_gate()
		"ScatterEvolution":
			_talk("散射机械臂图纸",["小一|右臂的接口……原来还空着。", "神明|把图纸带回腹腔的制造台。旁边的返程井还接着你醒来的地方。"],func(): state.scatter_blueprint = true; _save_progress())
		"ReturnDuct":
			if not state.scatter_blueprint:
				_talk("返程井",["小一|井边的图纸台还留着一份记录。"],func(): pass)
			else:
				signals.record_at = anchor("ReturnDuct")
				signals.record_clock = 0
				_begin_workshop_trip()
		"SpinalFluidTapUse":
			if not state.calibrated:
				_talk("脊液取液台",["小一|压力接口和右臂的图纸一致，装配后再来接入吧。"],func(): pass)
			elif not state.fluid_tutorial:
				_talk("脊柱循环工质",["神明|这里循环的是蓄压脊液。你的右臂每次齐射，都要释放一份压力。", "小一|空了就回来补充。左臂的激光，还能继续用。"],func(): refill_time = 0)
			else: refill_time = 0
		"ExitTerminal":
			if not state.calibrated:
				_talk("胸腔接头",["神明|胸腔的接口需要你的双臂模块。先把右臂带回来，小一。"],func(): pass)
			else:
				_talk("胸腔接头",["神明|沿着这些管线走，小一。我在更深的地方。"],func(): exit_gate.unlock())

func _talk(title: String, lines: Array, action: Callable, required: bool = false) -> void:
	busy = true
	dialog_required = required
	dialog_action = action
	dialog_token += 1
	var dialogue: Array = []
	for line in lines:
		var pair: PackedStringArray = line.split("|",true,1)
		dialogue.append({"speaker":pair[0],"text":pair[1]})
	hero().pulse_gun.cancel()
	hero().velocity = Vector2.ZERO
	get_tree().paused = true
	sheet.present(dialog_token,{"title":title,"category":"通讯","summary":"","confirm":"结束通讯","dialogue":dialogue})

func _dialog_finished(token: int, completed: bool) -> void:
	if token != dialog_token: return
	var action := dialog_action
	if dialog_required: map.set_service_passage_state(map.ServicePassage.REVEALED)
	dialog_action = Callable()
	busy = false
	get_tree().paused = false
	if completed and action.is_valid(): action.call()

func _open_protocol() -> void:
	if state.receipt_learned:
		protocol_armed = true
		hero().set_protocol_active(true)
		saved_receipt = false
		return
	busy = true
	hero().pulse_gun.cancel()
	get_tree().paused = true
	protocol_panel = preload("res://scenes/gameplay/spine_protocol_panel.gd").new()
	add_child(protocol_panel)
	protocol_panel.submitted.connect(func(correct):
		if correct:
			state.receipt_learned = true
			protocol_armed = true
			hero().set_protocol_active(true)
			_save_progress())
	protocol_panel.closed.connect(func(): busy = false; get_tree().paused = false)

func _authorize_gate() -> void:
	if not state.receipt_learned:
		_talk("门侧读头",["小一|它在等维护回执。我得先观察检修窗里的信号。"],func(): pass)
		return
	if authorized_gate.is_open: return
	busy = true
	gate_receipting = true
	var revision := world_revision
	hero().set_protocol_active(true)
	signals.clock = 0
	await get_tree().create_timer(2.0,false).timeout
	if hero().is_dead or revision != world_revision:
		busy = false
		gate_receipting = false
		return
	for pair in [["p2_cleaner_05","ProtocolYieldRear"],["p2_cleaner_06","ProtocolYieldFront"]]:
		for unit in enemies:
			if unit.entity_id == pair[0] and unit.health > 0:
				unit.home = anchor(pair[1])
				unit.patrol_offsets = PackedVector2Array([Vector2.ZERO])
				unit.patrol_index = 0
				unit.move_toward_point(unit.home,55)
	authorized_gate.unlock()
	await authorized_gate.opened
	if revision != world_revision: return
	gate_receipting = false
	busy = false

func _on_player_died() -> void:
	if death_pending: return
	if not state.first_fall:
		death_pending = true
		_recover_first_fall.call_deferred()
	else:
		menus.show_death()

func _recover_first_fall() -> void:
	busy = true
	get_tree().paused = true
	var fade := CanvasLayer.new()
	fade.layer = 24
	fade.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade)
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.02,0.025,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.add_child(shade)
	await get_tree().create_timer(0.35,true).timeout
	state.first_fall = true
	hero().restore_player(anchor("DefenseSafePocket"),hero().max_health,[&"pulse_gun"])
	hero().scatter_unlocked = state.calibrated
	hero().pressure = state.ammo
	defense.orbs.clear()
	_update_camera()
	$Camera2D.reset_smoothing()
	$Camera2D.force_update_scroll()
	map.set_service_passage_state(map.ServicePassage.REVEALED)
	death_pending = false
	fade.queue_free()
	_talk("通讯重新接通",["神明|等一下……我记得装甲下面有一道检修缝。你顺着那根回流管找找。", "小一|我看见接缝里的灯了。我会从下面过去。"],func(): _save_progress(),true)

func _retry() -> void:
	world_revision += 1
	busy = false
	gate_receipting = false
	refill_time = -1
	protocol_armed = false
	scan_time = 0
	scan_done = false
	if is_instance_valid(protocol_panel): protocol_panel.queue_free()
	sheet.dismiss()
	menus.close_and_resume()
	reset_test_combat()
	for i in range(enemies.size()):
		if enemies[i] is CharacterBody2D:
			enemies[i].home = baselines[i].position
			enemies[i].patrol_offsets = enemies[i].get_meta("story_patrol",PackedVector2Array([Vector2.ZERO]))
			enemies[i].set_physics_process(true)
	hero().pressure = state.ammo
	hero().scatter_unlocked = state.calibrated
	hero().set_protocol_active(false)
	var spawn := anchor("ScatterCheckpoint") if state.checkpoint == "return" else (anchor("DefenseSafePocket") if state.first_fall else anchor("PlayerSpawn"))
	hero().global_position = spawn
	authorized_gate.set_open(baseline_gate)
	exit_gate.set_open(baseline_exit)
	_door("p2_defense_isolation_gate").set_open(false)
	map.set_service_passage_state(map.ServicePassage.OPEN if state.hatch_open else (map.ServicePassage.REVEALED if state.first_fall else map.ServicePassage.CONCEALED))
	defense.reset_motion()
	$BackgroundMusic.stop()

func _snapshot_world() -> Dictionary:
	var units: Array = []
	for unit in enemies:
		units.append({"id":String(unit.entity_id),"health":unit.health,"position":[unit.global_position.x,unit.global_position.y]})
	return {"units":units,"gate":authorized_gate.is_open,"exit":exit_gate.is_open}

func _restore_baseline() -> void:
	for saved in state.baseline.get("units",[]):
		if not saved is Dictionary or not saved.get("position") is Array or saved.position.size()!=2: continue
		for i in range(enemies.size()):
			var unit = enemies[i]
			if String(unit.entity_id) != saved.get("id",""): continue
			var snapshot: Dictionary = unit.get_combat_state()
			snapshot.health = clampi(int(saved.get("health",unit.max_health)),0,unit.max_health)
			snapshot.alive = snapshot.health > 0
			snapshot.position = Vector2(float(saved.position[0]),float(saved.position[1]))
			unit.restore_combat_state(snapshot)
			baselines[i] = {"position":snapshot.position,"state":snapshot.duplicate(true)}
	authorized_gate.set_open(state.baseline.get("gate",false))
	exit_gate.set_open(state.baseline.get("exit",false))

func _begin_workshop_trip() -> void:
	busy = true
	hero().pulse_gun.cancel()
	var candidate := state.duplicate(true)
	candidate.baseline = _snapshot_world()
	candidate.room = "workshop"
	var loader = preload("res://scenes/gameplay/spine_flow_loading.gd").new()
	loader.name = "EntryLoading"
	loader.source = self
	loader.payload = {"state":candidate,"path":save_path,"data":save_data.duplicate(true),"health":hero().health,"isolated":isolate_progress or save_path.is_empty()}
	get_tree().root.add_child(loader)
	loader.begin("res://scenes/gameplay/spine_workshop_visit.tscn")

func finish_flow_transfer(payload: Dictionary) -> bool:
	if not map.is_walkable_point(hero().global_position): return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hero().get_node("CollisionShape2D").shape
	query.transform = Transform2D(0,hero().global_position)
	query.collision_mask = 1
	if not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	state.room = "spine"
	hero().health = clampi(int(payload.get("health",hero().max_health)),1,hero().max_health)
	return _save_progress()

func flow_transfer_cancelled() -> void: busy = false

func _save_progress(show_result: bool = true) -> bool:
	if not story_ready: return true
	state.ammo = hero().pressure
	var candidate := save_data.duplicate(true)
	candidate.snapshot = _capture_room_snapshot(hero())
	var result := FLOW.save(save_path,candidate,state)
	if result == OK:
		save_data = candidate
		if show_result and not save_path.is_empty(): notice.text = "旅程已保存。"
	else:
		notice.text = "存档失败，请检查磁盘空间或文件权限。"
	return result == OK

func _restore_room_snapshot(_player: Node2D, snapshot: Dictionary) -> void:
	# The base restores before the story's extra sentry, gates and defense exist.
	pending_live_snapshot = snapshot.duplicate(true)

func _capture_room_snapshot(player: Node2D) -> Dictionary:
	var snapshot := super._capture_room_snapshot(player)
	var gate_state := {}
	for gate in doors:
		gate_state[gate.get_meta("stable_id","")] = {"open":gate.is_open,"aperture":gate.aperture,"opening":gate.opening}
	snapshot.room["story_gates"] = gate_state
	snapshot.room["story_defense"] = defense.capture_journey_state()
	snapshot.room["story_runtime"] = {"protocol_armed":protocol_armed,"saved_receipt":saved_receipt,"scan_done":scan_done,"scan_time":scan_time,"record_cued":record_cued,"demo_viewed":demo_viewed}
	return snapshot

func _apply_live_snapshot(snapshot: Dictionary) -> void:
	super._restore_room_snapshot(hero(),snapshot)
	for gate in doors:
		var saved: Dictionary = snapshot.room.get("story_gates",{}).get(gate.get_meta("stable_id",""),{})
		if saved.is_empty(): continue
		gate.set_open(saved.get("open",false)==true)
		if JOURNEY.SNAPSHOT.number(saved.get("aperture")): gate.aperture = clampf(float(saved.aperture),0,1)
		gate.opening = saved.get("opening",false)==true and not gate.is_open
	if snapshot.room.get("story_defense") is Dictionary:
		defense.restore_journey_state(snapshot.room.story_defense)
	var runtime: Dictionary = snapshot.room.get("story_runtime",{})
	protocol_armed = runtime.get("protocol_armed",hero().has_protocol)==true
	saved_receipt = runtime.get("saved_receipt",false)==true
	scan_done = runtime.get("scan_done",false)==true
	if JOURNEY.SNAPSHOT.number(runtime.get("scan_time")): scan_time = maxf(0,float(runtime.scan_time))
	record_cued = runtime.get("record_cued",false)==true
	demo_viewed = runtime.get("demo_viewed",false)==true

func on_entry_revealed() -> void:
	if story_ready: super.on_entry_revealed()

func _finish_level() -> void:
	if busy: return
	state.completed = true
	_save_progress()
	busy = true
	var heading := "输能脊柱 · 试玩完成" if isolate_progress or save_path.is_empty() else "第二关 · 输能脊柱完成"
	_talk(heading,["系统|"+heading+"。", "小一|胸腔就在前面了。", "系统|胸腔地图尚未接入，返回标题保留旅程记录。"],func(): _return_title())

func _draw() -> void:
	if not story_ready: return
	if refill_time >= 0:
		var at := anchor("SpinalFluidTap")
		draw_rect(Rect2(at-Vector2(8,24),Vector2(16,48)),Color("263b3b"))
		draw_rect(Rect2(at+Vector2(-6,22-refill_time/1.6*44),Vector2(12,refill_time/1.6*44)),Color("bd6a50"))
