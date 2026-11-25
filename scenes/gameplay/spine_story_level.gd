extends "res://scenes/gameplay/spine_level.gd"
## Interactive v5 flow on A's source map and B's real player/weapons/enemies.
const FLOW := preload("res://scenes/gameplay/spine_flow_state.gd")
const INPUT := preload("res://scenes/gameplay/input_bindings.gd")
const CHECKPOINT_BEACON := preload("res://scenes/gameplay/checkpoint_beacon.gd")
const CHECKPOINT_MARKERS := {
	FLOW.SERVICE_CHECKPOINT: &"ServiceExit",
	FLOW.PATROL_CHECKPOINT: &"PatrolApproach",
	FLOW.BLUEPRINT_CHECKPOINT: &"BlueprintApproach",
}
const INTERACTION_POINT := preload("res://scenes/gameplay/interaction_point.gd")
const INTERACTION_RANGE := 44.5
const REFILL_HINT := "请前往脊液补能处补能"
const INTERACTION_ANCHORS := ["MaintenanceHatch", "MaintenanceRecord", "ProtocolObservation",
	"ProtocolTerminalUse", "ProtocolGateReader", "ProtocolTransferReceiver", "ScatterEvolution", "ReturnDuct",
	"SpinalFluidTapUse", "ExitTerminal"]
const SOLID_INTERACTION_FIXTURES := {
	"MaintenanceRecord": "Fittings/OptionalRecord",
	"ProtocolGateReader": "ProtocolFittings/ProtocolGateReader",
	"ProtocolTransferReceiver": "ProtocolFittings/ProtocolTransferReceiver",
	"ProtocolTerminalUse": "ProtocolFittings/ProtocolTerminal",
	"ScatterEvolution": "Fittings/ScatterEvolution",
	"SpinalFluidTapUse": "SpinalFluidStation/SpinalFluidTap",
	"ExitTerminal": "Fittings/ExitTerminal",
}
const FIXTURE_INTERACTION_CLEARANCE := 14.0
const F := Vector2(0.9063078,-0.4226183)
const GUARD_PATROL_DISTANCE := 72.0
const GUARD_PATROL_TRAVEL := 1.5
const GUARD_PATROL_PAUSE := 0.25
const GUARD_PATROL_HALF_CYCLE := GUARD_PATROL_TRAVEL + GUARD_PATROL_PAUSE
const GUARD_PATROL_CYCLE := 2.0 * GUARD_PATROL_HALF_CYCLE
const GUARD_FORMATION_VERSION := 3
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
var checkpoint_beacons: Dictionary[String, CHECKPOINT_BEACON] = {}
var protocol_rail
var demo_cleaner
var guard_patrol_time := 0.0
var guard_alerted := false
var authorized_gate
var exit_gate
var baseline_exit := false
var record_cued := false
var patrol_intro_seen := false
var patrol_reminder_pending := false
var patrol_intro: Tween
var patrol_camera_weight := 0.0
var patrol_camera_bounds: Rect2
var patrol_notice: PanelContainer
var patrol_guide: PanelContainer
var patrol_guide_tween: Tween
var hatch_preview: Tween
var hatch_camera_weight := 0.0
var refill_time := -1.0
var complete_panel: CanvasLayer
var status_notice: PanelContainer
var status_label: Label
var status_message := ""
var status_message_left := 0.0
var pressure_panel: PanelContainer
var pressure_label: Label
var interaction_points: Dictionary[String, INTERACTION_POINT] = {}
var interaction_panel: PanelContainer
var interaction_label: Label
var death_pending := false
var protocol_suspended := false
var tree_installed := false
var pending_live_snapshot: Dictionary = {}
@onready var first_fall_spawn: Marker2D = map.get_node("FirstFallRespawn")
@onready var protocol_zone: Node2D = map.get_node("Reservations/ProtocolZone")
@onready var protocol_approach: Node2D = map.get_node("Reservations/ProtocolApproach")
@onready var guard_patrol_zone: Node2D = map.get_node("Reservations/CleanerPatrolZone")
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
	hero().scatter_empty.connect(_show_status_message.bind(REFILL_HINT))
	$SpawnPoints/SentrySpawn/Sentry.entity_id = "p2_sentry_01"
	demo_cleaner = $SpawnPoints/CleanerSpawn/Cleaner
	demo_cleaner.entity_id = "p2_cleaner_01"
	for i in range(2): baselines[i].state = enemies[i].get_combat_state().duplicate(true)
	for i in range(enemies.size()):
		var unit := enemies[i]
		if unit is CharacterBody2D:
			if unit != demo_cleaner:
				unit.patrol_offsets = PackedVector2Array([Vector2.ZERO, -F * GUARD_PATROL_DISTANCE])
				unit.patrol_cycle_query = _guard_patrol_cycle
				unit.target_defeated.connect(_queue_patrol_reminder)
				baselines[i].position = unit.home
				baselines[i].state.position = unit.home
				baselines[i].state.patrol_index = 0
				unit.restore_combat_state(baselines[i].state)
				unit.get_node("Facing").global_rotation = (-F).angle()
			unit.set_meta("story_patrol_home", unit.home)
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
	notice.hide()
	health_display.theme = preload("res://scenes/gameplay/spine_flow_theme.tres")
	sheet.presentation_theme = health_display.theme
	_setup_interaction_points(hud)
	_setup_top_notices(hud)
	_setup_pressure_panel()
	_setup_checkpoints()
	if resume_at_checkpoint:
		var spawn := _retry_spawn()
		if pending_live_snapshot.is_empty():
			hero().global_position = spawn
		else:
			pending_live_snapshot = JOURNEY.SNAPSHOT.with_player_spawn(pending_live_snapshot, spawn)
	elif pending_live_snapshot.is_empty() and (not transfer_payload.is_empty() or state.checkpoint == "return"):
		hero().global_position = anchor("ScatterReturnEntry")
	elif pending_live_snapshot.is_empty() and checkpoint_beacons.has(state.checkpoint):
		hero().global_position = _retry_spawn()
	elif pending_live_snapshot.is_empty() and state.first_fall:
		hero().global_position = first_fall_spawn.global_position
	if playtest_start > 0 and isolate_progress:
		state.first_fall = true
		state.hatch_open = true
		map.set_service_passage_state(map.ServicePassage.OPEN)
		hero().global_position = anchor("ProtocolObservation")
		if playtest_start == 2:
			state.receipt_learned = true
			hero().global_position = anchor("ScatterReturnEntry")
	baseline_exit = exit_gate.is_open
	if not pending_live_snapshot.is_empty():
		_apply_live_snapshot(pending_live_snapshot)
		pending_live_snapshot = {}
	protocol_rail.set_powered(state.receipt_learned)
	hero().protocol_after_move = _after_player_move
	story_ready = true
	_after_player_move()
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
	door.fixed_closed = marker.object_id == "p2_authorized_door"
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
	return (story_ready and guard_alerted and patrol_intro == null and super._cleaner_on_screen(enemy)
		and _line_clear(hero().global_position,enemy.global_position))

func _in_guard_patrol_area(position: Vector2) -> bool:
	# The reservation follows the inner edges of the two deck bands.
	return Rect2(Vector2.ZERO, guard_patrol_zone.size).has_point(guard_patrol_zone.to_local(position))

func _line_clear(from: Vector2, to: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1)).is_empty()

func _update_camera() -> void:
	super._update_camera()
	if hatch_camera_weight > 0.0:
		var target := interaction_points["MaintenanceHatch"].global_position
		_frame_camera(Rect2(target, Vector2.ZERO).grow(80.0), hatch_camera_weight, 1.1)
		return
	if patrol_camera_weight > 0.0:
		_frame_camera(patrol_camera_bounds, patrol_camera_weight, 1.35)
		return
	var weight: float = map.service_camera_weight()
	if weight <= 0.0:
		return
	var deck: Polygon2D = map.get_node("Floors/ServiceCatwalk/Top")
	var bounds := Rect2(hero().global_position, Vector2.ZERO)
	for vertex in deck.polygon:
		bounds = bounds.expand(deck.to_global(vertex))
	_frame_camera(bounds.grow(85.0), weight, $Camera2D.zoom.x * 0.86)

func _frame_camera(bounds: Rect2, weight: float, zoom_limit: float) -> void:
	var view := get_viewport_rect().size / bounds.size
	var camera := $Camera2D as Camera2D
	var zoom := minf(minf(view.x, view.y), zoom_limit)
	camera.global_position = camera.global_position.lerp(bounds.get_center(), weight)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * zoom, weight)

func _process(delta: float) -> void:
	if not story_ready: return
	_update_camera()
	health_display.set_health(hero().health,hero().max_health)
	pressure_panel.visible = state.calibrated and not hero().is_dead
	if pressure_panel.visible:
		pressure_label.text = "右臂蓄压  %d / %d" % [hero().pressure, state.capacity]
	hero().modulate = Color(0.62,0.83,0.92,0.82) if hero().has_protocol else Color.WHITE
	_update_interaction_prompts()
	_update_status(delta)
	var art := map.get_node("SpineArt")
	art.gate_reader.set_active(state.receipt_learned)
	art.transfer_receiver.set_active(state.receipt_learned)
	var pressure_fraction := float(hero().pressure) / maxf(1.0, state.capacity)
	art.fluid_station.set_fluid_state(pressure_fraction, refill_time / 1.6)

func _physics_process(delta: float) -> void:
	if not story_ready: return
	guard_patrol_time = fposmod(guard_patrol_time + delta, GUARD_PATROL_CYCLE)
	if hero().is_dead or busy: return
	if hero().controls_enabled:
		for id in checkpoint_beacons:
			if id == FLOW.SERVICE_CHECKPOINT and not state.hatch_open: continue
			checkpoint_beacons[id].check_contact(hero().global_position, id != state.checkpoint)
		if patrol_reminder_pending or (not patrol_intro_seen and not state.receipt_learned):
			_update_patrol_notice()
	if not record_cued and hero().global_position.distance_to(map.get_node("RouteWaypoints/RecordRoute/Point00").global_position) < 110:
		record_cued = true
		signals.record_at = anchor("MaintenanceRecord")
		signals.record_clock = 0
	# Keep the old automatic fallback for journeys that have not lit the beacon.
	if state.checkpoint == "entry" and state.calibrated and hero().global_position.distance_to(anchor("ScatterCheckpoint")) < 48:
		state.checkpoint = "return"
	if refill_time >= 0:
		if hero().global_position.distance_to(interaction_points["SpinalFluidTapUse"].global_position) > 50.0:
			refill_time = -1
		else:
			refill_time += delta
			if refill_time >= 1.6:
				hero().pressure = state.capacity
				state.ammo = hero().pressure
				state.fluid_tutorial = true
				refill_time = -1
				if _save_progress(false):
					_show_status_message("脊液补能完成")
	if exit_gate.is_open and hero().global_position.distance_to(anchor("ThoraxEntry")) < 76:
		_finish_level()

func _setup_top_notices(hud: CanvasLayer) -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_left = 24.0
	center.offset_right = -24.0
	center.offset_top = 24.0
	center.offset_bottom = 112.0
	var notices := VBoxContainer.new()
	notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices.add_theme_constant_override("separation", 8)
	center.add_child(notices)
	patrol_notice = _build_hud_notice(notices, "前方清扫者集结，正面交战危险！")
	patrol_guide = _build_hud_notice(notices,
		"观察示范清扫者的路线和停靠点，破解检修终端，开启维护协议。\n保持隐身即可无伤通过这段走道。")
	status_notice = _build_hud_notice(notices, "")
	status_label = status_notice.get_child(0) as Label
	get_viewport().size_changed.connect(_resize_top_notices)
	_resize_top_notices()

func _setup_pressure_panel() -> void:
	pressure_panel = _build_hud_notice(health_display, "")
	pressure_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pressure_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pressure_panel.offset_left = 0.0
	pressure_panel.offset_right = 0.0
	pressure_panel.offset_top = -58.0
	pressure_panel.offset_bottom = -8.0
	pressure_label = pressure_panel.get_child(0) as Label

func _build_hud_notice(parent: Control, text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.theme = health_display.theme
	var style: StyleBoxFlat = interaction_panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color("101d25f2")
	style.border_color = Color("ac8c60")
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.hide()
	parent.add_child(panel)
	var message := Label.new()
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.text = text
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color("f3e6ca"))
	panel.add_child(message)
	return panel

func _resize_top_notices() -> void:
	var available := maxf(0.0, get_viewport_rect().size.x - 48.0)
	patrol_notice.custom_minimum_size.x = minf(380.0, available)
	patrol_guide.custom_minimum_size.x = minf(590.0, available)
	status_notice.custom_minimum_size.x = minf(440.0, available)

func _queue_patrol_reminder() -> void:
	patrol_reminder_pending = true

func _update_patrol_notice() -> void:
	var position: Vector2 = hero().global_position
	var at_approach := Rect2(Vector2.ZERO, protocol_approach.size).has_point(protocol_approach.to_local(position))
	if at_approach or (patrol_reminder_pending and _in_guard_patrol_area(position)):
		_start_patrol_intro()

func _start_patrol_intro() -> void:
	patrol_intro_seen = true
	patrol_reminder_pending = false
	var bounds := Rect2(anchor("ExitCleaner"), Vector2.ZERO)
	for unit in enemies:
		if unit is CharacterBody2D and unit != demo_cleaner:
			bounds = bounds.expand(unit.home).expand(unit.home - F * GUARD_PATROL_DISTANCE)
	patrol_camera_bounds = bounds.grow(72.0)
	hero().controls_enabled = false
	hero().velocity = Vector2.ZERO
	hero().pulse_gun.cancel()
	patrol_notice.modulate.a = 0.0
	patrol_notice.show()
	patrol_intro = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	patrol_intro.tween_property(self, "patrol_camera_weight", 1.0, 0.75)
	patrol_intro.tween_property(patrol_notice, "modulate:a", 1.0, 0.3)
	patrol_intro.tween_interval(3.5)
	patrol_intro.tween_property(self, "patrol_camera_weight", 0.0, 0.65)
	patrol_intro.parallel().tween_property(patrol_notice, "modulate:a", 0.0, 0.45)
	patrol_intro.finished.connect(_finish_patrol_intro)

func _finish_patrol_intro() -> void:
	_stop_patrol_intro()
	_update_camera()
	$Camera2D.force_update_scroll()
	if state.receipt_learned: return
	patrol_guide.modulate.a = 1.0
	patrol_guide.show()
	patrol_guide_tween = create_tween()
	patrol_guide_tween.tween_interval(6.0)
	patrol_guide_tween.tween_property(patrol_guide, "modulate:a", 0.0, 0.35)
	patrol_guide_tween.finished.connect(func():
		patrol_guide.hide()
		patrol_guide_tween = null)

func _stop_patrol_intro() -> void:
	if patrol_guide_tween != null:
		patrol_guide_tween.kill()
		patrol_guide_tween = null
		patrol_guide.hide()
	if patrol_intro == null: return
	patrol_intro.kill()
	patrol_intro = null
	patrol_camera_weight = 0.0
	patrol_notice.hide()
	if not hero().is_dead:
		hero().controls_enabled = true

func _guard_patrol_cycle() -> float:
	var leg := floorf(guard_patrol_time / GUARD_PATROL_HALF_CYCLE)
	var elapsed := fposmod(guard_patrol_time, GUARD_PATROL_HALF_CYCLE)
	return leg + clampf((elapsed - GUARD_PATROL_PAUSE) / GUARD_PATROL_TRAVEL, 0.0, 1.0)

func _setup_checkpoints() -> void:
	var art := map.get_node("SpineArt")
	var feet: CircleShape2D = hero().get_node("CollisionShape2D").shape
	for id in CHECKPOINT_MARKERS:
		var marker_name: StringName = CHECKPOINT_MARKERS[id]
		var marker := map.get_node("Checkpoints/" + String(marker_name))
		var skin = art.checkpoint_skins[marker_name]
		var beacon := CHECKPOINT_BEACON.new()
		beacon.name = "CheckpointBeacon"
		beacon.use_default_visual = false
		beacon.contact_outlines = skin.checkpoint_contact_outlines()
		beacon.contact_radius = feet.radius
		marker.add_child(beacon)
		beacon.activation_changed.connect(skin.set_active)
		beacon.activated = id in state.saved_beacons
		beacon.touched.connect(_activate_checkpoint.bind(id))
		checkpoint_beacons[id] = beacon

func _activate_checkpoint(id: String) -> void:
	var beacon := checkpoint_beacons[id]
	var previous_checkpoint: String = state.checkpoint
	var previous_beacons: Array = state.saved_beacons.duplicate()
	state.checkpoint = id
	if id not in state.saved_beacons:
		state.saved_beacons.append(id)
	if not _save_progress(false):
		state.checkpoint = previous_checkpoint
		state.saved_beacons = previous_beacons
		_show_status_message("存档失败，请稍后再试")
		return
	beacon.activated = true
	_show_status_message("存档点已保存")

func _test_protocol_active() -> bool:
	# Read the regional boundary at the player's current position, including the crossing frame.
	return story_ready and state.receipt_learned and not hero().is_dead \
		and not protocol_suspended and _in_protocol_area(hero().global_position)

func _after_player_move() -> void:
	_sync_protocol()
	if not guard_alerted and not hero().is_dead and not hero().has_protocol:
		guard_alerted = _in_guard_patrol_area(hero().global_position)

func _sync_protocol() -> void:
	if not story_ready:
		return
	if protocol_suspended and not _in_protocol_area(hero().global_position):
		protocol_suspended = false
	var active := _test_protocol_active()
	if hero().has_protocol != active:
		hero().set_protocol_active(active)

func _in_protocol_area(position: Vector2) -> bool:
	var local := protocol_zone.to_local(position)
	if local.x < 0.0 or local.x >= protocol_zone.size.x:
		return false
	return (local.y >= 0.0 and local.y < protocol_zone.size.y) \
		or Geometry2D.is_point_in_polygon(observation_floor.to_local(position), observation_floor.polygon)

func _update_scatter_prompt() -> void:
	if is_instance_valid(scatter_prompt): scatter_prompt.hide()
	if is_instance_valid(scatter_station): scatter_station.hide()

func try_unlock_scatter() -> bool:
	# Production acquisition is the abdomen manufacture/calibration transaction.
	return false

func _setup_interaction_points(hud: CanvasLayer) -> void:
	var markers := Node2D.new()
	markers.name = "InteractionPoints"
	add_child(markers)
	for key in INTERACTION_ANCHORS:
		var point := INTERACTION_POINT.new()
		point.name = key
		point.interaction_id = StringName(key)
		point.hide()
		markers.add_child(point)
		point.global_position = anchor(key)
		if SOLID_INTERACTION_FIXTURES.has(key):
			_place_solid_interaction(key, point)
		point.z_index = 8
		interaction_points[key] = point
	interaction_points["ProtocolObservation"].global_rotation = interaction_points["ProtocolTerminalUse"].global_rotation
	# The closed seal is the hatch itself. Intervening walls still block the ray.
	var hatch := map.get_node("EntranceDefense/ServiceSeals/MaintenanceHatch") as StaticBody2D
	interaction_points["MaintenanceHatch"].target_body = hatch.get_rid()

	interaction_panel = PanelContainer.new()
	interaction_panel.name = "InteractionHint"
	interaction_panel.theme = health_display.theme
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(interaction_panel)
	interaction_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_panel.offset_left = -196
	interaction_panel.offset_right = 196
	interaction_panel.offset_top = -68
	interaction_panel.offset_bottom = -34
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d25", 0.87)
	style.border_color = Color("48615d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	interaction_panel.add_theme_stylebox_override("panel", style)
	interaction_label = Label.new()
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_color_override("font_color", Color("d8e7e2"))
	interaction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_panel.add_child(interaction_label)
	interaction_panel.hide()

func _place_solid_interaction(key: String, point: Node2D) -> void:
	var fixture = map.get_node("SpineArt/" + SOLID_INTERACTION_FIXTURES[key])
	var collision: CollisionPolygon2D
	if key == "SpinalFluidTapUse":
		# Refit the existing plinth hitbox so the tap has just one solid body.
		collision = map.get_node("Covers/SpinalFluidPlinth/Body/Collision")
	else:
		var body := StaticBody2D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		fixture.add_child(body)
		collision = CollisionPolygon2D.new()
		collision.name = "Collision"
		body.add_child(collision)
	collision.polygon = collision.global_transform.affine_inverse() * fixture.global_transform * fixture.solid_outline()
	point.global_position = fixture.interaction_position(FIXTURE_INTERACTION_CLEARANCE)
	point.global_rotation = fixture.global_rotation

func _interaction_candidates() -> Dictionary:
	var candidates := {
		"MaintenanceRecord": "查看旧记录",
		"ProtocolTerminalUse": "操作导轨终端",
		"ScatterEvolution": "重看散射图纸" if state.scatter_blueprint else "读取散射图纸",
		"ReturnDuct": "进入返程井",
		"SpinalFluidTapUse": "接入脊液补能",
	}
	if not state.hatch_open:
		candidates["MaintenanceHatch"] = "开启检修盖板" if state.first_fall else "检查装甲接缝"
	if not state.receipt_learned:
		candidates["ProtocolObservation"] = "观察清扫路线"
	var reader_prompt := "检查检修传送装置"
	if state.receipt_learned:
		reader_prompt = "传送至门后掩体" if _test_protocol_active() else "接入维护协议后传送"
	candidates["ProtocolGateReader"] = reader_prompt
	candidates["ProtocolTransferReceiver"] = "传送回门前" if state.receipt_learned else "检查检修传送装置"
	if not exit_gate.is_open and not exit_gate.opening:
		candidates["ExitTerminal"] = "接入胸腔终端"
	return candidates

func _can_interact() -> bool:
	return story_ready and not get_tree().paused and not busy and not hero().is_dead and hero().controls_enabled

func _nearest_interaction(origin: Vector2, candidates: Dictionary) -> String:
	var nearest := ""
	var distance := INTERACTION_RANGE
	for key in candidates:
		var point := interaction_points[key]
		if point.can_interact_from(origin, distance):
			nearest = key
			distance = origin.distance_to(point.global_position)
	return nearest

func _update_interaction_prompts() -> void:
	var origin: Vector2 = hero().global_position
	var candidates := _interaction_candidates()
	var nearest := _nearest_interaction(origin, candidates) if _can_interact() else ""
	for key in interaction_points:
		var point := interaction_points[key]
		var selected := key == nearest
		# Before the recovery dialogue, the sealed passage only reacts up close.
		point.visible = candidates.has(key) and (key != "MaintenanceHatch" or state.first_fall or selected)
		point.set_focused(selected)
	interaction_panel.visible = not nearest.is_empty()
	if interaction_panel.visible:
		interaction_label.text = "[%s] %s" % [INPUT.action_label(&"interact"), candidates[nearest]]

func _show_status_message(message: String, seconds := 2.5) -> void:
	status_message = message
	status_message_left = seconds
	_update_status(0.0)

func _update_status(delta: float) -> void:
	status_message_left = maxf(0.0, status_message_left - delta)
	var showing_patrol := patrol_intro != null or patrol_guide.visible
	var lines: Array[String] = []
	if not showing_patrol and hero().has_protocol and refill_time < 0.0:
		lines.append("维护协议已启用")
	if status_message_left > 0.0:
		lines.append(status_message)
	if not showing_patrol and refill_time >= 0:
		lines.append("脊液接入  %d%%" % int(refill_time / 1.6 * 100))
	status_label.text = "\n".join(lines)
	status_notice.visible = not lines.is_empty() and not hero().is_dead

func _unhandled_key_input(event: InputEvent) -> void:
	if not story_ready or event.is_echo(): return
	if event.is_action_pressed("protocol_exit") and hero().has_protocol:
		hero().set_protocol_active(false)
		protocol_suspended = true
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and _can_interact():
		var nearest := _nearest_interaction(hero().global_position, _interaction_candidates())
		if not nearest.is_empty():
			_interact(nearest)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Remapped mouse buttons and scripted actions share the same interaction gate.
	if not event is InputEventKey: _unhandled_key_input(event)

func _interact(key: String) -> void:
	match key:
		"MaintenanceHatch":
			if not state.first_fall:
				_talk("装甲接缝",["小一|装甲下面，好像有气流。"],func(): pass)
			else:
				state.hatch_open = true
				map.set_service_passage_state(map.ServicePassage.OPEN, true)
				_save_progress(false)
		"MaintenanceRecord":
			_talk("旧记录 · 按事件先后排列",["记录|较早：返程路线已预约。", "记录|较晚：收到求救通讯。", "小一|这条返程记录……比那次通话还早。"],func(): state.record_read = true; _save_progress())
		"ProtocolObservation":
			_talk("检修窗", ["小一|它总从地面的起点出发。记下 %d 段方向，还有它中间停下的位置。" % demo_cleaner.waypoints.size()], func(): pass)
		"ProtocolTerminalUse": _open_protocol()
		"ProtocolGateReader": _transfer_at_reader("ProtocolTransferReceiver")
		"ProtocolTransferReceiver": _transfer_at_reader("ProtocolGateReader")
		"ScatterEvolution":
			_talk("散射机械臂图纸", ["小一|右臂的接口……原来还空着。",
				"神明|把图纸带回腹腔的制造台。旁边的返程井还接着你醒来的地方。"], func():
				state.scatter_blueprint = true
				if _save_progress(false) and not (state.assembled or state.calibrated):
					_show_status_message("请通过返程井前往制造台"))
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
	_update_interaction_prompts()

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
			_sync_protocol()
			if _save_progress(false):
				_show_status_message("隐身已接通 · 检修区内可自由移动", 5.0))
	protocol_panel.closed.connect(func():
		protocol_draft.assign(protocol_panel.directions)
		protocol_draft_stop = protocol_panel.stop_picker.get_selected_id()
		busy = false
		get_tree().paused = false)
	add_child(protocol_panel)

func _transfer_at_reader(destination_key: String) -> void:
	if not state.receipt_learned:
		_talk("检修传送", ["小一|传送需要维护回执。先去检修终端输入清扫者的路线。"], func(): pass)
		return
	if destination_key == "ProtocolTransferReceiver" and not _test_protocol_active():
		_talk("检修传送", ["小一|需要重新接入维护协议，才能传送到门后掩体。"], func(): pass)
		return
	var player: CharacterBody2D = hero()
	var destination := interaction_points[destination_key].global_position
	if not _can_stand_at(destination, player.collision_mask | 4):
		_talk("检修传送", ["小一|传送落点被挡住了，等它空出来再试。"], func(): pass)
		return
	player.pulse_gun.cancel()
	player.velocity = Vector2.ZERO
	player.global_position = destination
	player.reset_physics_interpolation()
	_sync_protocol()
	_update_camera()
	$Camera2D.reset_smoothing()
	$Camera2D.force_update_scroll()
	_update_interaction_prompts()

func _on_player_died() -> void:
	if death_pending: return
	_stop_hatch_preview()
	_stop_patrol_intro()
	if story_ready:
		status_notice.hide()
		pressure_panel.hide()
		_update_interaction_prompts()
	if not state.first_fall:
		death_pending = true
		_recover_first_fall.call_deferred()
	else:
		menus.show_death(state.checkpoint != "entry")

func _toggle_pause() -> void:
	super._toggle_pause()
	if story_ready:
		_update_interaction_prompts()

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
	hero().restore_player(first_fall_spawn.global_position,hero().max_health,[&"pulse_gun"])
	hero().scatter_unlocked = state.calibrated
	hero().pressure = state.ammo
	defense.orbs.clear()
	_update_camera()
	$Camera2D.reset_smoothing()
	$Camera2D.force_update_scroll()
	map.set_service_passage_state(map.ServicePassage.REVEALED)
	death_pending = false
	fade.queue_free()
	_talk("通讯重新接通",["神明|等一下……我记得装甲下面有一道检修缝。你顺着那根回流管找找。", "小一|我看见接缝里的灯了。我会从下面过去。"],_preview_maintenance_hatch,true)

func _preview_maintenance_hatch() -> void:
	_save_progress(false)
	hero().controls_enabled = false
	hero().velocity = Vector2.ZERO
	hatch_preview = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hatch_preview.tween_property(self, "hatch_camera_weight", 1.0, 0.7)
	hatch_preview.tween_interval(1.2)
	hatch_preview.tween_property(self, "hatch_camera_weight", 0.0, 0.65)
	hatch_preview.finished.connect(_stop_hatch_preview)

func _stop_hatch_preview() -> void:
	if hatch_preview == null: return
	hatch_preview.kill()
	hatch_preview = null
	hatch_camera_weight = 0.0
	if not hero().is_dead:
		hero().controls_enabled = true
	_update_camera()
	$Camera2D.force_update_scroll()

func _retry() -> void:
	_stop_hatch_preview()
	_stop_patrol_intro()
	busy = false
	refill_time = -1
	protocol_suspended = false
	status_message_left = 0.0
	protocol_draft.clear()
	protocol_draft_stop = 0
	if is_instance_valid(protocol_panel): protocol_panel.queue_free()
	sheet.dismiss()
	guard_alerted = false
	guard_patrol_time = 0.0
	menus.close_and_resume()
	for unit in enemies:
		if unit is CharacterBody2D:
			unit.home = unit.get_meta("story_patrol_home", unit.home)
			unit.patrol_offsets = unit.get_meta("story_patrol", PackedVector2Array([Vector2.ZERO]))
			unit.set_physics_process(true)
			if unit.patrol_cycle_query.is_valid():
				unit.get_node("Facing").global_rotation = (-F).angle()
	reset_test_combat()
	hero().pressure = state.ammo
	hero().scatter_unlocked = state.calibrated
	hero().set_protocol_active(false)
	hero().global_position = _retry_spawn()
	exit_gate.set_open(baseline_exit)
	_door("p2_defense_isolation_gate").set_open(false)
	map.set_service_passage_state(map.ServicePassage.OPEN if state.hatch_open else (map.ServicePassage.REVEALED if state.first_fall else map.ServicePassage.CONCEALED))
	_update_camera()
	$Camera2D.reset_smoothing()
	defense.reset_motion()
	$BackgroundMusic.stop()

func _retry_spawn() -> Vector2:
	if checkpoint_beacons.has(state.checkpoint):
		return checkpoint_beacons[state.checkpoint].global_position
	if state.checkpoint == "return":
		return anchor("ScatterCheckpoint")
	return first_fall_spawn.global_position if state.first_fall else anchor("PlayerSpawn")

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
			if snapshot.alive and unit is CharacterBody2D and unit != demo_cleaner \
					and _partition_overlaps(unit, snapshot.position, true):
				snapshot.position = unit.home
			unit.restore_combat_state(snapshot)
			baselines[i] = {"position":snapshot.position,"state":snapshot.duplicate(true)}
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

func _can_stand_at(destination: Vector2, collision_mask: int) -> bool:
	if not map.is_walkable_point(destination): return false
	var feet := hero().get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = feet.global_transform.translated(destination - hero().global_position)
	query.collision_mask = collision_mask
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func finish_flow_transfer(payload: Dictionary) -> bool:
	if not _can_stand_at(hero().global_position, 1): return false
	state.room = "spine"
	hero().health = clampi(int(payload.get("health",hero().max_health)),1,hero().max_health)
	if not _save_progress(false): return false
	if state.calibrated:
		_show_status_message(REFILL_HINT)
	return true

func flow_transfer_cancelled() -> void: busy = false

func _save_progress(show_result: bool = true) -> bool:
	if not story_ready: return true
	state.ammo = hero().pressure
	var candidate := save_data.duplicate(true)
	candidate.snapshot = _capture_room_snapshot(hero())
	var result := FLOW.save(save_path,candidate,state)
	if result == OK:
		save_data = candidate
		if show_result and not save_path.is_empty():
			_show_status_message("旅程已保存。")
	else:
		_show_status_message("存档失败，请检查磁盘空间或文件权限。")
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
		"record_cued": record_cued, "patrol_intro_seen": patrol_intro_seen, "patrol_reminder_pending": patrol_reminder_pending,
		"demo_loop_time": demo_cleaner.loop_time,
		"guard_patrol_time": guard_patrol_time, "guard_formation": GUARD_FORMATION_VERSION, "guard_alerted": guard_alerted}
	return snapshot

func _partition_overlaps(actor: Node2D, position: Vector2, include_far_side := false) -> bool:
	var feet: CircleShape2D = actor.get_node("CollisionShape2D").shape
	var clearance: float = authorized_gate.size.x * 0.5 + feet.radius
	var along: float = authorized_gate.to_local(position).x
	return along >= -clearance and (include_far_side or along <= clearance)

func _update_saved_guard_positions(snapshot: Dictionary, runtime: Dictionary, old_passage: bool) -> Dictionary:
	var old_formation: bool = runtime.get("guard_formation", 0) != GUARD_FORMATION_VERSION
	var shifted: bool = not state.receipt_learned and runtime.get("observation_layout", 0) == SHIFTED_CLEANER_LAYOUT
	if not old_formation and not shifted and not old_passage:
		return snapshot
	var updated := snapshot.duplicate(true)
	var progress := 1.0 - absf(1.0 - _guard_patrol_cycle())
	for unit in enemies:
		if not unit is CharacterBody2D or unit == demo_cleaner:
			continue
		var origin: Vector2 = unit.get_meta("story_patrol_home", unit.home)
		var patrol_position := origin - F * GUARD_PATROL_DISTANCE * progress
		var saved: Dictionary = updated.enemies.get(String(unit.entity_id), {})
		if saved.is_empty():
			if old_formation and unit.state == unit.State.PATROL:
				unit.global_position = patrol_position
			continue
		var crossed: bool = old_passage and saved.health > 0 \
			and _partition_overlaps(unit, JOURNEY.SNAPSHOT.vector(saved.global_position), true)
		if crossed or (shifted and unit.entity_id in SHIFTED_CLEANERS):
			saved.global_position = JOURNEY.SNAPSHOT.pack_vector(origin)
		elif old_formation and saved.health > 0 and saved.state == unit.State.PATROL:
			saved.global_position = JOURNEY.SNAPSHOT.pack_vector(patrol_position)
	return updated

func _apply_live_snapshot(snapshot: Dictionary) -> void:
	var runtime: Dictionary = snapshot.room.get("story_runtime",{})
	var patrol_time: Variant = runtime.get("guard_patrol_time", 0.0)
	guard_patrol_time = fposmod(float(patrol_time), GUARD_PATROL_CYCLE) if JOURNEY.SNAPSHOT.number(patrol_time) else 0.0
	var partition: Dictionary = snapshot.room.get("story_gates", {}).get("p2_authorized_door", {})
	var old_passage: bool = partition.get("open", false) == true or partition.get("opening", false) == true
	if old_passage:
		var position := JOURNEY.SNAPSHOT.vector(snapshot.player.global_position)
		if _partition_overlaps(hero(), position):
			var safe_reader := "ProtocolTransferReceiver" if authorized_gate.to_local(position).x >= 0.0 else "ProtocolGateReader"
			snapshot = JOURNEY.SNAPSHOT.with_player_spawn(snapshot, interaction_points[safe_reader].global_position)
			snapshot.player.gun = snapshot.player.get("gun", {}).duplicate()
			snapshot.player.gun["state"] = hero().pulse_gun.State.IDLE
	snapshot = _update_saved_guard_positions(snapshot, runtime, old_passage)
	super._restore_room_snapshot(hero(),snapshot)
	for gate in doors:
		if gate == authorized_gate: continue
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
	var legacy_alert: bool = not hero().has_protocol and _in_guard_patrol_area(hero().global_position)
	guard_alerted = runtime.get("guard_alerted", legacy_alert) == true
	if not guard_alerted:
		for unit in enemies:
			if (unit is CharacterBody2D and unit.health > 0
					and (unit.web_phase != 0 or unit.state in [unit.State.CHASE, unit.State.WARNING, unit.State.ATTACK])):
				unit.web_phase = 0
				unit.begin_recovery()
				unit.update_visuals()
	for silk in get_tree().get_nodes_in_group("b_cleaner_webs"):
		if silk.source == demo_cleaner or (not guard_alerted and is_ancestor_of(silk)):
			silk.spent = true
			silk.queue_free()
	record_cued = runtime.get("record_cued", false) == true
	patrol_intro_seen = runtime.get("patrol_intro_seen", false) == true
	patrol_reminder_pending = runtime.get("patrol_reminder_pending", false) == true

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
