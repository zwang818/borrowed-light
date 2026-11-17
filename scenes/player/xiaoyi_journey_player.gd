extends "res://scenes/player/xiaoyi_field_player.gd"
## Approved scatter behavior; the level owns ability acquisition.
func fire_scatter(direction: Vector2) -> bool:
	if not scatter_unlocked or attack_mode != AttackMode.SCATTER or is_dead or not controls_enabled or has_protocol or scatter_remaining > 0.0 or direction.is_zero_approx():
		return false
	holster_remaining = HOLSTER_DELAY
	scatter_remaining = 0.75
	var origin := get_shot_origin(AttackMode.SCATTER)
	if not origin.blocked:
		var flash := preload("res://tests/manual/b_combat/scatter_burst.gd").new()
		flash.player = self
		get_parent().add_child(flash)
		flash.global_position = origin.position
		flash.global_rotation = direction.angle()
	return true

func restore_player(location: Vector2, checkpoint_health: int, retained_weapons: Array) -> void:
	super.restore_player(location,checkpoint_health,retained_weapons)
	for flash in get_tree().get_nodes_in_group("b_scatter_flashes"):
		flash.queue_free()
