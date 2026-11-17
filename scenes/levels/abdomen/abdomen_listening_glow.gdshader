shader_type canvas_item;
render_mode unshaded;

uniform vec2 glow_size;
uniform vec2 glow_center;
uniform vec2 floor_size;

void fragment() {
	vec2 p = UV * glow_size - glow_center;

	// The overexposed center replaces the grate visually. Round its corners
	// beyond the grate's bounds so the old tile seams disappear into the light.
	vec2 edge = abs(p) - (floor_size * 0.5 - vec2(5.0));
	float distance_to_core = length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0);
	float core = 1.0 - smoothstep(9.0, 29.0, distance_to_core);

	// Stretch the light toward the spawn. A broad pool and softer outer bounce
	// give it a visible falloff against the dark metal.
	vec2 spill = (p + vec2(0.0, 40.0)) / vec2(floor_size.x * 1.33, 150.0);
	float pool = 1.0 - smoothstep(0.2, 1.0, length(spill));
	float bloom = 1.0 - smoothstep(13.0, 87.0, distance_to_core);
	float angle = atan(p.y, p.x + 0.001);
	float rays = pow(max(0.0, 0.59 + 0.22 * sin(angle * 9.0) + 0.16 * cos(angle * 17.0)), 2.0);
	float breath = 0.96 + 0.04 * sin(TIME * 1.7);
	float halo = (0.36 * pool + 0.27 * bloom + 0.24 * rays * pool) * breath;

	vec3 reflected = mix(vec3(0.64, 0.78, 0.78), vec3(0.95, 0.98, 0.95), bloom);
	COLOR = vec4(mix(reflected, vec3(0.995, 1.0, 0.984), core), core + (1.0 - core) * halo);
}
