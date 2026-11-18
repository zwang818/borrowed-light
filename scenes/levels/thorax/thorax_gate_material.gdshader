shader_type canvas_item;
#include "res://scenes/levels/thorax/thorax_core_light.gdshaderinc"

void fragment() {
	vec4 plate = texture(TEXTURE, UV);
	COLOR = vec4(core_unlit_steel(plate.rgb, core_light_mask(plate.rgb)), plate.a);
}
