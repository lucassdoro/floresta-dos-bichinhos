shader_type canvas_item;

// Tinta clipada na silhueta do coral: a textura do no' e' o coral_branches
// (mascara de alfa) e paint_tex e' o acumulado de carimbos do SubViewport.

uniform sampler2D paint_tex;
uniform float group_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 paint = texture(paint_tex, UV);
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(paint.rgb, paint.a * mask * group_alpha);
}
