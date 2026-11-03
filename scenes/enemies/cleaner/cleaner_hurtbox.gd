extends Area2D
## Damage-only silhouette; movement still uses the cleaner's foot collider.
func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	get_parent().health_changed.connect(_on_health_changed)
	_on_health_changed(get_parent().health, get_parent().max_health)

func get_damage_receiver() -> Node:
	return get_parent()

func apply_damage(amount: int) -> void:
	get_damage_receiver().apply_damage(amount)

func _on_health_changed(health: int, _maximum: int) -> void:
	set_deferred("collision_layer", 4 if health > 0 else 0)
