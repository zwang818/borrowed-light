extends "res://scenes/player/xiaoyi_map_player.gd"
## Shared movement/status behavior; ability acquisition remains owned by the level.
func _enter_tree() -> void:
	if not InputMap.has_action(SPRINT_ACTION):
		InputMap.add_action(SPRINT_ACTION)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SHIFT
		InputMap.action_add_event(SPRINT_ACTION,key)

const SPRINT_ACTION := &"b_sprint"
@export var sprint_multiplier: float = 1.25
var web_slow_remaining := 0.0
var web_speed_factor := 1.0
var sprint_active := false
var sprint_motion := Vector2.ZERO
var sprint_window_focused := true

func _physics_process(delta: float) -> void:
	web_slow_remaining = maxf(0.0,web_slow_remaining-delta)
	if web_slow_remaining <= 0.0 or is_dead:
		web_speed_factor = 1.0
		web_slow_remaining = 0.0
	sprint_active = sprint_window_focused and controls_enabled and not is_dead and Input.is_action_pressed(SPRINT_ACTION)
	var normal_speed := move_speed
	var before := global_position
	move_speed *= web_speed_factor
	if sprint_active:
		move_speed *= sprint_multiplier
	super._physics_process(delta)
	move_speed = normal_speed
	sprint_motion = global_position-before

func gait_displacement(displacement: Vector2) -> Vector2:
	# Cover more ground per step without speeding up the existing leg cycle.
	return displacement / sprint_multiplier if sprint_active else displacement

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		sprint_window_focused = false
		sprint_active = false
		sprint_motion = Vector2.ZERO
		Input.action_release(SPRINT_ACTION)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		sprint_window_focused = true

func restore_player(location: Vector2, checkpoint_health: int, retained_weapons: Array) -> void:
	web_slow_remaining = 0.0
	web_speed_factor = 1.0
	sprint_active = false
	sprint_motion = Vector2.ZERO
	super.restore_player(location, checkpoint_health, retained_weapons)

func apply_web_slow(duration: float, factor: float) -> void:
	if is_dead or has_protocol or not controls_enabled:
		return
	web_slow_remaining = maxf(web_slow_remaining,duration)
	web_speed_factor = minf(web_speed_factor,clampf(factor,0.1,1.0))
