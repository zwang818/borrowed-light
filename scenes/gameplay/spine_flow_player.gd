extends "res://scenes/player/xiaoyi_journey_player.gd"
## The production gun and swept pellets are unchanged; only the pressure budget is added.
signal pressure_changed(remaining: int)
signal scatter_empty
var pressure_limited := false
var pressure := 0
var calibration_enabled := false
var protocol_after_move: Callable

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if protocol_after_move.is_valid():
		protocol_after_move.call()

func update_combat_mode() -> void:
	super.update_combat_mode()
	if has_protocol:
		attack_mode = AttackMode.UNARMED

func has_arm_module(side: int) -> bool:
	return (side == 1 and calibration_enabled) or super.has_arm_module(side)

func set_attack_mode(mode: int) -> bool:
	var learned := scatter_unlocked
	if calibration_enabled: scatter_unlocked = true
	var result := super.set_attack_mode(mode)
	scatter_unlocked = learned
	return result

func fire_scatter(direction: Vector2) -> bool:
	if pressure_limited and not calibration_enabled and pressure <= 0:
		if scatter_unlocked and attack_mode == AttackMode.SCATTER and controls_enabled and not is_dead and not has_protocol:
			scatter_empty.emit()
		return false
	var learned := scatter_unlocked
	if calibration_enabled: scatter_unlocked = true
	var fired := super.fire_scatter(direction)
	scatter_unlocked = learned
	if fired and pressure_limited and not calibration_enabled:
		pressure -= 1
		pressure_changed.emit(pressure)
	return fired
