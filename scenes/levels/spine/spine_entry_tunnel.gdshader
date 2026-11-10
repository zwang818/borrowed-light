shader_type canvas_item;

uniform float pixel_world = 1.0;
uniform bool hoop = false;
uniform float start = 0.0;
uniform float run = 1.0;
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
	vec2 pixel = (floor(world_position / pixel_world) + 0.5) * pixel_world;
	vec2 shift = pixel - world_position;
	vec2 dx = dFdx(world_position);
	vec2 dy = dFdy(world_position);
	float determinant = dx.x * dy.y - dx.y * dy.x;
	vec2 offset = vec2(shift.x * dy.y - shift.y * dy.x, dx.x * shift.y - dx.y * shift.x) / determinant;
	vec2 uv = UV + dFdx(UV) * offset.x + dFdy(UV) * offset.y;
	float side = clamp(uv.y, 0.0, 1.0);
	float shell_light = max(0.0, cos((side - 0.34) * 2.95));
	float bevel = floor(shell_light * 16.0) / 16.0;
	float rough = grain(floor(pixel / vec2(3.0, 3.0)));
	float weather = grain(floor(pixel / vec2(9.0, 7.0)));
	vec3 base = COLOR.rgb * (0.40 + bevel * 0.70 - side * 0.16);
	base += (rough - 0.5) * 0.045 + (weather - 0.5) * 0.031;
	base += vec3(0.045, 0.018, 0.010) * bevel;
	if (hoop) {
		float u = clamp(uv.x - start, 0.0, run);
		float lip = min(u, run - u);
		if (lip < 2.0) {
			base *= 0.47;
		} else if (lip < 5.0) {
			base += vec3(0.15, 0.069, 0.044) * shell_light;
		}
		vec2 nut = vec2(u - run * 0.49, (fract(side * 22.0) - 0.5) * 17.0);
		if (dot(nut, nut) < 18.0) {
			base *= 0.51;
			vec2 highlight = nut + vec2(1.5, 1.5);
			if (dot(highlight, highlight) < 5.0) {
				base += vec3(0.20, 0.093, 0.055) * shell_light;
			}
		}
	} else {
		float panel = side * 7.0;
		float rib = abs(fract(panel + 0.5) - 0.5);
		float patch = mod(uv.x + floor(panel) * 53.0, 184.0);
		if (rib < 0.014 || patch < 2.0) {
			base *= 0.53;
		} else if (rib < 0.026 || patch < 3.0) {
			base += vec3(0.09, 0.036, 0.025) * shell_light;
		}
		if (weather > 0.72 && rough > 0.65 && (rib < 0.12 || patch < 19.0)) {
			base = mix(base, vec3(0.22, 0.16, 0.16), 0.44);
		}
		vec2 stud = vec2(mod(uv.x, 36.0) - 4.0, (rib - 0.050) * 57.0);
		if (dot(stud, stud) < 3.9) {
			base *= 0.48;
			if (stud.y < -0.4) {
				base += vec3(0.12, 0.064, 0.039) * shell_light;
			}
		}
	}
	COLOR = vec4(base, COLOR.a);
}
