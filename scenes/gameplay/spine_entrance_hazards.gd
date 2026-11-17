extends "res://tests/manual/a_map/spine_hazard_preview.gd"
## Reuse A's authored timing, geometry, warning and visuals in production.
## Player owns damage immunity/death; the level owns retries and pause.
const HIT_DAMAGE := 1

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
