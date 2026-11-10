shader_type canvas_item;

// Sample a stable one-world-unit grid, including at fractional camera zoom.
uniform float pixel_world = 1.0;
uniform vec2 axis = vec2(0.906308, -0.422618);
uniform int finish = 0; // Shell, underside, distant bulkhead, grate.
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float grain(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 p = (floor(world_position / pixel_world) + 0.5) * pixel_world;
	vec2 local = floor(vec2(dot(p, axis), dot(p, vec2(-axis.y, axis.x))));
	vec2 size = finish == 2 ? vec2(224.0, 123.0) : vec2(96.0, 44.0);
	vec2 shifted = local + vec2(mod(floor(local.y / size.y), 2.0) * size.x * 0.5, 0.0);
	vec2 cell = floor(shifted / size);
	vec2 tile = mod(shifted, size);
	vec3 base = COLOR.rgb * (0.88 + grain(cell) * 0.20);
	float grit = grain(p);
	float stain = grain(floor(local / vec2(13.0, 8.0)));
	float fleck = grain(floor(local / vec2(4.0, 2.0)));
	base += (grit - 0.5) * 0.031 + (fleck - 0.5) * 0.021;
	if (tile.x < 2.0 || tile.y < 2.0) {
		base *= 0.51;
	} else if (tile.x < 3.0 || tile.y < 3.0) {
		base += 0.075;
	} else if (tile.x > size.x - 2.0 || tile.y > size.y - 2.0) {
		base *= 0.80;
	}
	vec2 bolt = min(tile, size - tile) - vec2(7.0, 6.0);
	if (dot(bolt, bolt) < 6.0) {
		base *= 0.47;
		if (bolt.y < -0.5) {
			base += 0.18;
		}
	}
	if (stain > 0.74 && fleck > 0.43 && finish != 3) {
		base = mix(base, vec3(0.30, 0.17, 0.12) * (finish == 2 ? 0.43 : 1.0), (stain - 0.72) * 2.0);
	}
	if (finish == 0 && fleck > 0.76 && stain > 0.55) {
		base += vec3(0.067, 0.038, 0.018);
	}
	if (finish == 0 && grain(cell + 93.0) > 0.76) {
		vec2 inset = min(tile, size - tile);
		if (inset.x > 19.0 && inset.y > 12.0 && inset.y < 15.0) {
			base *= mod(tile.x, 4.0) < 2.0 ? 0.58 : 1.12;
		}
	}
	if (finish == 3) {
		vec2 slot = mod(local, vec2(6.0, 11.0));
		if (slot.x < 3.0 && slot.y < 8.0) {
			base *= 0.25;
		} else if (slot.y == 8.0) {
			base += 0.09;
		}
	}
	if (finish == 2) {
		float depth = abs(local.y - 2595.0);
		float channel = mod(local.x + floor(local.y / 384.0) * 136.0, 366.0);
		float falloff = 1.0 - smoothstep(275.0, 1400.0, depth) * 0.46;
		base *= (channel < 40.0 ? 0.37 : 0.75) * falloff;
		if (channel > 40.0 && channel < 44.0) {
			base += vec3(0.065, 0.021, 0.025) * falloff;
		}
	}
	COLOR = vec4(base, COLOR.a);
}
