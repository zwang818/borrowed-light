extends "res://tests/manual/a_map/spine_hazard_preview.gd"
## Reuse A's authored timing, geometry, warning and visuals in production.
## Player owns damage immunity/death; the level owns retries and pause.
const HIT_DAMAGE := 1
const SNAPSHOT := preload("res://scenes/gameplay/journey_snapshot.gd")

func _ready() -> void:
	z_index = 12
	actor_hit.connect(_on_actor_hit)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_dead or not actor.controls_enabled:
		return
	super._physics_process(delta)

func _on_actor_hit(_device: String) -> void:
	if is_instance_valid(actor) and not actor.is_dead and actor.controls_enabled:
		actor.apply_damage(HIT_DAMAGE)

func capture_journey_state() -> Dictionary:
	var active_orbs := []
	for orb in orbs:
		active_orbs.append(SNAPSHOT.capture_fields(orb, [&"position", &"direction", &"travel_left"]))
	return {"elapsed": elapsed, "ring_hit_cycle": ring_hit_cycle.duplicate(), "orbs": active_orbs}

func restore_journey_state(data: Dictionary) -> void:
	SNAPSHOT.restore_fields(self, [&"elapsed"], data)
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
