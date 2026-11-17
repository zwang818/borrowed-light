extends "res://scenes/ui/intro_cutscene/entry_loading.gd"
## Keep the source alive until a real destination and safe landing are ready.
var source: Node
var destination: Node
var payload: Dictionary
var source_mode := Node.PROCESS_MODE_INHERIT
var source_removed := false
var committed := false

func _switch_scene() -> void:
	switching = true
	_report_progress(0.85)
	destination = packed.instantiate()
	if destination == null or not destination.has_method("finish_flow_transfer"):
		_fail()
		return
	destination.transfer_payload = payload.duplicate(true)
	var tree := get_tree()
	source_mode = source.process_mode
	tree.current_scene = null
	tree.root.remove_child(source)
	source_removed = true
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
	if not destination.finish_flow_transfer(payload):
		_fail()
		return
	committed = true
	source.queue_free()
	await _finish_loading()

func _rollback() -> void:
	if committed or not source_removed: return
	var tree := get_tree()
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
