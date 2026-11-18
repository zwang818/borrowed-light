shader_type canvas_item;
render_mode unshaded, blend_add;

#include "res://scenes/levels/thorax/thorax_core_light.gdshaderinc"

uniform float lamp_level = 0.94;
uniform vec3 ambient_steel = vec3(0.384, 0.424, 0.510);

void fragment() {
	vec4 plate = texture(TEXTURE, UV);
	float mask = core_light_mask(plate.rgb);
	vec3 steel = core_unlit_steel(plate.rgb, mask);
	vec3 emission = max(plate.rgb - steel * ambient_steel, vec3(0.0));
	COLOR = vec4(emission * lamp_level, plate.a * mask);
}
