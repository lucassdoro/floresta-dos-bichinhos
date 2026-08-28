shader_type canvas_item;

// O escuro da noite: veu azul-marinho com dois furos de borda suave — a
// fogueira (fixa, tremula via flicker) e o vaga-lume (movel).

uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform vec2 fire_center = vec2(960.0, 830.0);
uniform float fire_radius = 330.0;
uniform float flicker = 1.0;
uniform vec2 light_center = vec2(800.0, 700.0);
uniform float light_radius = 230.0;

const vec3 DARK = vec3(0.043, 0.078, 0.188);
const float DARK_ALPHA = 0.72;
const float SOFT_START = 0.55;

float hole(vec2 p, vec2 c, float r) {
	return smoothstep(r * SOFT_START, r, distance(p, c));
}

void fragment() {
	vec2 p = UV * rect_size;
	float h = min(hole(p, fire_center, fire_radius * flicker), hole(p, light_center, light_radius));
	COLOR = vec4(DARK, DARK_ALPHA * h);
}
