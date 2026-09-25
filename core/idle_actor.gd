class_name IdleActor
extends AnimatedSprite2D

## Personagem parado mas vivo: respira (escala a partir dos pes), pisca de
## tempos em tempos e so mexe a boca enquanto fala.

const POP_SCALE := 0.15
const POP_DURATION := 0.15

@export var idle_animation: StringName
@export var blink_animation: StringName
@export var talk_animation: StringName
@export var breath_amount := 0.015
@export var breath_period := 2.6
## Intervalo aleatorio entre piscadas, em segundos (min, max).
@export var blink_interval := Vector2(2.5, 5.0)

var _base_scale := Vector2.ONE
var _time := 0.0
var _pop := 0.0
var _talking := false
var _next_blink := 0.0

func _ready() -> void:
	_base_scale = scale
	# cada personagem respira num tempo diferente
	_time = randf() * breath_period
	animation_finished.connect(_on_animation_finished)
	_rest()

func _process(delta: float) -> void:
	_time += delta
	var breath := sin(_time * TAU / breath_period) * breath_amount
	scale = _base_scale * Vector2(1.0 - breath * 0.5, 1.0 + breath) * (1.0 + _pop)
	if _talking or animation == blink_animation:
		return
	_next_blink -= delta
	if _next_blink <= 0.0:
		play(blink_animation)

func talk(active: bool) -> void:
	if active == _talking or talk_animation == &"":
		return
	_talking = active
	if active:
		play(talk_animation)
		return
	_rest()

func pop() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_pop", POP_SCALE, POP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_pop", 0.0, POP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_animation_finished() -> void:
	if animation == blink_animation:
		_rest()

func _rest() -> void:
	play(idle_animation)
	_next_blink = randf_range(blink_interval.x, blink_interval.y)
