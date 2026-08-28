class_name PearlNecklace
extends Node2D

## Colar de perolas na base: cada letra achada vira uma perola nacarada com a
## letra. Desenho procedural simplificado (sem blur).

const PEARL_SIZE := 90.0
const STEP := 110.0
const CREAM := Color(1.0, 0.96, 0.87)
const BROWN := Color(0.42, 0.25, 0.11)
const GLOW := Color(1.0, 0.85, 0.45)

@export var slots := 6

var _filled: Array[bool] = []
var _letters: Array[String] = []
var _glow_t := {}

func _ready() -> void:
	for i in slots:
		_filled.append(false)
		_letters.append("")

func total_width() -> float:
	return (slots - 1) * STEP + PEARL_SIZE

## Centro global da perola de um slot.
func pearl_center(index: int) -> Vector2:
	return global_position + Vector2(-total_width() / 2.0 + PEARL_SIZE / 2.0 + index * STEP, 0)

func set_found(index: int, letter: String) -> void:
	_filled[index] = true
	_letters[index] = letter
	_glow_t[index] = 0.0
	var label := Label.new()
	label.text = letter
	label.size = Vector2(PEARL_SIZE, PEARL_SIZE)
	label.position = pearl_center(index) - global_position - label.size / 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 54)
	label.add_theme_color_override("font_color", Color(0.36, 0.23, 0.12, 1))
	label.z_index = 1
	add_child(label)

func _process(delta: float) -> void:
	if _glow_t.is_empty():
		return
	for index in _glow_t.keys():
		_glow_t[index] += delta
		if _glow_t[index] >= 0.6:
			_glow_t.erase(index)
	queue_redraw()

func _draw() -> void:
	var half := total_width() / 2.0
	draw_line(Vector2(-half - 40, 0), Vector2(half + 40, 0), Color(BROWN, 0.8), 6.0)
	for index in slots:
		var center := Vector2(-half + PEARL_SIZE / 2.0 + index * STEP, 0)
		var radius := PEARL_SIZE / 2.0 - 3.0
		if _glow_t.has(index):
			var a: float = sin(_glow_t[index] / 0.6 * PI)
			draw_circle(center, radius + 10, Color(GLOW, a * 0.7))
		if _filled[index]:
			draw_circle(center, radius, Color(0.95, 0.94, 0.96))
			draw_circle(center + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.62, Color(1, 1, 1, 0.9))
			draw_circle(center + Vector2(radius * 0.35, radius * 0.2), radius * 0.4, Color(0.96, 0.81, 0.89, 0.5))
			draw_circle(center + Vector2(-radius * 0.2, radius * 0.5), radius * 0.35, Color(0.75, 0.85, 0.95, 0.55))
			draw_arc(center, radius, 0, TAU, 40, BROWN, 6.0)
			draw_circle(center + Vector2(-radius * 0.35, -radius * 0.45), radius * 0.12, Color.WHITE)
		else:
			draw_circle(center, radius, Color(CREAM, 0.35))
			draw_arc(center, radius, 0, TAU, 40, Color(BROWN, 0.45), 6.0)
