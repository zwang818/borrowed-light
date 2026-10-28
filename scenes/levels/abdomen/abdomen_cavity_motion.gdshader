shader_type canvas_item;
// Driven by the pausable scene clock, deliberately not shader TIME.
uniform float cycle_phase = 0.0;
uniform sampler2D clean_cavity : filter_nearest;
uniform vec4 web_regions[9];
varying vec4 art_tint;
varying vec2 local_position;

void vertex() {
	art_tint = COLOR;
	local_position = VERTEX;
}

// A sleeve rocks around its vertical axis. Its edge and bolted collars stay fixed.
vec2 roll_sleeve(vec2 p, vec4 bounds, float phase) {
	if (p.x > bounds.x && p.x < bounds.z && p.y > bounds.y && p.y < bounds.w) {
		float across = (p.x - bounds.x) / (bounds.z - bounds.x);
		float end_mask = smoothstep(bounds.y, bounds.y + 8.0, p.y) * (1.0 - smoothstep(bounds.w - 8.0, bounds.w, p.y));
		p.x += sin(phase) * 13.0 * sin(across * 3.14159265) * end_mask;
	}
	return p;
}

// Two anchored ends and a moving joint: bellows compress while the lower shaft extends.
vec2 telescope(vec2 p, vec4 bounds, float joint, float phase) {
	if (p.x > bounds.x && p.x < bounds.z && p.y > bounds.y && p.y < bounds.w) {
		float edge = smoothstep(bounds.x, bounds.x + 5.0, p.x) * (1.0 - smoothstep(bounds.z - 5.0, bounds.z, p.x));
		float moving_joint = joint + sin(phase) * 12.0 * edge;
		if (p.y < moving_joint) {
			p.y = bounds.y + (p.y - bounds.y) / (moving_joint - bounds.y) * (joint - bounds.y);
		} else {
			p.y = joint + (p.y - moving_joint) / (bounds.w - moving_joint) * (bounds.w - joint);
		}
	}
	return p;
}

void fragment() {
	vec2 tile = floor((local_position - vec2(-1152.0, -1024.0)) / 640.0);
	float phase = cycle_phase * 6.2831853 + tile.x * 1.73 + tile.y * 2.31;
	// Coordinates refer to the retained 1254 px source. No scrolling of the whole tile.
	vec2 p = UV * 1254.0;
	p = roll_sleeve(p, vec4(568.0, 153.0, 681.0, 231.0), phase);
	p = roll_sleeve(p, vec4(568.0, 350.0, 681.0, 471.0), phase);
	p = roll_sleeve(p, vec4(568.0, 663.0, 681.0, 761.0), phase);
	p = roll_sleeve(p, vec4(568.0, 840.0, 681.0, 981.0), phase);
	p = roll_sleeve(p, vec4(568.0, 1087.0, 681.0, 1194.0), phase);
	p = roll_sleeve(p, vec4(280.0, 288.0, 359.0, 374.0), phase + 2.1);
	p = roll_sleeve(p, vec4(279.0, 463.0, 359.0, 535.0), phase + 2.1);
	p = roll_sleeve(p, vec4(279.0, 920.0, 359.0, 977.0), phase + 2.1);
	p = roll_sleeve(p, vec4(891.0, 283.0, 987.0, 367.0), phase + 4.2);
	p = roll_sleeve(p, vec4(891.0, 575.0, 987.0, 653.0), phase + 4.2);
	p = roll_sleeve(p, vec4(891.0, 949.0, 987.0, 1030.0), phase + 4.2);
	p = telescope(p, vec4(716.0, 830.0, 787.0, 1046.0), 948.0, phase + 1.2);
	p = telescope(p, vec4(803.0, 275.0, 857.0, 384.0), 350.0, phase + 3.4);
	p = telescope(p, vec4(161.0, 855.0, 209.0, 1005.0), 977.0, phase + 4.7);
	vec2 sampled = (floor(p) + vec2(0.5)) / 1254.0;
	vec4 base = texture(TEXTURE, sampled);
	// Only former web patches use the cleaned image. All other source pixels stay original.
	vec2 original = UV * 1254.0;
	for (int i = 0; i < 9; i++) {
		vec4 r = web_regions[i];
		if (original.x >= r.x && original.y >= r.y && original.x <= r.z && original.y <= r.w) {
			float edge = min(min(original.x - r.x, r.z - original.x), min(original.y - r.y, r.w - original.y));
			base = mix(base, texture(clean_cavity, sampled), smoothstep(0.0, 5.0, edge));
		}
	}
	COLOR = art_tint * base;
}
