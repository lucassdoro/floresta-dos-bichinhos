shader_type canvas_item;
// Uma passada de gaussiana separavel (halo do neon da splash). Sai
// premultiplicado com alpha 0: em blend_premul_alpha isso e' soma pura, tanto
// no viewport da primeira passada quanto na tela (halo aditivo).
render_mode blend_premul_alpha;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float sigma = 8.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	int radius = int(ceil(sigma * 2.5));
	vec3 sum = vec3(0.0);
	float weights = 0.0;
	for (int i = -radius; i <= radius; i++) {
		float weight = exp(-float(i * i) / (2.0 * sigma * sigma));
		sum += texture(TEXTURE, UV + direction * float(i) * TEXTURE_PIXEL_SIZE).rgb * weight;
		weights += weight;
	}
	COLOR = vec4(sum / weights * tint.rgb * tint.a, 0.0);
}
