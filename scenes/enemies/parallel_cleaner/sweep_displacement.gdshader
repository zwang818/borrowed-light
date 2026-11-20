shader_type canvas_item;
render_mode unshaded;

uniform sampler2D room_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform float max_offset_px = 4.0;
uniform float sweep_radius = 85.0;

varying vec2 from_pivot;
varying vec2 screen_x;
varying vec2 screen_y;
varying float wall_limit;

void vertex() {
	from_pivot = VERTEX;
	mat4 room_to_screen = CANVAS_MATRIX * MODEL_MATRIX;
	screen_x = room_to_screen[0].xy;
	screen_y = room_to_screen[1].xy;
	wall_limit = COLOR.r * sweep_radius;
}

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	float radius = length(from_pivot);
	float offset_px = floor(mask.a * max_offset_px + 0.5) * sign(mask.r - 0.5);
	// Shift along the arc normal, keeping the source sample on this side of cover.
	offset_px = clamp(offset_px, -radius, max(0.0, wall_limit - radius - 0.75));
	vec2 normal = from_pivot / max(radius, 0.001);
	vec2 screen_step = (screen_x * normal.x + screen_y * normal.y) * offset_px;
	vec3 sample_color = textureLod(room_color, SCREEN_UV + screen_step * SCREEN_PIXEL_SIZE, 0.0).rgb;
	COLOR = vec4(sample_color, step(0.01, abs(offset_px)));
}
