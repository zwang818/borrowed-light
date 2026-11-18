shader_type canvas_item;
render_mode unshaded;

uniform float elapsed = 0.0;
uniform int shot = 0;
uniform vec2 target = vec2(0.5);
uniform vec2 secondary = vec2(0.5);

float soft_disc(vec2 point, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.0, 1.0, length((point - center) / radius));
}

void fragment() {
	vec2 pixel = floor(UV * vec2(836.0, 470.0)) / vec2(836.0, 470.0);
	float t = mod(elapsed, 2.4);
	vec2 sample_uv = UV;
	if (shot == 7) {
		float recoil = exp(-pow((t - 0.66) / 0.08, 2.0));
		sample_uv = (UV - vec2(0.5)) * (1.0 - recoil * 0.014) + vec2(0.5);
	}
	vec4 art = texture(TEXTURE, sample_uv);
	vec3 amber = vec3(1.0, 0.67, 0.30);
	float beam = 0.0;

	if (shot == 0 || shot == 1 || shot == 4 || shot == 5) {
		float sweep = clamp((t - 0.28) / 0.92, 0.0, 1.0);
		vec2 cursor = mix(target, secondary, sweep);
		float active = smoothstep(0.30, 0.42, t) * (1.0 - smoothstep(1.08, 1.2, t));
		vec2 distance_to_cursor = abs(pixel - cursor);
		beam += active * 0.68 * (1.0 - smoothstep(0.002, 0.009, distance_to_cursor.x))
			* (1.0 - smoothstep(0.025, 0.105, distance_to_cursor.y));
		beam += 0.18 * active * soft_disc(pixel, cursor, vec2(0.14, 0.13));
	} else if (shot == 6) {
		float spark_time = max(t - 0.54, 0.0);
		float burst = step(0.54, t) * (1.0 - smoothstep(0.0, 0.44, spark_time));
		beam += 0.55 * burst * soft_disc(pixel, target, vec2(0.09, 0.11));
		for (int i = 0; i < 10; i++) {
			float angle = float(i) * 2.39;
			vec2 velocity = vec2(cos(angle) * 0.20, sin(angle) * 0.29);
			vec2 spark = target + velocity * spark_time + vec2(0.0, spark_time * spark_time * 0.18);
			beam += burst * soft_disc(pixel, spark, vec2(0.004, 0.007));
		}
	} else if (shot == 7) {
		amber = vec3(1.0, 0.88, 0.62);
		for (int i = 0; i < 3; i++) {
			float travel = (t - 0.63 - float(i) * 0.085) / 0.51;
			if (travel >= 0.0 && travel < 1.0) {
				vec2 center = mix(target, secondary, travel);
				vec2 radius = mix(vec2(0.024, 0.072), vec2(0.009, 0.031), travel);
				float ring = abs(length((pixel - center) / radius) - 1.0);
				beam += (1.0 - smoothstep(0.04, 0.19, ring)) * (1.0 - travel);
			}
		}
		beam += soft_disc(pixel, target, vec2(0.095, 0.16))
			* exp(-pow((t - 0.65) / 0.082, 2.0)) * 0.79;
	} else {
		float lamp = smoothstep(0.28, 0.52, t) * (1.0 - smoothstep(1.62, 1.91, t));
		beam += lamp * soft_disc(pixel, target, vec2(0.062, 0.085)) * 0.7;
		beam += lamp * soft_disc(pixel, target, vec2(0.018, 0.026)) * 0.68;
	}
	COLOR = vec4(mix(art.rgb, amber, clamp(beam, 0.0, 0.93)), art.a);
}
