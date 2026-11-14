shader_type canvas_item;

// Original sprite alpha supplies the outer silhouette. The per-facing lower
// contour separates the actual head from the torso/shoulders in the same atlas.
uniform vec2 frame_size = vec2(1.0);
uniform vec2 lower_edge[12];
uniform int edge_count = 2;
varying vec2 frame_point;

void vertex() {
	frame_point = VERTEX / frame_size;
}

void fragment() {
	float bottom = lower_edge[0].y;
	for (int i = 1; i < 12; i++) {
		if (i >= edge_count) { break; }
		vec2 left = lower_edge[i - 1];
		vec2 right = lower_edge[i];
		if (frame_point.x >= left.x) {
			float t = clamp((frame_point.x - left.x) / max(right.x - left.x, 0.0001), 0.0, 1.0);
			bottom = mix(left.y, right.y, t);
		}
	}
	if (frame_point.y > bottom) {
		COLOR.a = 0.0;
	}
}
