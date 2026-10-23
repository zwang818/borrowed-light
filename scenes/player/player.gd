extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died
const PARAMETERS := preload("res://scenes/weapons/combat_parameters.gd")
@export var max_health: int = PARAMETERS.PLAYER_HEALTH
var health: int = PARAMETERS.PLAYER_HEALTH
var is_dead: bool = false
var has_protocol: bool = false
var invulnerability_remaining: float = 0.0


## Prototype speed: 5 tiles/second at the test room's temporary 32 px/tile.
@export var move_speed: float = 160.0
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var move_up_action: StringName = &"move_up"
@export var move_down_action: StringName = &"move_down"
@export var shoot_action: StringName = &"shoot"
## The test room grants this weapon. Production acquisition belongs to C.
@export var pulse_gun_equipped: bool = false

var controls_enabled: bool = true
var aim_direction: Vector2 = Vector2.RIGHT

@onready var facing: Node2D = $Facing
@onready var pulse_gun: Node2D = $Facing/PulseGun


func _ready() -> void:
	health = max_health
	pulse_gun.visible = pulse_gun_equipped
	for action in [move_left_action, move_right_action, move_up_action, move_down_action, shoot_action]:
		if not InputMap.has_action(action):
			push_error("Player requires input action: %s" % action)
			set_physics_process(false)
			return


func _physics_process(delta: float) -> void:
	invulnerability_remaining = maxf(0.0, invulnerability_remaining - delta)
	if is_dead:
		facing.modulate = Color(0.3, 0.3, 0.3)
	elif invulnerability_remaining > 0.0:
		facing.modulate = Color(1, 0.4, 0.4, 0.55 if int(invulnerability_remaining * 20) % 2 == 0 else 1.0)
	else:
		facing.modulate = Color.WHITE
	pulse_gun.visible = pulse_gun_equipped
	if not controls_enabled:
		velocity = Vector2.ZERO
		pulse_gun.cancel()
		return
	# get_vector limits diagonal input to unit length.
	var direction := Input.get_vector(
		move_left_action, move_right_action, move_up_action, move_down_action
	)
	velocity = direction * move_speed
	move_and_slide()
	aim_at(get_global_mouse_position())
	if pulse_gun_equipped and not has_protocol:
		pulse_gun.advance_time(delta, global_position, aim_direction)
		if pulse_gun.state == pulse_gun.State.FIRING:
			aim_direction = pulse_gun.locked_direction
			facing.global_rotation = aim_direction.angle()
	else:
		pulse_gun.cancel()


func _unhandled_input(event: InputEvent) -> void:
	# An edge-triggered event catches short clicks and never repeats while held.
	if controls_enabled and not has_protocol and pulse_gun_equipped and event.is_action_pressed(shoot_action):
		aim_at(get_global_mouse_position())
		pulse_gun.request_fire(aim_direction)
		get_viewport().set_input_as_handled()


func aim_at(world_position: Vector2) -> void:
	if pulse_gun.state == pulse_gun.State.FIRING:
		aim_direction = pulse_gun.locked_direction
		facing.global_rotation = aim_direction.angle()
		return
	var offset := world_position - global_position
	# Keep the last facing when the cursor coincides with the player.
	if offset.length_squared() > 0.0001:
		aim_direction = offset.normalized()
		facing.global_rotation = aim_direction.angle()


func apply_damage(amount: int) -> void:
	if is_dead or amount <= 0 or invulnerability_remaining > 0.0:
		return
	health = maxi(0, health - amount)
	invulnerability_remaining = PARAMETERS.PLAYER_INVULNERABILITY
	health_changed.emit(health, max_health)
	if health == 0:
		is_dead = true
		controls_enabled = false
		velocity = Vector2.ZERO
		pulse_gun.cancel()
		died.emit()


func get_health_snapshot() -> Dictionary:
	return {"health": health, "max_health": max_health, "is_dead": is_dead}


func restore_player(location: Vector2, checkpoint_health: int, retained_weapons: Array) -> void:
	pulse_gun.cancel()
	global_position = location
	velocity = Vector2.ZERO
	health = clampi(checkpoint_health, 1, max_health)
	is_dead = false
	has_protocol = false
	invulnerability_remaining = 0.0
	pulse_gun_equipped = &"pulse_gun" in retained_weapons
	controls_enabled = true
	facing.modulate = Color.WHITE
	health_changed.emit(health, max_health)


func set_protocol_active(active: bool) -> void:
	has_protocol = active
	if active:
		pulse_gun.cancel()
