class_name LetterBubble
extends Control

## Bolha de agua com uma letra dentro. Nasce abaixo do lugar e sobe com
## balanco; flutuando, faz bob e wobble (x/y em antifase). Estoura no acerto,
## balanca no erro, esmaece quando a rodada acaba.

signal tapped(bubble: LetterBubble)

const DIAMETER := 280.0
const RISE_DURATION := 0.8
const SWAY_AMPLITUDE := 18.0
const BOB_AMPLITUDE := 12.0
const WOBBLE_AMPLITUDE := 0.03
const WOBBLE_PERIOD := 1.1
const POP_DURATION := 0.3
const SHAKE_DURATION := 0.4
const SHAKE_DEGREES := 8.0
const FADE_DURATION := 0.3
const BUBBLE := preload("res://assets/art/MiniGames/ColorReef/bubble_a.webp")
const BUBBLE_POP := preload("res://assets/art/MiniGames/ColorReef/bubble_pop.webp")

var letter := "A"
var rest_position := Vector2.ZERO
var rise_distance := 420.0

var _bob_phase := randf() * TAU
var _bob_period := 2.6 + randf() * 0.8
var _rise_t := 0.0
var _time := 0.0
var _pop_t := -1.0
var _shake_t := -1.0
var _fade_t := -1.0

@onready var _visual: TextureRect = $Visual
@onready var _label: Label = $Visual/Letter

func is_settled() -> bool:
	return _rise_t >= RISE_DURATION

func is_gone() -> bool:
	return _pop_t >= POP_DURATION or _fade_t >= FADE_DURATION

func is_leaving() -> bool:
	return _pop_t >= 0.0 or _fade_t >= 0.0

func _ready() -> void:
	pivot_offset = size / 2.0
	_label.text = letter
	position = rest_position + Vector2(0, rise_distance) - size / 2.0

func pop() -> void:
	if is_leaving():
		return
	_pop_t = 0.0
	_visual.texture = BUBBLE_POP

func shake() -> void:
	_shake_t = 0.0

func fade_out() -> void:
	if is_leaving():
		return
	_fade_t = 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_settled() or is_leaving():
			return
		tapped.emit(self)

func _process(delta: float) -> void:
	_time += delta
	var center := rest_position
	if is_settled():
		var bob := sin(_time * TAU / _bob_period + _bob_phase)
		center = rest_position + Vector2(0, -bob * BOB_AMPLITUDE)
	else:
		_rise_t += delta
		var t := clampf(_rise_t / RISE_DURATION, 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - t, 3.0)
		center = rest_position + Vector2(
			sin(t * TAU) * SWAY_AMPLITUDE * (1.0 - t),
			rise_distance * (1.0 - ease_out))
	position = center - size / 2.0

	var wobble := WOBBLE_AMPLITUDE * sin(_time * TAU / WOBBLE_PERIOD)
	scale = Vector2(1.0 + wobble, 1.0 - wobble)

	if _shake_t >= 0.0:
		_shake_t += delta
		var t := _shake_t / SHAKE_DURATION
		if t >= 1.0:
			_shake_t = -1.0
			rotation = 0.0
		else:
			rotation_degrees = SHAKE_DEGREES * sin(t * PI * 3.0) * (1.0 - t)

	if _pop_t >= 0.0:
		_pop_t += delta
		modulate.a = clampf(1.0 - _pop_t / POP_DURATION, 0.0, 1.0)
		scale *= 1.0 + 0.3 * clampf(_pop_t / POP_DURATION, 0.0, 1.0)
	if _fade_t >= 0.0:
		_fade_t += delta
		modulate.a = clampf(1.0 - _fade_t / FADE_DURATION, 0.0, 1.0)
	if is_gone():
		queue_free()
