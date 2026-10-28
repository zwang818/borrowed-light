shader_type canvas_item;
// Local to environment art. Player/enemy/UI materials never use this shader.
// One art pixel = texel_group_x/y source pixels. Surface scripts derive those
// values from abdomen_art_scale.gd so every plane shows the same pixel size.
uniform float texel_group_x : hint_range(1.0, 20.0) = 3.0;
uniform float texel_group_y : hint_range(1.0, 20.0) = 3.0;
varying vec4 art_tint;

void vertex() {
	art_tint = COLOR;
}

void fragment() {
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE / vec2(texel_group_x, texel_group_y)) + vec2(0.5);
	vec2 snapped_uv = px * TEXTURE_PIXEL_SIZE * vec2(texel_group_x, texel_group_y);
	COLOR = art_tint * texture(TEXTURE, snapped_uv);
}
