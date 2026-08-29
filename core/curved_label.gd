@tool
class_name CurvedLabel
extends Control

## Texto que acompanha uma curva (fita do mapa): cada glifo sobe pelo arco
## senoidal e inclina na tangente. amplitude positiva curva pra cima.

@export var key := "":
	set(value):
		key = value
		queue_redraw()
@export var font_size := 27:
	set(value):
		font_size = value
		queue_redraw()
@export var amplitude := 10.0:
	set(value):
		amplitude = value
		queue_redraw()
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var outline_color := Color(0, 0, 0, 0):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_size := 0:
	set(value):
		outline_size = value
		queue_redraw()
@export var uppercase := true:
	set(value):
		uppercase = value
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _draw() -> void:
	var text := tr(key) if key != "" else ""
	if text.is_empty():
		return
	if uppercase:
		text = text.to_upper()
	var font := get_theme_default_font()
	var advances: Array[float] = []
	var total := 0.0
	for character in text:
		var advance := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		advances.append(advance)
		total += advance
	var start_x := (size.x - total) / 2.0
	var baseline := size.y / 2.0 + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var x := start_x
	for index in text.length():
		var advance := advances[index]
		var u := 0.5 if total <= 0.0 else (x + advance / 2.0 - start_x) / total
		var y_offset := -amplitude * sin(PI * u)
		# tangente da curva: derivada de -A*sin(pi*u) em relacao a x
		var slope := -amplitude * PI * cos(PI * u) / maxf(total, 1.0)
		draw_set_transform(Vector2(x, baseline + y_offset), atan(slope), Vector2.ONE)
		if outline_size > 0 and outline_color.a > 0.0:
			draw_char_outline(font, Vector2.ZERO, text[index], font_size, outline_size, outline_color)
		draw_char(font, Vector2.ZERO, text[index], font_size, color)
		draw_set_transform_matrix(Transform2D())
		x += advance
