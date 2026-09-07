shader_type canvas_item;
render_mode blend_add;

// Piso de vidro da splash: espelha o que ja esta na tela em torno de
// mirror_v (pe' da composicao, em UV) e borra com disco de Vogel.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float mirror_v = 0.78;
uniform float strength = 0.16;
uniform float radius_px = 16.0;

const float GOLDEN_ANGLE = 2.39996323;
const int TAPS = 16;

void fragment() {
	if (SCREEN_UV.y < mirror_v) {
		discard;
	}
	vec2 uv = vec2(SCREEN_UV.x, 2.0 * mirror_v - SCREEN_UV.y);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < TAPS; i++) {
		float t = (float(i) + 0.5) / float(TAPS);
		float radius = sqrt(t) * radius_px;
		float angle = float(i) * GOLDEN_ANGLE;
		sum += texture(screen_texture, uv + vec2(cos(angle), sin(angle)) * radius * SCREEN_PIXEL_SIZE).rgb;
	}
	COLOR = vec4(sum / float(TAPS) * strength, 1.0);
}
