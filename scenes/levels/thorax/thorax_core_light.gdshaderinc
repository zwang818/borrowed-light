float core_light_mask(vec3 color) {
	return smoothstep(0.12, 0.45, color.r - color.b) * smoothstep(0.45, 0.86, color.r);
}

vec3 core_unlit_steel(vec3 color, float mask) {
	vec3 cold = min(color.b, 0.48) * vec3(0.52, 0.67, 1.0);
	return mix(color, cold, mask);
}
