shader_type canvas_item;

uniform sampler2D floor_atlas : source_color, filter_nearest, repeat_disable;
uniform float tile_world = 76.0;
varying vec2 deck_vertex;

void vertex() {
	deck_vertex = VERTEX;
}

float variation(vec2 tile) {
	vec3 q = fract(vec3(tile.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 position = floor(deck_vertex) + 0.5;
	vec2 tile = floor(position / tile_world);
	vec2 face = fract(position / tile_world);
	float seed = variation(tile);
	vec2 cell = seed > 0.88 ? vec2(0.0, 1.0) : vec2(step(0.60, seed), 0.0);
	// Half-texel inset protects the source cells at quadrant boundaries.
	vec2 inset = vec2(0.0016);
	vec2 atlas_uv = cell * 0.5 + mix(inset, vec2(0.5) - inset, face);
	vec3 steel = texture(floor_atlas, atlas_uv).rgb;
	float plate_tone = mix(0.85, 1.10, variation(tile + 19.0));
	COLOR = vec4(steel * plate_tone * vec3(1.02, 1.04, 1.09), 1.0);
}
