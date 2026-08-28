class_name LaliCharacter
extends AnimatedSprite2D

## Lali (peixinha da fase 2): idle ping-pong a 24fps, entra deslizando e da
## pops de escala nos gestos ask (1.06) e correct (1.18).

const ENTER_DURATION := 0.6

@export var base_scale := 0.828

func _ready() -> void:
	scale = Vector2.ONE * base_scale
	play("idle")

func enter_from(start: Vector2, rest: Vector2) -> void:
	position = start
	var tween := create_tween()
	tween.tween_property(self, "position", rest, ENTER_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func ask() -> void:
	_pop(1.06, 0.3)

func correct() -> void:
	_pop(1.18, 0.4)

func _pop(peak: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * base_scale * peak, duration / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * base_scale, duration / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
