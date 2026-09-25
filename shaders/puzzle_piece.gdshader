shader_type canvas_item;

// Peca de quebra-cabeca recortada em GPU: a textura do no' e' a mascara
// jigsaw; o shader sampleia a regiao da foto e usa o alfa da mascara.
// revealed=0 mostra o placeholder bege (antes do "corte").

uniform sampler2D photo : source_color, filter_linear_mipmap;
uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_size = vec2(1.0);
uniform float revealed : hint_range(0.0, 1.0) = 0.0;

const vec3 PLACEHOLDER = vec3(0.918, 0.851, 0.722);

// no fragment o COLOR ja vem multiplicado pela TEXTURE; o tint puro sai do vertex
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	vec2 photo_uv = clamp(region_origin + UV * region_size, vec2(0.0), vec2(1.0));
	vec3 rgb = texture(photo, photo_uv).rgb;
	COLOR = vec4(mix(PLACEHOLDER, rgb, revealed), mask) * tint;
}
