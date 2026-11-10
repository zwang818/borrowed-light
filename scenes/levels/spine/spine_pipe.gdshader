shader_type canvas_item;

uniform float pixel_world = 1.0;
uniform float run = 128.0;
uniform float width = 32.0;
uniform float pitch = 74.0;
uniform float phase = 0.0;
uniform int profile = 0; // Copper, wine-red vessel, braided hose, flange.
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
	vec2 uv = clamp(UV + dFdx(UV) * offset.x + dFdy(UV) * offset.y, 0.0, 1.0);
	float across = uv.y * width;
	float side = uv.y * 2.0 - 1.0;
	float curve = sqrt(max(0.0, 1.0 - side * side));
	float distance = floor(uv.x * run + phase + side * side * width * 0.18);
	float section = floor(distance / pitch);
	float joint = mod(distance, pitch);
	float glint = abs(uv.y - 0.28 - 0.025 * sin(distance * 0.08));
	float worn = grain(floor(vec2(distance / 5.0, across / 3.0)));
	float speck = grain(pixel);
	float reflected = floor(curve * 9.0) / 9.0;
	vec3 paint = COLOR.rgb * (0.36 + reflected * 0.91 - uv.y * 0.31);
	paint *= 0.88 + grain(vec2(section, phase)) * 0.22;
	paint += (speck - 0.5) * 0.031 + (worn - 0.5) * 0.038;
	if (profile == 0 || profile == 1) {
		vec3 reflected_color = profile == 0 ? vec3(0.38, 0.174, 0.084) : vec3(0.18, 0.052, 0.056) * COLOR.r * 2.3;
		paint += reflected_color * (1.0 - smoothstep(0.015, 0.16, glint)) * (0.43 + 0.57 * worn);
		if (glint < 0.023 && worn > 0.38) {
			paint += reflected_color * (profile == 0 ? 0.59 : 0.37);
		}
		if (profile == 1 && width > 44.0) {
			float weld = mod(distance + side * 1.5, 39.0);
			float edge = mod(across + floor(distance / 39.0) * 9.0, 22.0);
			if (weld < 1.5 || edge < 1.5) {
				paint *= 0.73;
			} else if (weld < 2.5 || edge < 2.5) {
				paint += vec3(0.052, 0.020, 0.025) * reflected;
			}
		}
		float oxide = grain(floor(vec2(distance / 13.0, across / 7.0)));
		if (oxide > 0.70 && worn > 0.45) {
			paint = mix(paint, profile == 0 ? vec3(0.36, 0.17, 0.086) : vec3(0.28, 0.09, 0.083), (oxide - 0.70) * 1.1);
		}
		if (mod(across, 8.0) < 1.0 && mod(distance, 31.0) < 15.0 && worn > 0.48) {
			paint += reflected_color * 0.20;
		}
		if (joint >= 19.0 && joint < 22.0) {
			paint *= joint < 20.0 ? 0.68 : 1.13;
		}
	} else if (profile == 2) {
		float braid = mod(distance + floor(across * 0.75), 5.0);
		paint *= braid < 2.0 ? 0.68 : 1.19;
	} else if (profile == 3) {
		// A separate overhanging flange. Rims and bolt heads follow the cylindrical face.
		float lip = min(uv.x, 1.0 - uv.x) * run;
		paint = COLOR.rgb * (0.48 + reflected * 0.61 - uv.y * 0.33);
		paint += (worn - 0.5) * 0.065;
		if (lip < 2.0) {
			paint *= 0.36;
		} else if (lip < 4.0) {
			paint += vec3(0.17, 0.106, 0.073) * reflected;
		} else if (lip < 7.0) {
			paint *= 0.63;
		}
		vec2 nut = vec2((uv.x - 0.5) * run, mod(across, 14.0) - 7.0);
		if (abs(nut.x) + abs(nut.y) < 4.8) {
			paint = nut.y < 0.0 ? vec3(0.60, 0.36, 0.21) : vec3(0.30, 0.16, 0.12);
		}
	}
	float band_width = profile == 2 ? 6.0 : 13.0;
	if (profile != 3 && joint < band_width) {
		vec3 collar = profile == 1 ? vec3(0.37, 0.22, 0.16) * (0.55 + COLOR.r) : vec3(0.41, 0.29, 0.21);
		paint = collar * (0.59 + reflected * 0.43 - uv.y * 0.20);
		paint += (worn - 0.5) * 0.051;
		if (joint < 2.0 || joint > band_width - 2.0) {
			paint *= 0.49;
		} else if (joint < 3.0 || joint > band_width - 4.0) {
			paint += vec3(0.11, 0.092, 0.07);
		}
		if (profile != 2 && width > 22.0) {
			vec2 bolt = vec2(joint - band_width * 0.5, mod(across + 1.0, 11.0) - 5.0);
			float face = abs(bolt.x) + abs(bolt.y);
			if (face < 3.8) {
				paint = bolt.y < -0.5 ? vec3(0.55, 0.39, 0.25) * (0.65 + COLOR.r) : vec3(0.15, 0.10, 0.09);
				if (face > 2.6) {
					paint *= 0.65;
				}
			}
		}
	}
	float rim = min(across, width - across);
	if (rim < 1.7) {
		paint *= 0.28;
	} else if (rim < 3.5 && side < 0.0) {
		paint += vec3(0.048, 0.035, 0.026);
	}
	COLOR = vec4(paint, COLOR.a);
}
