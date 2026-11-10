shader_type canvas_item;

uniform float pixel_world = 1.0;
varying vec2 world_position;
varying vec2 part_position;

void vertex() {
	part_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float grain(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 pixel = floor(world_position / pixel_world);
	vec2 part = floor(part_position / pixel_world);
	float pits = grain(floor(part / vec2(6.0, 5.0)));
	float brush = grain(floor(part / vec2(7.0, 1.0)));
	float fleck = grain(pixel);
	vec3 paint = COLOR.rgb;
	// Keep translucent glass reflections and sparks clean. Opaque metal gets patina and wear.
	float metal = smoothstep(0.78, 1.0, COLOR.a);
	float wear = smoothstep(0.68, 0.93, brush) * smoothstep(0.58, 0.86, pits);
	paint *= 1.0 + metal * ((pits - 0.5) * 0.25 + (fleck - 0.5) * 0.14);
	paint += vec3(0.14, 0.082, 0.045) * wear * metal * COLOR.r;
	COLOR = vec4(paint, COLOR.a);
}
