shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 glow_size;
uniform vec2 glow_center;
uniform vec2 floor_size;

void fragment() {
	vec2 p = UV * glow_size - glow_center;

	// Overlay only the light so joints and rust on the plates remain visible.
	vec2 direct = p / (floor_size * vec2(0.9, 1.18));
	float center = exp(-2.8 * dot(direct, direct));
	vec2 spread = (p + vec2(0.0, 28.0)) / vec2(floor_size.x * 1.34, 147.0);
	float pool = 1.0 - smoothstep(0.0, 1.0, length(spread));
	float breath = 0.97 + 0.03 * sin(TIME * 1.7);

	// A small warm reflection blends into the spill without outlining it.
	float warm_reflection = pool * (1.0 - center) * 0.14;
	vec3 light = mix(vec3(0.48, 0.69, 0.84), vec3(0.78, 0.64, 0.43), warm_reflection);
	COLOR = vec4(light, (0.26 * center + 0.16 * pool) * breath);
}
