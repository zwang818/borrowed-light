shader_type canvas_item;
render_mode unshaded;

uniform bool activated = false;

void fragment() {
	vec4 pixel = COLOR;
	// The green channels belong to the lamp, not the brass and steel casing.
	if (!activated && pixel.g > max(pixel.r, pixel.b) + 0.025) {
		pixel.rgb = vec3(pixel.g, pixel.r * 0.44, pixel.b * 0.36);
	}
	COLOR = pixel;
}
