extends "res://scenes/player/xiaoyi_journey_player.gd"
## Only the independent graybox grants scatter before its story evolution.
func _ready() -> void:
	scatter_unlocked = true
	super._ready()
