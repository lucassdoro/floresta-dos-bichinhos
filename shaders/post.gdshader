shader_type canvas_item;

// Ordem do UberPost da URP: bloom -> vinheta -> color grading.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float taps : hint_range(0.0, 16.0) = 16.0;
uniform float bloom_intensity = 0.35;
uniform float bloom_threshold = 0.90;
uniform float bloom_knee = 0.50;
uniform float bloom_radius = 0.035;
uniform float vignette_intensity = 0.16;
uniform float vignette_smoothness = 0.40;
uniform float post_exposure_ev = 0.05;
uniform float contrast_amount = 0.06;
uniform float saturation_amount = 0.10;

const float GOLDEN_ANGLE = 2.39996323;

vec3 prefilter(vec3 color) {
	float brightest = max(color.r, max(color.g, color.b));
	float knee = bloom_threshold * bloom_knee;
	float soft = clamp(brightest - bloom_threshold + knee, 0.0, 2.0 * knee);
	soft = soft * soft / (4.0 * knee + 1e-4);
	float contribution = max(soft, brightest - bloom_threshold) / max(brightest, 1e-4);
	return color * contribution;
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;

	int tap_count = int(taps);
	if (tap_count > 0) {
		// disco de Vogel: uma amostra por tap, sem cadeia de mips
		vec3 bloom = vec3(0.0);
		float aspect = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
		for (int i = 0; i < tap_count; i++) {
			float t = (float(i) + 0.5) / taps;
			float radius = sqrt(t) * bloom_radius;
			float angle = float(i) * GOLDEN_ANGLE;
			vec2 offset = vec2(cos(angle) * aspect, sin(angle)) * radius;
			bloom += prefilter(texture(screen_texture, SCREEN_UV + offset).rgb);
		}
		color += bloom / taps * bloom_intensity;
	}

	vec2 distance_from_center = abs(SCREEN_UV - vec2(0.5)) * vignette_intensity * 3.0;
	float vignette = pow(clamp(1.0 - dot(distance_from_center, distance_from_center), 0.0, 1.0),
		vignette_smoothness * 5.0);
	color *= vignette;

	color *= exp2(post_exposure_ev);
	color = (color - vec3(0.5)) * (1.0 + contrast_amount) + vec3(0.5);
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luminance), color, 1.0 + saturation_amount);

	COLOR = vec4(color, 1.0);
}
