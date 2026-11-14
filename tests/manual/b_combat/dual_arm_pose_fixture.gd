extends "res://tests/manual/b_combat/manual_modes_fixture.gd"
## Deterministic mouse direction for dual-module visual tests, never used in play.
var inspection_remaining := 0.0
var sprint_window_focused := true
var sprint_active := false
func has_arm_module(_side: int) -> bool:
	return true
