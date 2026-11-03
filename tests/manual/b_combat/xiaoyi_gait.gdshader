shader_type canvas_item;
varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }
uniform float phase = 0.0;
uniform float strength = 0.0;
uniform float side_view = 0.0;
// Continuous lower-leg follow-through between authored poses. Torso and weapon remain intact.
void fragment() {
	vec2 uv = UV;
	float leg = smoothstep(0.67, 0.84, uv.y);
	float left_leg = 1.0 - smoothstep(0.46, 0.54, uv.x);
	float step = sin(phase) * (left_leg * 2.0 - 1.0);
	float lift = max(0.0, step);
	uv.x -= step * leg * strength * mix(0.018, 0.035, side_view);
	uv.y += lift * leg * strength * 0.032;
	vec4 color = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { color = vec4(0.0); }
	COLOR = sprite_tint * color;
}
