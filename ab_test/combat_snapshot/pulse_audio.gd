extends Node

# Presentation consumes weapon events; it never changes combat state.
func _ready() -> void:
	get_parent().state_changed.connect(_on_weapon_state_changed)


func _on_weapon_state_changed(state_name: StringName) -> void:
	$Charge.stop()
	$Laser.stop()
	if state_name == &"charging":
		$Charge.play()
	elif state_name == &"firing":
		$Laser.play()
