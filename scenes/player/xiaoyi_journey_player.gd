extends "res://scenes/player/xiaoyi_field_player.gd"
const SCATTER_AUDIO := preload("res://assets/audio/mechanicals/09_scatter_mechanism.wav")
var scatter_audio: AudioStreamPlayer

## Approved scatter behavior; the level owns ability acquisition.
var scatter_burst_script: Script = preload("res://tests/manual/b_combat/scatter_burst_a.gd")
func fire_scatter(direction: Vector2) -> bool:
	if not scatter_unlocked or attack_mode != AttackMode.SCATTER or is_dead or not controls_enabled or has_protocol or scatter_remaining > 0.0 or direction.is_zero_approx():
		return false
	holster_remaining = HOLSTER_DELAY
	scatter_remaining = 0.75
	var origin := get_shot_origin(AttackMode.SCATTER)
	if not origin.blocked:
		if scatter_audio == null:
			scatter_audio = AudioStreamPlayer.new()
			scatter_audio.name = "ScatterMechanismAudio"
			scatter_audio.stream = SCATTER_AUDIO
			scatter_audio.volume_db = -3.0
			add_child(scatter_audio)
		scatter_audio.play()
		var flash = scatter_burst_script.new()
		flash.player = self
		get_parent().add_child(flash)
		flash.global_position = origin.position
		flash.global_rotation = direction.angle()
	return true

func restore_player(location: Vector2, checkpoint_health: int, retained_weapons: Array) -> void:
	super.restore_player(location,checkpoint_health,retained_weapons)
	if is_instance_valid(scatter_audio):
		scatter_audio.stop()
	for flash in get_tree().get_nodes_in_group("b_scatter_flashes"):
		flash.queue_free()
