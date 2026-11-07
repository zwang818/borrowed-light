shader_type canvas_item;

uniform float sway_amount = 1.6;
uniform float sway_speed = 4.2;

void vertex() {
	float tip_weight = pow(1.0 - UV.y, 1.45);
	float gust = sin(TIME * sway_speed + UV.x * 10.0 + UV.y * 2.2);
	VERTEX.x += gust * sway_amount * tip_weight;
}
