shader_type canvas_item;

// Folhagem de cima balanca; o chao fica parado.
uniform float amplitude : hint_range(0.0, 0.02) = 0.004;
uniform float speed : hint_range(0.0, 3.0) = 0.6;
uniform float wave_density : hint_range(1.0, 20.0) = 8.0;
uniform float mask_bottom : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	float mask = 1.0 - smoothstep(0.0, mask_bottom, UV.y);
	float wave = sin(TIME * speed + UV.y * wave_density) * amplitude * mask;
	COLOR = texture(TEXTURE, UV + vec2(wave, 0.0));
}
