class_name NumberPlatform
extends Control

## Pedra numerada: flutua, quica no acerto e o numero esmaece quando visitada.

signal tapped(platform: NumberPlatform)

const VISITED_ALPHA := 0.4
const BOUNCE_SCALE := 1.08
const BOUNCE_DURATION := 0.25
const BOB_AMPLITUDE := 6.0
const BOB_PERIOD := 3.0

@export var number := 1

var visited := false
var base_position := Vector2.ZERO

var _time := randf() * TAU

@onready var _badge: TextureRect = %Badge
@onready var _number_label: Label = %NumberLabel

func _ready() -> void:
	pivot_offset = size / 2.0
	_number_label.text = str(number)

func set_number(value: int) -> void:
	number = value
	_number_label.text = str(value)

func mark_visited() -> void:
	visited = true
	_badge.modulate.a = VISITED_ALPHA

func bounce() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * BOUNCE_SCALE, BOUNCE_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, BOUNCE_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Centro de pouso do Lolo: 20px acima do centro da pedra.
func landing_center() -> Vector2:
	return base_position + Vector2(0, -20)

func _process(delta: float) -> void:
	_time += delta
	var wave := sin(_time * TAU / BOB_PERIOD)
	position = base_position - size / 2.0 + Vector2(0, -wave * BOB_AMPLITUDE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tapped.emit(self)
