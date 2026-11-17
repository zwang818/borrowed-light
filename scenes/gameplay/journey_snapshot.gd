extends RefCounted
## The disk snapshot resumes the running encounter. The level's retry baseline
## continues to use restore_player / restore_combat_state on its original data.
const PLAYER_FIELDS := [&"global_position", &"velocity", &"health", &"aim_direction",
	&"has_protocol", &"invulnerability_remaining", &"selected_mode", &"attack_mode", &"scatter_remaining",
	&"holster_remaining", &"inspection_remaining", &"web_slow_remaining", &"web_speed_factor"]
const PLAYER_POSE_FIELDS := [&"walk_distance", &"turn_elapsed", &"relaxed_walk_strength",
	&"relaxed_walk_phase", &"gait_strength", &"scatter_flip"]
const ENEMY_FIELDS := [&"global_position", &"health", &"remaining", &"hurt_flash", &"locked_direction"]
const CLEANER_FIELDS := [&"velocity", &"attack_hit", &"web_phase", &"web_remaining",
	&"web_cooldown", &"web_direction"]
const PAIR_FIELDS := [&"engaged", &"covers_retreat", &"taking_side_route"]
const SENTRY_FIELDS := [&"shots_left", &"attack_mode", &"next_attack_mode", &"attack_center", &"shot_index"]
const GUN_FIELDS := [&"remaining", &"contact_remaining", &"locked_direction", &"pending_direction"]
const BULLET_FIELDS := [&"global_position", &"global_rotation", &"direction", &"travelled", &"speed", &"unlimited_range"]
const SILK_FIELDS := [&"global_position", &"direction", &"speed", &"lifetime", &"persistent_flight"]
const BULLET := preload("res://scenes/weapons/enemy_projectile.tscn")
const SILK := preload("res://tests/manual/b_combat/web_projectile.gd")

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 1.0e9

static func point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])

static func vector(data: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return Vector2(data[0], data[1]) if point(data) else fallback

static func pack_vector(value: Vector2) -> Array:
	return [value.x, value.y]

static func capture_fields(node: Object, fields: Array) -> Dictionary:
	var data := {}
	for field in fields:
		var value = node.get(field)
		data[String(field)] = pack_vector(value) if value is Vector2 else value
	return data

static func restore_fields(node: Object, fields: Array, data: Dictionary) -> void:
	for field in fields:
		var value = data.get(String(field))
		var original = node.get(field)
		if original is Vector2 and point(value):
			node.set(field, vector(value))
		elif original is bool and value is bool:
			node.set(field, value)
		elif original is int and number(value):
			node.set(field, int(value))
		elif original is float and number(value):
			node.set(field, float(value))

static func capture(level: Node, player: Node2D, enemies: Array, bullets: Node, webs: Array = []) -> Dictionary:
	var targets := _targets(enemies, webs)
	var actors := {}
	for enemy in enemies:
		actors[String(enemy.entity_id)] = _capture_enemy(enemy)
	return {"player": _capture_player(player, targets), "enemies": actors,
		"projectiles": _capture_projectiles(level, bullets)}

static func restore(player: Node2D, enemies: Array, bullets: Node, data: Dictionary, webs: Array = []) -> void:
	for enemy in enemies:
		var actor: Dictionary = data.enemies.get(String(enemy.entity_id), {})
		if not actor.is_empty():
			_restore_enemy(enemy, actor)
	_restore_player(player, data.player, _targets(enemies, webs))
	_restore_projectiles(player, enemies, bullets, data.get("projectiles", []))

static func _targets(enemies: Array, webs: Array) -> Dictionary:
	var targets := {}
	for enemy in enemies:
		targets[String(enemy.entity_id)] = enemy
	for web in webs:
		targets["web/" + String(web.name)] = web
	return targets

static func _capture_player(player: Node2D, targets: Dictionary) -> Dictionary:
	var data := capture_fields(player, PLAYER_FIELDS)
	var visual := player.get_node("Facing/XiaoyiCombatVisual")
	data["pose"] = capture_fields(visual, PLAYER_POSE_FIELDS)
	data.pose["facing_row"] = visual.facing_row
	data.pose["target_row"] = visual.target_row
	data.pose["current_column"] = visual.current_column
	var gun = player.pulse_gun
	data["gun"] = capture_fields(gun, GUN_FIELDS)
	data.gun["state"] = gun.state
	data.gun["glow_position"] = pack_vector(gun.charge_glow.position)
	data.gun["beam_points"] = []
	for world_point in gun.beam_points:
		data.gun.beam_points.append(pack_vector(world_point))
	data.gun["damaged"] = []
	for id in targets:
		if gun.damaged_targets.has(targets[id].get_instance_id()):
			data.gun.damaged.append(id)
	return data

static func _restore_player(player: Node2D, data: Dictionary, targets: Dictionary) -> void:
	restore_fields(player, PLAYER_FIELDS, data)
	player.health = clampi(player.health, 0, player.max_health)
	player.is_dead = player.health == 0
	player.controls_enabled = not player.is_dead
	player.facing.global_rotation = player.aim_direction.angle()
	if player.is_dead:
		player.facing.modulate = Color(0.3, 0.3, 0.3)
	elif player.invulnerability_remaining > 0.0:
		player.facing.modulate = Color(1, 0.4, 0.4, 0.55 if int(player.invulnerability_remaining * 20) % 2 == 0 else 1.0)
	var gun = player.pulse_gun
	if not player.is_dead and player.pulse_gun_equipped and not player.has_protocol:
		_restore_gun(gun, data.get("gun", {}), targets)
	if player.selected_mode != player.AttackMode.SCATTER or not player.scatter_unlocked:
		player.selected_mode = player.AttackMode.LASER
	player.attack_mode = clampi(player.attack_mode, player.AttackMode.LASER, player.AttackMode.SCATTER)
	gun.visible = player.can_fire_pulse()
	var visual := player.get_node("Facing/XiaoyiCombatVisual")
	var pose: Dictionary = data.get("pose", {})
	restore_fields(visual, PLAYER_POSE_FIELDS, pose)
	visual.facing_row = _bounded_int(pose.get("facing_row"), 0, 7)
	visual.target_row = _bounded_int(pose.get("target_row"), 0, 7)
	visual.current_column = _bounded_int(pose.get("current_column"), 0, 3)
	visual.previous_position = player.global_position
	visual._show_frame()
	player.health_changed.emit(player.health, player.max_health)

static func _restore_gun(gun: Node2D, data: Dictionary, targets: Dictionary) -> void:
	gun.state = _bounded_int(data.get("state"), gun.State.IDLE, gun.State.FIRING)
	restore_fields(gun, GUN_FIELDS, data)
	if gun.state == gun.State.CHARGING:
		gun.charge_glow.position = vector(data.get("glow_position"))
		gun.charge_glow.scale = Vector2.ONE * lerpf(0.35, 1.0, clampf(1.0 - gun.remaining / gun.CHARGE_DURATION, 0.0, 1.0))
		gun.charge_glow.show()
	elif gun.state == gun.State.FIRING:
		for id in data.get("damaged", []):
			if targets.has(id):
				gun.damaged_targets[targets[id].get_instance_id()] = true
		var local_points := PackedVector2Array()
		for encoded in data.get("beam_points", []):
			var world_point := vector(encoded)
			gun.beam_points.append(world_point)
			local_points.append(gun.beam.to_local(world_point))
		for line in [gun.beam, gun.beam_core]:
			line.points = local_points
			line.visible = local_points.size() > 1

static func _capture_enemy(enemy: Node2D) -> Dictionary:
	var data := capture_fields(enemy, ENEMY_FIELDS)
	data["state"] = enemy.state
	data["facing"] = enemy.get_node("Facing").rotation
	if enemy is CharacterBody2D:
		data.merge(capture_fields(enemy, CLEANER_FIELDS))
		data["patrol_index"] = enemy.patrol_index
		if "engaged" in enemy:
			data.merge(capture_fields(enemy, PAIR_FIELDS))
		data["pose"] = capture_fields(enemy.combat_visual(), [&"face_left", &"stride", &"walked_this_tick"])
	else:
		data.merge(capture_fields(enemy, SENTRY_FIELDS))
		data["pose"] = capture_fields(enemy.model, [&"aim_angle", &"phase", &"recoil"])
	return data

static func _restore_enemy(enemy: Node2D, data: Dictionary) -> void:
	var position := vector(data.global_position, enemy.global_position)
	enemy.restore_combat_state({"entity_id": enemy.entity_id, "health": data.health,
		"position": position, "patrol_index": _bounded_int(data.get("patrol_index"), 0, 1000)})
	enemy.global_position = position
	restore_fields(enemy, [&"remaining", &"hurt_flash", &"locked_direction"], data)
	if enemy.health > 0:
		enemy.state = _bounded_int(data.state, 0, enemy.State.DEAD - 1)
	if number(data.get("facing")):
		enemy.get_node("Facing").rotation = float(data.facing)
	enemy.update_visuals()
	var pose: Dictionary = data.get("pose", {})
	if enemy is CharacterBody2D:
		restore_fields(enemy, CLEANER_FIELDS, data)
		if "engaged" in enemy:
			restore_fields(enemy, PAIR_FIELDS, data)
		var visual = enemy.combat_visual()
		restore_fields(visual, [&"face_left", &"stride", &"walked_this_tick"], pose)
		visual.previous = enemy.position
		visual.modulate = enemy.get_node("Facing").modulate
		visual._update_hurtbox()
		visual.queue_redraw()
	else:
		restore_fields(enemy, SENTRY_FIELDS, data)
		enemy.attack_mode = clampi(enemy.attack_mode, 0, 1)
		enemy.next_attack_mode = clampi(enemy.next_attack_mode, 0, 1)
		restore_fields(enemy.model, [&"aim_angle", &"phase", &"recoil"], pose)
		enemy.model.update_pose()

static func _capture_projectiles(level: Node, bullets: Node) -> Array:
	var projectiles := []
	for bullet in bullets.get_children():
		if not bullet.spent and not bullet.is_queued_for_deletion():
			projectiles.append({"kind": "bullet", "state": capture_fields(bullet, BULLET_FIELDS)})
	for web in level.get_tree().get_nodes_in_group("b_cleaner_webs"):
		if level.is_ancestor_of(web) and not web.spent and not web.is_queued_for_deletion() and is_instance_valid(web.source):
			projectiles.append({"kind": "silk", "source": String(web.source.entity_id), "state": capture_fields(web, SILK_FIELDS)})
	for burst in level.get_tree().get_nodes_in_group("b_scatter_flashes"):
		if level.is_ancestor_of(burst) and not burst.is_queued_for_deletion():
			var state := capture_fields(burst, [&"global_position", &"global_rotation", &"age"])
			var pellets := []
			for i in range(burst.pellet_count):
				pellets.append({"point": pack_vector(burst.points[i]), "distance": burst.distances[i], "spent": burst.spent[i]})
			projectiles.append({"kind": "scatter", "state": state, "pellets": pellets})
	return projectiles

static func _restore_projectiles(player: Node2D, enemies: Array, bullets: Node, data: Array) -> void:
	var sources := _targets(enemies, [])
	for item in data:
		var state: Dictionary = item.state
		match item.kind:
			"bullet":
				var bullet := BULLET.instantiate()
				bullets.add_child(bullet)
				restore_fields(bullet, BULLET_FIELDS, state)
			"silk":
				var source: Node2D = sources.get(item.get("source", ""))
				if source == null:
					continue
				var web := Node2D.new()
				web.set_script(SILK)
				web.source = source
				source.get_parent().add_child(web)
				restore_fields(web, SILK_FIELDS, state)
			"scatter":
				var burst = player.scatter_burst_script.new()
				burst.player = player
				player.get_parent().add_child(burst)
				restore_fields(burst, [&"global_position", &"global_rotation", &"age"], state)
				for i in range(mini(item.pellets.size(), burst.pellet_count)):
					var pellet: Dictionary = item.pellets[i]
					burst.points[i] = vector(pellet.point)
					burst.distances[i] = clampf(pellet.distance, 0.0, burst.RANGE)
					burst.spent[i] = pellet.spent

static func _bounded_int(value: Variant, low: int, high: int) -> int:
	return clampi(int(value), low, high) if number(value) else low
