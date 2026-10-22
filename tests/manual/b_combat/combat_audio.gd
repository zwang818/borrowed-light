extends Node
## B-only presentation adapter: never edits shared combat code or AB resources.
signal sound_played(id: StringName)
const DIR := "res://tests/manual/b_combat/audio/"
const LIMIT := 8
var player
var sentry
var cleaner
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var previous_health: Dictionary = {}
var previous_states: Dictionary = {}
var cooldowns: Dictionary = {}
var previous_position := Vector2.ZERO
var step_distance := 0.0
var previous_protocol := false
var previous_weapon := false
var resetting := false
var step_variant := 0

func _ready() -> void:
	process_physics_priority = 100
	var scene := get_parent()
	player = scene.get_node("SpawnPoints/PlayerSpawn/Player")
	sentry = scene.get_node("SpawnPoints/SentrySpawn/Sentry")
	cleaner = scene.get_node("SpawnPoints/CleanerSpawn/Cleaner")
	for actor in [player, sentry, cleaner]:
		actor.health_changed.connect(_health_changed.bind(actor))
	sentry.shot_fired.connect(func(): play_sound(&"sentry_fire"))
	reset_audio()

func play_sound(id: StringName) -> void:
	if get_tree().paused or (player.is_dead and id != &"player_shutdown"):
		return
	if float(cooldowns.get(id, 0.0)) > 0.0:
		return
	cooldowns[id] = 0.07
	var voice: AudioStreamPlayer
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		if voices.size() >= LIMIT:
			# Reserve critical feedback by replacing the oldest ordinary voice.
			if id not in [&"player_hurt", &"player_shutdown", &"cleaner_warning", &"sentry_warning"]:
				return
			voice = voices.pop_front()
			voices.append(voice)
			voice.stop()
		else:
			voice = AudioStreamPlayer.new()
			add_child(voice)
			voices.append(voice)
	var resource_id := String(id)
	if id == &"player_step":
		resource_id = ["player_step", "player_step_2", "player_step_3", "player_step_4"][step_variant % 4]
		step_variant += 1
	if not streams.has(resource_id):
		streams[resource_id] = load(DIR + resource_id + ".wav")
	voice.stream = streams[resource_id]
	voice.set_meta("sound_id", id)
	voice.volume_db = -22 if id == &"player_step" else (-5 if id in [&"player_hurt", &"player_shutdown", &"cleaner_warning", &"sentry_warning"] else -11)
	voice.pitch_scale = 1.0
	voice.play()
	sound_played.emit(id)

func stop_sound(id: StringName) -> void:
	for voice in voices:
		if voice.get_meta("sound_id", &"") == id:
			voice.stop()

func stop_all() -> void:
	for voice in voices:
		voice.stop()
	cooldowns.clear()
	step_distance = 0

func reset_audio() -> void:
	resetting = false
	stop_all()
	for actor in [player, sentry, cleaner]:
		previous_health[actor] = actor.health
	previous_states[sentry] = sentry.state
	previous_states[cleaner] = cleaner.state
	previous_position = player.global_position
	previous_protocol = player.has_protocol
	previous_weapon = player.pulse_gun_equipped

func _health_changed(current: int, _maximum: int, actor: Node) -> void:
	var old: int = previous_health.get(actor, current)
	previous_health[actor] = current
	if resetting:
		return
	if current >= old:
		if actor == player and current > old and old > 0:
			play_sound(&"repair")
		return
	if actor == player:
		if current == 0:
			stop_all()
			play_sound(&"player_shutdown")
		else:
			play_sound(&"player_hurt")
	elif current == 0:
		stop_sound(&"cleaner_warning" if actor == cleaner else &"sentry_warning")
		stop_sound(&"cleaner_attack" if actor == cleaner else &"sentry_fire")
		play_sound(&"enemy_shutdown")
	else:
		play_sound(&"enemy_hit")

func _physics_process(delta: float) -> void:
	for id in cooldowns:
		cooldowns[id] = maxf(0, cooldowns[id] - delta)
	if player.is_dead:
		return
	var distance: float = previous_position.distance_to(player.global_position)
	previous_position = player.global_position
	# Actual displacement, not held keys: no footsteps when pushing a wall.
	if distance > 0.05 and distance < player.move_speed * delta * 2 and player.controls_enabled:
		step_distance += distance
		if step_distance >= 26:
			step_distance = fmod(step_distance, 26)
			play_sound(&"player_step")
	else:
		step_distance = 0
		stop_sound(&"player_step")
	for actor in [sentry, cleaner]:
		var previous: int = previous_states[actor]
		var warning: StringName = &"cleaner_warning" if actor == cleaner else &"sentry_warning"
		if actor.state != previous:
			if actor.state == actor.State.WARNING:
				play_sound(warning)
			else:
				stop_sound(warning)
			if actor == cleaner and actor.state == cleaner.State.ATTACK:
				play_sound(&"cleaner_attack")
			previous_states[actor] = actor.state
	if previous_protocol != player.has_protocol:
		play_sound(&"protocol_enter" if player.has_protocol else &"protocol_exit")
		previous_protocol = player.has_protocol
	if previous_weapon != player.pulse_gun_equipped:
		if player.pulse_gun_equipped:
			play_sound(&"weapon_pickup")
		previous_weapon = player.pulse_gun_equipped

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		stop_all()
		if is_instance_valid(player):
			player.pulse_gun.get_node("Audio/Charge").stop()
			player.pulse_gun.get_node("Audio/Laser").stop()
	elif what == NOTIFICATION_UNPAUSED and is_instance_valid(player):
		reset_audio()
