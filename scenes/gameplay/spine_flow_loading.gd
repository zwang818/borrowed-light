extends "res://scenes/ui/intro_cutscene/entry_loading.gd"
## Keep the source alive until a real destination and safe landing are ready.
var source: Node
var destination: Node
var payload: Dictionary
var restart_session: Dictionary
var restart_session_installed := false
var source_mode := Node.PROCESS_MODE_INHERIT
var source_removed := false
var committed := false

static func restart_level(room: Node, path: String, save_path: String,
		previous_level_data: Dictionary = {}) -> void:
	var window := room.get_tree().root
	if window.has_node("EntryLoading"):
		return
	var loader = load("res://scenes/gameplay/spine_flow_loading.gd").new()
	loader.name = "EntryLoading"
	loader.source = room
	loader.restart_session = {"path": save_path, "data": previous_level_data, "defer_save": true}
	window.add_child(loader)
	loader.begin(path)

func _switch_scene() -> void:
	switching = true
	_report_progress(0.85)
	destination = packed.instantiate()
	if destination == null:
		_fail()
		return
	var restarting := not restart_session.is_empty()
	var required_method := "commit_level_restart" if restarting else "finish_flow_transfer"
	if not destination.has_method(required_method):
		destination.free()
		_fail()
		return
	if restarting:
		if "playtest_start" in destination:
			destination.playtest_start = 0
	else:
		destination.transfer_payload = payload.duplicate(true)
	var tree := get_tree()
	source_mode = source.process_mode
	tree.current_scene = null
	tree.root.remove_child(source)
	source_removed = true
	if restarting:
		tree.set_meta("journey_session", restart_session)
		restart_session_installed = true
	tree.root.add_child(destination)
	tree.current_scene = destination
	var deadline := Time.get_ticks_msec()+120000
	while not destination.is_entry_ready():
		if Time.get_ticks_msec() > deadline:
			_fail()
			return
		_observe_initialization(destination)
		await tree.process_frame
	await tree.physics_frame
	var saved: bool = destination.commit_level_restart() if restarting else destination.finish_flow_transfer(payload)
	if not saved:
		_fail()
		return
	if restarting:
		previous_pause = false
	committed = true
	source.queue_free()
	await _finish_loading()

func _rollback() -> void:
	if committed or not source_removed: return
	var tree := get_tree()
	if restart_session_installed and tree.has_meta("journey_session"):
		tree.remove_meta("journey_session")
	if is_instance_valid(destination):
		tree.root.remove_child(destination)
		destination.queue_free()
	tree.root.add_child(source)
	tree.current_scene = source
	source.process_mode = source_mode
	source_removed = false
	if source.has_method("flow_transfer_cancelled"): source.flow_transfer_cancelled()

func _fail() -> void:
	_rollback()
	super._fail()

func _cancel() -> void:
	_rollback()
	if is_instance_valid(source) and source.has_method("flow_transfer_cancelled"): source.flow_transfer_cancelled()
	super._cancel()
