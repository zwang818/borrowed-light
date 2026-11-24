extends AudioStreamPlayer

const FIELD_PLAYER := preload("res://scenes/player/xiaoyi_field_player.gd")
const STEPS := [
	preload("res://assets/audio/footsteps/xiaoyi_steel_01.wav"),
	preload("res://assets/audio/footsteps/xiaoyi_steel_02.wav"),
	preload("res://assets/audio/footsteps/xiaoyi_steel_03.wav"),
	preload("res://assets/audio/footsteps/xiaoyi_steel_04.wav"),
]
const STEP_DISTANCE := 40.0
const FIRST_STEP_DISTANCE := 18.0
const WALK_VOLUME_DB := -16.0
const BOSS_BATTLE_VOLUME_DB := -24.0

var player: FIELD_PLAYER
var previous_position := Vector2.ZERO
var distance_to_step := FIRST_STEP_DISTANCE
var next_foot := 0


func _ready() -> void:
	# Sample the movement that the player completed on this physics tick.
	process_physics_priority = 2
	previous_position = player.global_position
	volume_db = WALK_VOLUME_DB


func set_boss_battle(active: bool) -> void:
	volume_db = BOSS_BATTLE_VOLUME_DB if active else WALK_VOLUME_DB


func _physics_process(delta: float) -> void:
	var position_now := player.global_position
	var displacement := position_now - previous_position
	previous_position = position_now
	if not player.controls_enabled or player.is_dead or not player.is_physics_processing():
		distance_to_step = FIRST_STEP_DISTANCE
		stop()
		return
	if displacement.length() > maxf(32.0, player.move_speed * delta * 2.0):
		# A duct jump or respawn is not a step.
		distance_to_step = FIRST_STEP_DISTANCE
		stop()
		return
	# Count distance before visual gait scaling so sprint uses the faster rhythm.
	var travel := player.sprint_motion.length()
	if travel <= 0.05:
		distance_to_step = FIRST_STEP_DISTANCE
		return
	distance_to_step -= travel
	if distance_to_step > 0.0:
		return
	distance_to_step += STEP_DISTANCE
	stream = STEPS[next_foot]
	next_foot = (next_foot + 1) % STEPS.size()
	play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		distance_to_step = FIRST_STEP_DISTANCE
		stop()
