shader_type canvas_item;
// Local to environment art. Player/enemy/UI materials never use this shader.
uniform float texel_group : hint_range(1.0, 8.0) = 3.0;
varying vec4 art_tint;
void vertex() {
	art_tint = COLOR;
}
void fragment() {
	vec2 snapped_uv = (floor(UV / TEXTURE_PIXEL_SIZE / texel_group) + vec2(0.5)) * TEXTURE_PIXEL_SIZE * texel_group;
	COLOR = art_tint * texture(TEXTURE, snapped_uv);
}
