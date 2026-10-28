@tool
extends Node2D
## Drawn under floors and walls with ServiceCavity; no particles, collision or gameplay.
var cycle_phase := 0.0
const VENTS := [Vector2(709, 487), Vector2(854, 359), Vector2(1000, 1118), Vector2(315, 250)]

func _draw() -> void:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var view := inverse * get_viewport_rect()
	for row in range(8):
		for column in range(6):
			var origin := Vector2(-1152 + column * 640, -1024 + row * 640)
			if not view.grow(80).intersects(Rect2(origin, Vector2(640, 640))):
				continue
			var offset := (float(column) * 1.73 + float(row) * 2.31) / TAU
			for vent in range(VENTS.size()):
				var nozzle: Vector2 = origin + VENTS[vent] / 1254.0 * 640.0
				var direction := -1.0 if vent == 1 else 1.0
				# A short release followed by a long quiet interval; each vent is offset.
				for puff in range(5):
					var age := fposmod(cycle_phase + offset + float(vent) * 0.31 - float(puff) * 0.022, 1.0)
					if age > 0.24:
						continue
					var t := age / 0.24
					var center := nozzle + Vector2(direction * (t * 28.0 + sin(t * PI) * 6.0), -t * 46.0)
					var alpha := sin(t * PI) * 0.15
					_cloud(center, 2.0 + t * 10.0, Color(0.56, 0.67, 0.67, alpha), puff)

func _cloud(center: Vector2, radius: float, color: Color, seed: int) -> void:
	# Stepped silhouettes keep vapor soft without smooth high-resolution blobs.
	var r := maxf(2.0, floor(radius / 2.0) * 2.0)
	var c := center.snapped(Vector2(2, 2))
	var lean := 2.0 if seed % 2 == 0 else -2.0
	draw_rect(Rect2(c + Vector2(-r * 0.5 + lean, -r), Vector2(r, r * 0.5)), color)
	draw_rect(Rect2(c + Vector2(-r, -r * 0.5), Vector2(r * 2, r)), color)
	draw_rect(Rect2(c + Vector2(-r * 0.5 - lean, r * 0.5), Vector2(r, r * 0.5)), color)
