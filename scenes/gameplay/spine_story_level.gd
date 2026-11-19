extends "res://scenes/gameplay/spine_level.gd"
## Interactive v5 flow on A's source map and B's real player/weapons/enemies.
const FLOW := preload("res://scenes/gameplay/spine_flow_state.gd")
const INPUT := preload("res://scenes/gameplay/input_bindings.gd")
const CHECKPOINT_BEACON := preload("res://scenes/gameplay/checkpoint_beacon.gd")
const F := Vector2(0.9063078,-0.4226183)
const SHIFTED_CLEANER_LAYOUT := 2
const SHIFTED_CLEANERS := [&"p2_cleaner_03", &"p2_cleaner_04", &"p2_cleaner_05"]
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
var protocol_draft: Array[int] = []
var protocol_draft_stop := 0
var defense
var signals
var checkpoint_beacon: CHECKPOINT_BEACON
var protocol_rail
var demo_cleaner
var authorized_gate
var exit_gate
var baseline_gate := false
var baseline_exit := false
var record_cued := false
var refill_time := -1.0
var complete_panel: CanvasLayer
var prompt: Label
var pressure_label: Label
var nearest := ""
var death_pending := false
var protocol_suspended := false
var protocol_hint_left := 0.0
var tree_installed := false
var pending_live_snapshot: Dictionary = {}
@onready var protocol_zone: Node2D = map.get_node("Reservations/ProtocolZone")
@onready var observation_floor: Polygon2D = map.get_node("Floors/ProtocolObservationBay/Top")

func hero(): return $SpawnPoints/PlayerSpawn/Player
func anchor(key: String) -> Vector2:
	var aliases := {"MaintenanceRecord":"OptionalRecord", "ReturnDuct":"BlueprintDuct", "ScatterCheckpoint":"Checkpoint", "ThoraxEntry":"ToThorax"}
	return map.get_node("Markers/"+aliases.get(key,key)).global_position

func _enter_tree() -> void:
	if tree_installed: return # A cancelled transactional transfer reattaches this room.
	tree_installed = true
	super._enter_tree()
	$SpawnPoints/PlayerSpawn/Player.set_script(preload("res://scenes/gameplay/spine_flow_player.gd"))
	$SpawnPoints/CleanerSpawn/Cleaner.set_script(preload("res://scenes/gameplay/spine_patrol_demo.gd"))

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
	add_child(signals)
	protocol_rail = preload("res://scenes/gameplay/spine_protocol_rail.gd").new()
	protocol_rail.name = "MaintenanceRail"
	add_child(protocol_rail)
	protocol_rail.configure(self)
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
	_setup_service_checkpoint()
	if resume_at_checkpoint:
		var spawn := _retry_spawn()
		if pending_live_snapshot.is_empty():
			hero().global_position = spawn
		else:
			pending_live_snapshot = JOURNEY.SNAPSHOT.with_player_spawn(pending_live_snapshot, spawn)
	elif pending_live_snapshot.is_empty() and (not transfer_payload.is_empty() or state.checkpoint == "return"):
		hero().global_position = anchor("ScatterReturnEntry")
	elif pending_live_snapshot.is_empty() and checkpoint_beacon.activated:
		hero().global_position = checkpoint_beacon.global_position
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
	if baseline_gate:
		_clear_gate_lane()
	baseline_exit = exit_gate.is_open
	if not pending_live_snapshot.is_empty():
		_apply_live_snapshot(pending_live_snapshot)
		pending_live_snapshot = {}
	protocol_rail.set_powered(state.receipt_learned)
	hero().protocol_after_move = _sync_protocol
	story_ready = true
	_sync_protocol()
	entry_ready = true
	_update_camera()
	$Camera2D.reset_smoothing()
	# The base cannot capture story nodes before this asynchronous setup finishes.
	if not defer_entry_save and not save_path.is_empty() and transfer_payload.is_empty():
		_save_progress(false)
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
	if marker.object_id in ["p2_authorized_door", "p2_exit_door"]:
		map.get_node("SpineArt").make_door_skin(door, marker.object_id == "p2_authorized_door")
	if marker.object_id in ["p2_authorized_door", "p2_exit_door", "p2_shortcut_door"]:
		door.self_modulate.a = 0.0

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
	return (story_ready and state.receipt_learned and super._cleaner_on_screen(enemy)
		and _line_clear(hero().global_position,enemy.global_position))

func _line_clear(from: Vector2, to: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1)).is_empty()

func _process(delta: float) -> void:
	if not story_ready: return
	protocol_hint_left = maxf(0.0, protocol_hint_left - delta)
	_update_camera()
	health_display.set_health(hero().health,hero().max_health)
	hero().modulate = Color(0.62,0.83,0.92,0.82) if hero().has_protocol else Color.WHITE
	pressure_label.text = "右臂蓄压  %d / %d" % [hero().pressure,state.capacity] if state.calibrated else ""
	_update_prompt()
	var art := map.get_node("SpineArt")
	art.gate_reader.set_active(hero().has_protocol or authorized_gate.opening or authorized_gate.is_open)
	var pressure_fraction := float(hero().pressure) / maxf(1.0, state.capacity)
	art.fluid_station.set_fluid_state(pressure_fraction, refill_time / 1.6)

func _physics_process(delta: float) -> void:
	if not story_ready or hero().is_dead or busy: return
	if state.hatch_open and hero().controls_enabled:
		checkpoint_beacon.check_contact(hero().global_position)
	if not record_cued and hero().global_position.distance_to(map.get_node("RouteWaypoints/RecordRoute/Point00").global_position) < 110:
		record_cued = true
		signals.record_at = anchor("MaintenanceRecord")
		signals.record_clock = 0
	# Keep the old automatic fallback for journeys that have not lit the beacon.
	if state.checkpoint == "entry" and state.calibrated and hero().global_position.distance_to(anchor("ScatterCheckpoint")) < 48:
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

func _setup_service_checkpoint() -> void:
	checkpoint_beacon = CHECKPOINT_BEACON.new()
	checkpoint_beacon.name = "CheckpointBeacon"
	checkpoint_beacon.use_default_visual = false
	checkpoint_beacon.activation_changed.connect(map.get_node("SpineArt").checkpoint_skin.set_active)
	checkpoint_beacon.activated = state.checkpoint == FLOW.SERVICE_CHECKPOINT
	map.get_node("Checkpoints/ServiceExit").add_child(checkpoint_beacon)
	checkpoint_beacon.touched.connect(_activate_service_checkpoint)

func _activate_service_checkpoint() -> void:
	var previous: String = state.checkpoint
	state.checkpoint = FLOW.SERVICE_CHECKPOINT
	if not _save_progress(false):
		state.checkpoint = previous
		checkpoint_beacon.show_notice("存档失败，请稍后再试")
		return
	checkpoint_beacon.activated = true
	checkpoint_beacon.show_notice("存档点已保存")

func _test_protocol_active() -> bool:
	# Read the regional boundary at the player's current position, including the crossing frame.
	return story_ready and state.receipt_learned and not hero().is_dead \
		and not protocol_suspended and _in_protocol_area(hero().global_position)

func _sync_protocol() -> void:
	if not story_ready:
		return
	if protocol_suspended and not _in_protocol_area(hero().global_position):
		protocol_suspended = false
	var active := _test_protocol_active()
	if hero().has_protocol != active:
		hero().set_protocol_active(active)

func _in_protocol_area(position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, protocol_zone.size).has_point(protocol_zone.to_local(position)) \
		or Geometry2D.is_point_in_polygon(observation_floor.to_local(position), observation_floor.polygon)

func _update_scatter_prompt() -> void:
	if is_instance_valid(scatter_prompt): scatter_prompt.hide()
	if is_instance_valid(scatter_station): scatter_station.hide()

func try_unlock_scatter() -> bool:
	# Production acquisition is the abdomen manufacture/calibration transaction.
	return false

func _interaction_candidates() -> Dictionary:
	var candidates := {
		"MaintenanceHatch": "开启检修盖板" if state.first_fall else "检查装甲接缝",
		"MaintenanceRecord": "查看旧记录",
		"ProtocolTerminalUse": "操作导轨终端",
		"ScatterEvolution": "重看散射图纸" if state.scatter_blueprint else "读取散射图纸",
		"ReturnDuct": "进入返程井",
		"SpinalFluidTapUse": "接入脊液补能",
		"ExitTerminal": "接入胸腔终端",
	}
	if not state.receipt_learned:
		candidates["ProtocolObservation"] = "观察清扫路线"
	if not authorized_gate.is_open and not authorized_gate.opening:
		var reader_prompt := "检查门侧读头"
		if state.receipt_learned:
			reader_prompt = "发送维护回执" if _test_protocol_active() else "检查门侧读头"
		candidates["ProtocolGateReader"] = reader_prompt
	return candidates

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
	if refill_time >= 0:
		prompt.text = "脊液接入  %d%%" % int(refill_time/1.6*100)
	elif authorized_gate.opening:
		prompt.text = "授权门开启中"
	elif protocol_hint_left > 0.0 and not busy and not hero().is_dead:
		prompt.text = "隐身已接通 · 检修区内可自由移动"
	elif prompt.text.is_empty() and hero().has_protocol:
		prompt.text = "维护协议已启用"

func _interaction_clear(from: Vector2, to: Vector2, key: String) -> bool:
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1))
	if hit.is_empty(): return true
	# The authored hatch seal is the interaction target, not an intervening wall.
	return key == "MaintenanceHatch" and str(hit.collider.get_path()).contains("ServiceSeals") and Vector2(hit.position).distance_to(to) < 60

func _unhandled_key_input(event: InputEvent) -> void:
	if not story_ready or event.is_echo(): return
	if event.is_action_pressed("protocol_exit") and hero().has_protocol:
		hero().set_protocol_active(false)
		protocol_suspended = true
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
		"ProtocolObservation":
			_talk("检修窗", ["小一|它总从地面的起点出发。记下 %d 段方向，还有它中间停下的位置。" % demo_cleaner.waypoints.size()], func(): pass)
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
	if state.receipt_learned and protocol_suspended:
		protocol_suspended = false
		_sync_protocol()
		return
	busy = true
	hero().pulse_gun.cancel()
	get_tree().paused = true
	protocol_panel = preload("res://scenes/gameplay/spine_protocol_panel.gd").new()
	protocol_panel.calibrated = state.receipt_learned
	protocol_panel.expected = protocol_rail.observed_directions()
	protocol_panel.expected_stop = demo_cleaner.stop_after
	protocol_panel.directions.assign(protocol_draft)
	protocol_panel.initial_stop = protocol_draft_stop
	protocol_panel.board_angle = protocol_rail.board_angle
	protocol_panel.submitted.connect(func():
		if not state.receipt_learned:
			state.receipt_learned = true
			protocol_rail.set_powered(true)
			protocol_hint_left = 5.0
			_sync_protocol()
			_save_progress())
	protocol_panel.closed.connect(func():
		protocol_draft.assign(protocol_panel.directions)
		protocol_draft_stop = protocol_panel.stop_picker.get_selected_id()
		busy = false
		get_tree().paused = false)
	add_child(protocol_panel)

func _authorize_gate() -> void:
	if not state.receipt_learned:
		_talk("门侧读头", ["小一|维护协议还没接通。先到检修终端输入清扫者的路线。"], func(): pass)
		return
	if authorized_gate.is_open or authorized_gate.opening:
		return
	if not _test_protocol_active():
		_talk("门侧读头", ["小一|需要接入维护协议，才能发送回执。"], func(): pass)
		return
	_clear_gate_lane()
	authorized_gate.unlock()

func _clear_gate_lane() -> void:
	for pair in [["p2_cleaner_05", "ProtocolYieldRear"], ["p2_cleaner_06", "ProtocolYieldFront"]]:
		for unit in enemies:
			if unit.entity_id == pair[0] and unit.health > 0:
				unit.home = anchor(pair[1])
				unit.patrol_offsets = PackedVector2Array([Vector2.ZERO])
				unit.patrol_index = 0

func _on_player_died() -> void:
	if death_pending: return
	if not state.first_fall:
		death_pending = true
		_recover_first_fall.call_deferred()
	else:
		menus.show_death(state.checkpoint != "entry")

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
	busy = false
	refill_time = -1
	protocol_suspended = false
	protocol_hint_left = 0.0
	protocol_draft.clear()
	protocol_draft_stop = 0
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
	hero().global_position = _retry_spawn()
	_update_camera()
	$Camera2D.reset_smoothing()
	authorized_gate.set_open(baseline_gate)
	if baseline_gate:
		_clear_gate_lane()
	exit_gate.set_open(baseline_exit)
	_door("p2_defense_isolation_gate").set_open(false)
	map.set_service_passage_state(map.ServicePassage.OPEN if state.hatch_open else (map.ServicePassage.REVEALED if state.first_fall else map.ServicePassage.CONCEALED))
	defense.reset_motion()
	$BackgroundMusic.stop()

func _retry_spawn() -> Vector2:
	if checkpoint_beacon.activated:
		return checkpoint_beacon.global_position
	if state.checkpoint == "return":
		return anchor("ScatterCheckpoint")
	return anchor("DefenseSafePocket") if state.first_fall else anchor("PlayerSpawn")

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
	snapshot.room["story_runtime"] = {"protocol_suspended": protocol_suspended,
		"record_cued": record_cued, "demo_loop_time": demo_cleaner.loop_time}
	return snapshot

func _apply_live_snapshot(snapshot: Dictionary) -> void:
	var runtime: Dictionary = snapshot.room.get("story_runtime",{})
	# Restore the original deployment for unsolved saves made with the shifted markers.
	if not state.receipt_learned and runtime.get("observation_layout", 0) == SHIFTED_CLEANER_LAYOUT:
		snapshot = snapshot.duplicate(true)
		for unit in enemies:
			if unit.entity_id in SHIFTED_CLEANERS and snapshot.enemies.has(String(unit.entity_id)):
				snapshot.enemies[String(unit.entity_id)].global_position = JOURNEY.SNAPSHOT.pack_vector(unit.home)
	super._restore_room_snapshot(hero(),snapshot)
	for gate in doors:
		var saved: Dictionary = snapshot.room.get("story_gates",{}).get(gate.get_meta("stable_id",""),{})
		if saved.is_empty(): continue
		gate.set_open(saved.get("open",false)==true)
		if JOURNEY.SNAPSHOT.number(saved.get("aperture")): gate.aperture = clampf(float(saved.aperture),0,1)
		gate.opening = saved.get("opening",false)==true and not gate.is_open
	if snapshot.room.get("story_defense") is Dictionary:
		defense.restore_journey_state(snapshot.room.story_defense)
	protocol_suspended = runtime.get("protocol_suspended",
		runtime.get("rail_suspended", runtime.get("saved_receipt", false))) == true
	var loop_time = runtime.get("demo_loop_time", 0.0)
	demo_cleaner.restore_loop(float(loop_time) if JOURNEY.SNAPSHOT.number(loop_time) else 0.0)
	if not state.receipt_learned:
		for unit in enemies:
			if (unit is CharacterBody2D and unit.health > 0
					and (unit.web_phase != 0 or unit.state in [unit.State.CHASE, unit.State.WARNING, unit.State.ATTACK])):
				unit.web_phase = 0
				unit.begin_recovery()
				unit.update_visuals()
	for silk in get_tree().get_nodes_in_group("b_cleaner_webs"):
		if silk.source == demo_cleaner or (not state.receipt_learned and is_ancestor_of(silk)):
			silk.spent = true
			silk.queue_free()
	record_cued = runtime.get("record_cued", false) == true
	if authorized_gate.is_open or authorized_gate.opening:
		_clear_gate_lane()

func on_entry_revealed() -> void:
	if story_ready and hero().is_dead:
		menus.show_death(state.checkpoint != "entry")

func _finish_level() -> void:
	if busy: return
	state.completed = true
	_save_progress()
	busy = true
	var heading := "输能脊柱 · 试玩完成" if isolate_progress or save_path.is_empty() else "第二关 · 输能脊柱完成"
	_talk(heading,["系统|"+heading+"。", "小一|胸腔就在前面了。", "系统|胸腔地图尚未接入，返回标题保留旅程记录。"],func(): _return_title())
