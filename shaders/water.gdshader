shader_type canvas_item;

// Agua viva pro fundo do mar: duas ondas de distorcao em UV + brilho lento.

uniform float amplitude : hint_range(0.0, 0.02) = 0.005;
uniform float speed : hint_range(0.0, 3.0) = 0.8;
uniform float wave_density : hint_range(0.0, 40.0) = 12.0;
uniform float shimmer_strength : hint_range(0.0, 0.3) = 0.06;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	uv.x += sin(uv.y * wave_density + t) * amplitude;
	uv.y += cos(uv.x * wave_density * 0.7 + t * 1.3) * amplitude * 0.6;
	vec4 color = texture(TEXTURE, uv);
	float shimmer = sin(uv.x * 30.0 + t * 2.0) * sin(uv.y * 24.0 - t * 1.7);
	color.rgb += shimmer * shimmer_strength * 0.5;
	COLOR = color;
}
