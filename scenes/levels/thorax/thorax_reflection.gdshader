shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float phase = 0.0;
uniform float lamp_level = 0.94;
varying vec2 deck_position;

void vertex() {
	deck_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float patches(vec2 cell) {
	vec3 q = fract(vec3(cell.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 point = floor(deck_position);
	float y = UV.y;
	float x = abs(UV.x - 0.5);
	float footprint = (1.0 - smoothstep(0.08, max(0.09, 0.45 - y * 0.24), x));
	float fade = (1.0 - smoothstep(0.08, 1.0, y)) * smoothstep(0.0, 0.045, y);
	float plate_bevel = step(2.0, mod(point.y, 76.0)) * step(2.0, mod(point.x, 76.0));
	float row = floor(point.y / 2.0);
	float shift = patches(vec2(row, 17.0)) * 43.0;
	vec2 flake = vec2(floor((point.x + shift) / 7.0), row);
	float migration = sin(point.y * 0.102 - phase * 5.1 + sin(point.x * 0.037));
	float brushed = sin(point.x * 0.081 + sin(point.y * 0.16) * 1.8) * 0.13;
	float glint = smoothstep(0.30, 0.76, patches(flake) * 0.59 + brushed + migration * 0.17);
	float intensity = mix(0.24, 0.79, glint) * footprint * fade * lamp_level;
	COLOR = vec4(1.0, 0.64, 0.23, intensity * mix(0.31, 1.0, plate_bevel));
}
