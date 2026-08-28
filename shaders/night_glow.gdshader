shader_type canvas_item;
render_mode blend_add;

// Luz quente aditiva dentro dos furos do veu: clareia o que o fundo mostra.

uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform vec2 fire_center = vec2(960.0, 830.0);
uniform float fire_radius = 330.0;
uniform float flicker = 1.0;
uniform vec2 light_center = vec2(800.0, 700.0);
uniform float light_radius = 230.0;

const vec3 FIRE_TINT = vec3(1.0, 0.627, 0.251);
const vec3 LIGHT_TINT = vec3(1.0, 0.878, 0.541);

void fragment() {
	vec2 p = UV * rect_size;
	float fire_a = clamp(1.0 - distance(p, fire_center) / (fire_radius * flicker), 0.0, 1.0) * 0.22;
	float light_a = clamp(1.0 - distance(p, light_center) / light_radius, 0.0, 1.0) * 0.30;
	COLOR = vec4(FIRE_TINT * fire_a + LIGHT_TINT * light_a, 1.0);
}
