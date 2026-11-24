extends "res://tests/manual/a_map/spine_hazard_preview.gd"
## Preview geometry now drives real damage; all shots/rings retain wall clipping.
const SNAPSHOT := preload("res://scenes/gameplay/journey_snapshot.gd")
var flow: Node
var blockade_time := 0.0
var pulse_warning := false
@export_range(0.01,1.0) var damage_ratio := 1.0

func _ready() -> void:
	cycle_speed = 4.0 / 3.0
	actor_hit.connect(_hit)

func _hit(_device: String) -> void:
	if actor.is_dead or not actor.controls_enabled: return
	actor.apply_damage(ceili(actor.max_health*damage_ratio))

func _physics_process(delta: float) -> void:
	if flow == null or not flow.story_ready or actor.is_dead: return
	super._physics_process(delta)
	if not flow.state.first_fall and actor.global_position.distance_to(flow.anchor("IsolationGate")) < 210:
		blockade_time += delta
		pulse_warning = true
		if blockade_time >= 3.0: _hit("封锁脉冲")
	else:
		blockade_time = 0
		pulse_warning = false

func reset_motion() -> void:
	super.reset_motion()
	blockade_time = 0
	pulse_warning = false

func _draw() -> void:
	super._draw()
	if pulse_warning:
		draw_arc(flow.anchor("DefenseElectrode03"), 35+blockade_time*28, 0, TAU, 64, Color("e6ac67"), 3)

func capture_journey_state() -> Dictionary:
	var active_orbs := []
	for orb in orbs:
		active_orbs.append(SNAPSHOT.capture_fields(orb, [&"position", &"direction", &"travel_left"]))
	return {"elapsed": elapsed, "ring_hit_cycle": ring_hit_cycle.duplicate(), "orbs": active_orbs, "blockade_time": blockade_time, "pulse_warning": pulse_warning}

func restore_journey_state(data: Dictionary) -> void:
	orbs.clear()
	SNAPSHOT.restore_fields(self, [&"elapsed", &"blockade_time", &"pulse_warning"], data)
	var cycles = data.get("ring_hit_cycle")
	if cycles is Array and cycles.size() == ring_hit_cycle.size():
		for i in range(cycles.size()):
			if SNAPSHOT.number(cycles[i]):
				ring_hit_cycle[i] = int(cycles[i])
	var active_orbs = data.get("orbs")
	if active_orbs is Array:
		for state in active_orbs:
			if not state is Dictionary or not SNAPSHOT.point(state.get("position")) or not SNAPSHOT.point(state.get("direction")):
				continue
			var orb := Orb.new()
			SNAPSHOT.restore_fields(orb, [&"position", &"direction", &"travel_left"], state)
			orbs.append(orb)
	queue_redraw()
