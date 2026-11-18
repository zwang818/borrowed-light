extends Node
## Save on a normal window close, even while the room is paused.
var save_before_exit: Callable
var previous_auto_quit: bool

func _ready() -> void:
	previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_on_close_requested)

func _exit_tree() -> void:
	get_tree().root.close_requested.disconnect(_on_close_requested)
	get_tree().auto_accept_quit = previous_auto_quit

func _on_close_requested() -> void:
	if save_before_exit.call():
		get_tree().quit()
	else:
		OS.alert("存档失败，请检查磁盘空间或文件权限。")
