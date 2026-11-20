extends RefCounted
## Advance past battle in tests focused on the terminal, UI or achievements.

static func clear_exit_encounter(level: Node2D) -> bool:
	var start: Vector2 = level.player.global_position
	level.player.global_position = Vector2(855, 533)
	for enemy in level.enemies:
		enemy.apply_damage(enemy.health)
	for i in range(110):
		await level.get_tree().physics_frame
		if is_instance_valid(level.boss) and not level.boss.chassis.disabled:
			level.boss.apply_damage(level.boss.health)
			level.player.global_position = start
			return level.terminal_gate.collision_layer == 0
	level.player.global_position = start
	return false
