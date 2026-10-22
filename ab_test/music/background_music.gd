extends AudioStreamPlayer
## AB snapshot; future B changes require an explicit sync.
const TRACK = preload("res://ab_test/music/interior_exploration.wav")
const BASE_DB := -24.0
const DUCK_DB := -32.0
var player
var enemies: Array = []
var fade: Tween
var duck_remaining := 0.0

func _ready() -> void:
	var scene := get_parent()
	player = scene.player
	enemies.assign(scene.cleaners)
	var loop := TRACK.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
	stream = loop
	player.died.connect(_on_death)
	scene.get_node("CombatAudio").sound_played.connect(_on_sound)
	restart()

func restart() -> void:
	if fade != null:
		fade.kill()
	duck_remaining = 0
	volume_db = -60
	play()
	fade = create_tween()
	fade.tween_property(self, "volume_db", BASE_DB, 0.8)

func _on_death() -> void:
	if fade != null:
		fade.kill()
	fade = create_tween()
	fade.tween_property(self, "volume_db", -60.0, 0.3)
	fade.tween_callback(stop)

func _on_sound(id: StringName) -> void:
	if id in [&"player_hurt", &"cleaner_warning", &"sentry_warning"]:
		duck_remaining = 0.7

func _process(delta: float) -> void:
	if player.is_dead:
		return
	duck_remaining = maxf(0, duck_remaining - delta)
	var warning := false
	for enemy in enemies:
		warning = warning or enemy.state == enemy.State.WARNING
	var target := DUCK_DB if warning or duck_remaining > 0 else BASE_DB
	if target == DUCK_DB and fade != null and fade.is_running():
		fade.kill()
	if fade == null or not fade.is_running():
		volume_db = move_toward(volume_db, target, delta * (70 if target == DUCK_DB else 8))
