extends "res://tests/manual/b_combat/xiaoyi_graybox_visual.gd"
## Shared gold sparks and dust for the combat graybox and main level.
var spark_length_scale := 1.0
var sparks_enabled := true
var dust_color := Color(0.46,0.48,0.37,0.65)
var trail: Node2D
func _ready() -> void:
	super._ready()
	trail = preload("res://tests/manual/b_combat/sprint_sparks.gd").new()
	trail.player = player
	trail.spark_length_scale = spark_length_scale
	trail.sparks_enabled = sparks_enabled
	trail.dust_color = dust_color
	add_child(trail)
func _draw_sprint_trail() -> void:
	pass # World-space sparks/dust replace the attached cyan lines.
