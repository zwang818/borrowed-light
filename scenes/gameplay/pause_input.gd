extends Node
## Keeps only the pause key active while the gameplay scene tree is paused.

var target: Node


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and is_instance_valid(target):
		target.call("_toggle_pause")
		get_viewport().set_input_as_handled()
