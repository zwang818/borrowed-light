shader_type canvas_item;

// Age the painted and cast faces on the prop's own pixel grid.
varying vec2 fixture_position;

void vertex() {
	fixture_position = VERTEX;
}

float grain(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 p = floor(fixture_position);
	float coarse = grain(floor(p / vec2(6.0, 4.0)));
	float fine = grain(p);
	float nick = grain(floor(p / vec2(3.0, 2.0)));
	float light = max(max(COLOR.r, COLOR.g), COLOR.b);
	float warm = smoothstep(0.00, 0.14, COLOR.r - COLOR.b);
	float matte = smoothstep(0.16, 0.35, light) * (1.0 - smoothstep(0.55, 0.87, light));
	vec3 final_color = COLOR.rgb * (1.0 + matte * ((fine - 0.5) * 0.09 + (coarse - 0.5) * 0.14));
	float chip = step(0.70, coarse) * step(0.79, nick) * (1.0 - step(0.84, fine));
	final_color += vec3(0.082, 0.052, 0.030) * matte * (0.45 + warm * 0.55) * chip;
	COLOR = vec4(final_color, COLOR.a);
}
